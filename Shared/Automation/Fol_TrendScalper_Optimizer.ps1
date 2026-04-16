# Fol_TrendScalper Native Optimization Scan (v1.5 Gold Special)
param (
    [string]$EAFolder = "Fol_TrendScalper",
    [string]$EAFile = "Fol_TrendScalper"
)

$ConfigPath = Join-Path (Split-Path $PSCommandPath) "env_config.ps1"
. $ConfigPath

$EAPaths = Get-EA-Paths -EAFolder $EAFolder -EAName $EAFile
$PS_SCRIPT = Join-Path (Split-Path $PSCommandPath) "AutoBacktest.ps1"
$JS_AGGREGATOR = Join-Path (Split-Path $PSCommandPath) "aggregator.js"
$RESULT_DIR = $EAPaths.ReportDir

# Clear previous results
Write-Host "Cleaning up old results..." -ForegroundColor Gray
Remove-Item "$RESULT_DIR\*.xml" -ErrorAction SilentlyContinue
Remove-Item "$RESULT_DIR\*.html" -ErrorAction SilentlyContinue

# Close MT5 to ensure clean start
Write-Host "Ensuring clean start..."
Get-Process | Where-Object { $_.Name -eq "terminal64" } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

$PAIR = "GOLD#"
$PERIOD = "M15"
$FROM_DATE = "2026.01.01" # Phase C: 2026 (Proven Growth Period)
$TO_DATE = "2026.04.16"

# Stage 2 Winning Parameters + Spread Penalty (+0.5pips = 5 points)
$OPT_INPUTS = "InpADXThreshold=12;InpRSIPullback=30.0;InpTPMultiplier=2.1;InpSLMultiplier=1.4"
$FIXED_INPUTS = "InpUseNews=false;InpUseHTF=true;InpStartHour=1;InpEndHour=23;InpMaxSpread=100"

Write-Host "`n=== Fol_TrendScalper v1.5 [ENVIRONMENT PROOF: 2026 - MODEL 1] ===" -ForegroundColor Green
Write-Host "Symbol: $PAIR ($PERIOD)"
Write-Host "Range: $FROM_DATE to $TO_DATE"
Write-Host "Mode: 1-YEAR M1-OHLC (Proof of Health)"

$cmdArgs = @("-ExecutionPolicy", "Bypass", "-File", $PS_SCRIPT, 
             "-EAFolder", $EAFolder, "-EAFile", $EAFile, 
             "-Pair", $PAIR, "-Period", $PERIOD,
             "-Risk", "1.0", "-Optimize", "0", 
             "-Model", "1",                    # 1-MIN OHLC (FAST PROOF)
             "-Spread", "35",                  # Penalty Applied
             "-FromDate", $FROM_DATE, "-ToDate", $TO_DATE,
             "-ExtraInputs", "$OPT_INPUTS;$FIXED_INPUTS",
             "-CustomSuffix", "S2_2026_DIAG")

Start-Process -FilePath "powershell.exe" -ArgumentList $cmdArgs -Wait -NoNewWindow

Write-Host "`nPhase A (2023) Complete." -ForegroundColor Green
