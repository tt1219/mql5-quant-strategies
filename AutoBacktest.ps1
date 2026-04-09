# MT5 パラメータ駆動バックテストスクリプト (v2.1)
param (
    [string]$Pair = "USDJPY",
    [double]$Risk = 2.0,
    [double]$Dev = 1.5,
    [string]$Period = "M15"
)

$TerminalPath = "C:\Program Files\XMTrading MT5\terminal64.exe"
$EditorPath = "C:\Program Files\XMTrading MT5\metaeditor64.exe"
$DataDir = "c:\Users\user\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675"
$ExpertSource = "$DataDir\MQL5\Experts\BollingerReverseEA_Hyper.mq5"
$ExpertBaseName = "BollingerReverseEA_Hyper.ex5"

$FinalReportDir = "$DataDir\MQL5\Experts\BacktestResults_Opt"
if (!(Test-Path $FinalReportDir)) { New-Item -ItemType Directory -Path $FinalReportDir }

# 1. 自動コンパイル
Write-Host "Compiling Expert Advisor..." -ForegroundColor Cyan
Start-Process -FilePath $EditorPath -ArgumentList "/compile:`"$ExpertSource`"", "/log" -Wait

# 2. バックテスト実行
Write-Host "`n--- Testing $Pair (Risk=$Risk%, Dev=$Dev, Period=$Period) ---" -ForegroundColor Cyan

$ReportFileName = "OptReport_$($Pair)_$($Period)_R$($Risk)_D$($Dev).html"
$IniFile = "$env:TEMP\mt5_opt_config_$($Pair).ini"

$ConfigContent = @"
[Tester]
Expert=$ExpertBaseName
Symbol=$Pair
Period=$Period
Model=0
FromDate=2025.01.01
ToDate=2026.01.01
Deposit=10000
Currency=USD
Leverage=1:1000
Report=$ReportFileName
ReplaceReport=1
ShutdownTerminal=1
Visual=0

[TesterInputs]
InpRiskPercent=$Risk
InpBandsDev=$Dev
InpSLMultiplier=1.2
InpStartHour=8
InpEndHour=20
"@
$ConfigContent | Out-File -FilePath $IniFile -Encoding unicode

Write-Host "Starting MT5..."
Start-Process -FilePath $TerminalPath -ArgumentList "/config:`"$IniFile`"" -Wait

$GeneratedReport = Join-Path $DataDir $ReportFileName
if (Test-Path $GeneratedReport) {
    $FinalPath = Join-Path $FinalReportDir $ReportFileName
    Move-Item -Path $GeneratedReport -Destination $FinalPath -Force
    Write-Host "SUCCESS: Report Saved to $FinalPath" -ForegroundColor Green
    return $FinalPath
} else {
    Write-Host "FAILED: Report not found." -ForegroundColor Red
    exit 1
}
