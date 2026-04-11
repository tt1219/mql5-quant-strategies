# MT5 パラメータ駆動バックテストスクリプト (v3.0 - Generic)
param (
    [string]$EAFolder = "BollingerHyper",
    [string]$EAFile = "BollingerReverseEA_Hyper",
    [string]$Pair = "USDJPY",
    [double]$Risk = 2.0,
    [double]$Dev = 1.5,
    [string]$Period = "M15",
    [int]$ADX = 25,
    [int]$NewsMins = 10,
    [int]$UseNewsFilter = 1,
    [string]$ExtraInputs = "" # 追加のパラメータ文字列 (InpA=1;InpB=2)
)

$ConfigPath = Join-Path (Split-Path $PSCommandPath) "env_config.ps1"
. $ConfigPath

$EAPaths = Get-EA-Paths -EAName $EAFolder
# ファイル名がフォルダ名と異なる場合の個別上書き
if ($EAFile -ne $EAFolder) {
    $EAPaths.Source = "$DataDir\MQL5\Experts\Active\$EAFolder\$EAFile.mq5"
    $EAPaths.BaseName = "Active\$EAFolder\$EAFile"
}

$BoolUseNewsFilter = ($UseNewsFilter -eq 1)

$FinalReportDir = $EAPaths.ReportDir
if (!(Test-Path $FinalReportDir)) { New-Item -ItemType Directory -Path $FinalReportDir }

# Report ファイル名に News-Off を付与するためのサフィックス
$Suffix = if ($BoolUseNewsFilter) { "" } else { "_NewsOFF" }

# 1. 自動コンパイル
Write-Host "Compiling Expert Advisor..." -ForegroundColor Cyan
Start-Process -FilePath $EditorPath -ArgumentList "/compile:`"$($EAPaths.Source)`"", "/log" -Wait

# 2. バックテスト実行
Write-Host "`n--- Testing $Pair (Risk=$Risk%, Dev=$Dev, Period=$Period, NewsFilter=$BoolUseNewsFilter) ---" -ForegroundColor Cyan

$SafePair = $Pair -replace '#', '_SHARP'
$ReportFileName = "OptReport_$($SafePair)_$($Period)_R$($Risk)_D$($Dev)_A$($ADX)$($Suffix).html"
$IniFile = "$env:TEMP\mt5_opt_config_$($SafePair).ini"

$ConfigContent = @"
[Tester]
Expert=$($EAPaths.BaseName)
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
InpADXThreshold=$ADX
InpUseNewsFilter=$BoolUseNewsFilter
InpNewsMinsBefore=$NewsMins
InpNewsMinsAfter=$NewsMins
$ExtraInputs
"@
$ConfigContent | Out-File -FilePath $IniFile -Encoding unicode

Write-Host "Starting MT5..."
Start-Process -FilePath $TerminalPath -ArgumentList "/config:`"$IniFile`"" -Wait

# 待機とリトライ (MT5のファイル出力ラグ対策)
$GeneratedReport = Join-Path $DataDir $ReportFileName
$WaitCount = 0
while (!(Test-Path $GeneratedReport) -and $WaitCount -lt 10) {
    Start-Sleep -Seconds 2
    $WaitCount++
}

if (Test-Path $GeneratedReport) {
    if (!(Test-Path $FinalReportDir)) { New-Item -ItemType Directory -Path $FinalReportDir }
    $FinalPath = Join-Path $FinalReportDir $ReportFileName
    Move-Item -Path $GeneratedReport -Destination $FinalPath -Force
    Write-Host "SUCCESS: Report Saved to $FinalPath" -ForegroundColor Green
    return $FinalPath
} else {
    Write-Host "FAILED: Report not found." -ForegroundColor Red
    exit 1
}
