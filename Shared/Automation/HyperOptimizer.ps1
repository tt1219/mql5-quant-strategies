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
$NEWS_MINS = 30

Write-Host "`n=== Starting Grid Search for BB Hyper ($EAFile) ===" -ForegroundColor Cyan

# DEVIATION (1.5 to 2.0) と ADX (25 to 30) をMT5側の最適化機能で回すように設定
$ExtraParams = "InpRSIPullback=1.5||1.5||0.5||2.0||Y;InpUseNews=true;InpADXThreshold=25||25||5||30||Y"

$Jobs = @()

foreach ($pair in $PAIRS) {
    $ScriptBlock = {
        param($PS_SCRIPT, $EAFolder, $EAFile, $pair, $PERIODS, $RISK_LEVELS, $ExtraParams)
        foreach ($period in $PERIODS) {
            foreach ($risk in $RISK_LEVELS) {
                Write-Host ">>> Run: $pair ($period) R$risk ..." -ForegroundColor Yellow
                $cmdArgs = @("-ExecutionPolicy", "Bypass", "-File", $PS_SCRIPT, 
                             "-EAFolder", $EAFolder, "-EAFile", $EAFile, 
                             "-Optimize", "1",
                             "-Pair", $pair, "-Risk", $risk, 
                             "-Period", $period, "-ExtraInputs", $ExtraParams)
                
                try {
                    Start-Process -FilePath "powershell.exe" -ArgumentList $cmdArgs -Wait -NoNewWindow -ErrorAction Stop
                } catch { continue }
            }
        }
    }
    $Jobs += Start-Job -ScriptBlock $ScriptBlock -ArgumentList $PS_SCRIPT, $EAFolder, $EAFile, $pair, $PERIODS, $RISK_LEVELS, $ExtraParams
}

Write-Host "Waiting for BB optimization jobs to finish..." -ForegroundColor Cyan
Wait-Job -Job $Jobs | Out-Null
Receive-Job -Job $Jobs
Remove-Job -Job $Jobs

# Run Aggregator
Write-Host "`nFinalizing Report..." -ForegroundColor Cyan
node $JS_AGGREGATOR $EAFolder

$report_md = Join-Path $RESULT_DIR "..\reports\full_backtest_report.md"
if (Test-Path $report_md) {
    Write-Host "`nGrid Scan Complete. Report: $report_md" -ForegroundColor Green
}
