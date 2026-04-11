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
    [string]$ExtraInputs = "", # 追加のパラメータ文字列 (InpA=1;InpB=2)
    [string]$FromDate = "2026.01.01",
    [string]$ToDate = "2026.04.11"
)

$ConfigPath = Join-Path (Split-Path $PSCommandPath) "env_config.ps1"
. $ConfigPath

# Ensure MT5 is closed before starting with new config
Write-Host "Checking for running MT5 terminal..."
$terminals = Get-Process | Where-Object { $_.Name -eq "terminal64" }
if ($terminals) {
    Write-Host "Closing running MT5 instance to apply configuration..." -ForegroundColor Yellow
    $terminals | Stop-Process -Force
    Start-Sleep -Seconds 3
}

$EAPaths = Get-EA-Paths -EAFolder $EAFolder -EAName $EAFile

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

# Replace semicolons with actual newlines for the .ini file
$ParamsForIni = $ExtraInputs -replace ';', "`r`n"

$ConfigContent = @"
[Tester]
Expert=$($EAPaths.BaseName)
Symbol=$Pair
Period=$Period
Model=0
FromDate=$($FromDate)
ToDate=$($ToDate)
Deposit=10000
Currency=USD
Leverage=1:1000
Report=$ReportFileName
ReplaceReport=1
ShutdownTerminal=1
Visual=0

[TesterInputs]
InpRiskPercent=$Risk
$ParamsForIni
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
