# MT5 グリッドサーチ・オーケストレーター (v3.0)
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

# Grid Search Parameters
$PAIRS = @("EURUSD#", "GBPUSD", "XAUUSD#")
$PERIODS = @("M5", "M15")
$RISK_LEVELS = @(0.5, 1.0, 2.0)
$DEVIATIONS = @(1.5, 2.0)
$ADX_LEVELS = @(25, 30)
$NEWS_MINS = 30

Write-Host "`n=== Starting Grid Search for $EAFile ===" -ForegroundColor Cyan

foreach ($pair in $PAIRS) {
    foreach ($period in $PERIODS) {
        foreach ($risk in $RISK_LEVELS) {
            foreach ($dev in $DEVIATIONS) {
                foreach ($adx in $ADX_LEVELS) {
                    Write-Host ">>> Run: $pair ($period) R$risk D$dev A$adx..." -ForegroundColor Yellow
                    $ExtraParams = "InpRSIPullback=$dev;InpUseNews=true"
                    $cmdArgs = @("-ExecutionPolicy", "Bypass", "-File", $PS_SCRIPT, 
                                 "-EAFolder", $EAFolder, "-EAFile", $EAFile, 
                                 "-Pair", $pair, "-Risk", $risk, 
                                 "-Period", $period, "-ExtraInputs", $ExtraParams)
                    
                    try {
                        Start-Process -FilePath "powershell.exe" -ArgumentList $cmdArgs -Wait -ErrorAction Stop
                    } catch { continue }
                }
            }
        }
    }
}

# Run Aggregator
Write-Host "`nFinalizing Report..." -ForegroundColor Cyan
node $JS_AGGREGATOR $EAFolder

$report_md = Join-Path $RESULT_DIR "..\reports\full_backtest_report.md"
if (Test-Path $report_md) {
    Write-Host "`nGrid Scan Complete. Report: $report_md" -ForegroundColor Green
}
