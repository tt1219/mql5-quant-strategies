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
$FROM_DATE = "2025.04.12"
$TO_DATE = "2026.04.11"

# Construction of Optimization Ranges (Value||Start||Step||Stop||Enabled)
$OPT_INPUTS = "InpRSIPullback=35||30||5||40||Y;InpADXThreshold=25||20||5||30||Y;InpSLMultiplier=2.0||1.5||0.5||2.5||Y;InpTPMultiplier=1.0||1.0||0.5||2.0||Y"
# Total: 3 x 3 x 3 x 3 = 81 patterns
$FIXED_INPUTS = "InpBETrigger=0.5||0.5||0.1||0.5||N;InpBBExpRatio=1.1||1.1||0.1||1.1||N;InpUseNews=false||false||0||false||N"

Write-Host "`n=== Fol_TrendScalper v1.5 [GOLD NATIVE OPTIMIZATION] ===" -ForegroundColor Cyan
Write-Host "Symbol: $PAIR ($PERIOD)"
Write-Host "Range: $FROM_DATE to $TO_DATE"
Write-Host "Mode: Slow Complete (Grid Search)"

$cmdArgs = @("-ExecutionPolicy", "Bypass", "-File", $PS_SCRIPT, 
             "-EAFolder", $EAFolder, "-EAFile", $EAFile, 
             "-Pair", $PAIR, "-Period", $PERIOD,
             "-Risk", "1.0", "-Optimize", "1", # 1: Slow Complete
             "-FromDate", $FROM_DATE, "-ToDate", $TO_DATE,
             "-ExtraInputs", "$OPT_INPUTS;$FIXED_INPUTS",
             "-CustomSuffix", "GoldenNative")

Start-Process -FilePath "powershell.exe" -ArgumentList $cmdArgs -Wait -NoNewWindow

# NOTE: Optimization generates an .xml report. Aggregator might need update to support XML.
Write-Host "`nScan Complete. Please check the reports directory." -ForegroundColor Green
