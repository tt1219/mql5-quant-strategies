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
    [string]$ToDate = "2026.04.11",
    [int]$Deposit = 100000,
    [string]$Currency = "JPY",
    [string]$Leverage = "1:1000",
    [int]$Model = 0, # 0: Every tick, 1: OHLC M1, 4: Real ticks
    [int]$Optimize = 0, # 0: Disabled, 1: Fast/Slow complete, 2: Genetic algorithm
    [int]$Spread = 0, # 0: Current, >0: Fixed points
    [string]$CustomSuffix = "" # カスタムサフィックス
)

$ConfigPath = Join-Path (Split-Path $PSCommandPath) "env_config.ps1"
. $ConfigPath

$SafePair = $Pair -replace '[^a-zA-Z0-9]', ''
$SafeSuffix = $CustomSuffix -replace '[^a-zA-Z0-9]', ''
$WorkerDir = "$env:TEMP\MT5_Worker_$SafePair`_$SafeSuffix"

# Ensure previous MT5 in THIS worker is closed
Write-Host "Checking for running MT5 in $WorkerDir..."
$terminals = Get-Process | Where-Object { $_.Name -eq "terminal64" -and $_.Path -like "$WorkerDir*" }
if ($terminals) {
    Write-Host "Closing worker-specific MT5 instance..." -ForegroundColor Yellow
    $terminals | Stop-Process -Force
    Start-Sleep -Seconds 2
}

$EAPaths = Get-EA-Paths -EAFolder $EAFolder -EAName $EAFile

$BoolUseNewsFilter = ($UseNewsFilter -eq 1)

$FinalReportDir = $EAPaths.ReportDir
if (!(Test-Path $FinalReportDir)) { New-Item -ItemType Directory -Path $FinalReportDir }

# Report ファイル名に News-Off を付与するためのサフィックス
$Suffix = if ($BoolUseNewsFilter) { "" } else { "_NewsOFF" }

# 1. 自動コンパイルと並列用ポータブル環境の構築
Write-Host "Preparing Isolated Worker Environment for $Pair..." -ForegroundColor Cyan
if (!(Test-Path $WorkerDir)) {
    # インストールフォルダとデータフォルダをマージしてポータブル環境を作成
    $TerminalExePath = Split-Path $TerminalPath
    robocopy $TerminalExePath $WorkerDir /E /MT:8 /XD basis /NFL /NDL /NJH /NJS | Out-Null
}
# 常に最新のMQL5スクリプトとアカウント設定(config)をコピー同期
robocopy "$DataDir\MQL5" "$WorkerDir\MQL5" /E /MT:8 /XD .git .agents /NFL /NDL /NJH /NJS | Out-Null
robocopy "$DataDir\config" "$WorkerDir\config" /E /MT:8 /NFL /NDL /NJH /NJS | Out-Null

$WorkerTerminal = "$WorkerDir\terminal64.exe"
$WorkerEditor = "$WorkerDir\metaeditor64.exe"
$WorkerEA_Path = "$WorkerDir\MQL5\Experts\Strategies\$EAFolder\$EAFile.mq5"

Write-Host "Compiling Expert Advisor in Worker..." -ForegroundColor Gray
Start-Process -FilePath $WorkerEditor -ArgumentList "/compile:`"$WorkerEA_Path`"", "/log" -Wait

# 2. バックテスト実行
Write-Host "`n--- Testing $Pair (Risk=$Risk%, Dev=$Dev, Period=$Period, NewsFilter=$BoolUseNewsFilter) ---" -ForegroundColor Cyan

$SafePair = $Pair -replace '#', '_SHARP'
$BaseSuffix = if ($BoolUseNewsFilter) { "" } else { "_NewsOFF" }
$ReportExt = if ($Optimize -gt 0) { ".xml" } else { ".html" }
$ReportFileName = "OptReport_$($SafePair)_$($Period)_R$($Risk)_D$($Dev)_A$($ADX)$($BaseSuffix)$($CustomSuffix)$ReportExt"
$IniFile = "$env:TEMP\mt5_opt_config_$($SafePair)_$($SafeSuffix).ini"
# MT5 のレポート出力は MQL5/Files からの相対パス、または絶対パス
$ReportPathForIni = "MQL5\Files\$ReportFileName"

$ParamsForIni = $ExtraInputs -replace ';', "`r`n"
$ExpertParamsPath = ""

if ($Optimize -gt 0) {
    # .set ファイルを $env:TEMP に書き込む (WorkerDir未生成タイミング問題を回避)
    $SetFileName = "opt_$($SafePair)_$($SafeSuffix).set"
    $SetPath = Join-Path $env:TEMP $SetFileName
    
    # InpRiskPercent も含めて .set に書き出す (BOMなしASCII = MT5必須フォーマット)
    $SetLines = @("InpRiskPercent=$Risk||$Risk||0.1||$Risk||N")
    $SetLines += ($ExtraInputs -split ';' | Where-Object { $_ -ne '' })
    $SetContent = $SetLines -join "`r`n"
    [System.IO.File]::WriteAllText($SetPath, $SetContent, [System.Text.Encoding]::ASCII)
    Write-Host "Set file written to: $SetPath" -ForegroundColor Gray
    # MT5はExpertParametersに絶対パスを使用できる
    $ExpertParamsPath = $SetPath
}

# 最適化時は .set ファイルで全パラメータを管理するため INI の [TesterInputs] を省略する
if ($Optimize -gt 0) {
    $ConfigContent = @"
[Tester]
Expert=$($EAPaths.BaseName)
Symbol=$Pair
Period=$Period
Model=$Model
Optimization=$Optimize
FromDate=$($FromDate)
ToDate=$($ToDate)
Deposit=$($Deposit)
Currency=$($Currency)
Leverage=$($Leverage)
Spread=$($Spread)
Report=$ReportPathForIni
ReplaceReport=1
ShutdownTerminal=1
Visual=0
ExpertParameters=$ExpertParamsPath
"@
} else {
    $ConfigContent = @"
[Tester]
Expert=$($EAPaths.BaseName)
Symbol=$Pair
Period=$Period
Model=$Model
Optimization=$Optimize
FromDate=$($FromDate)
ToDate=$($ToDate)
Deposit=$($Deposit)
Currency=$($Currency)
Leverage=$($Leverage)
Spread=$($Spread)
Report=$ReportPathForIni
ReplaceReport=1
ShutdownTerminal=1
Visual=0
ExpertParameters=$ExpertParamsPath

[TesterInputs]
InpRiskPercent=$Risk
$ParamsForIni
"@
}
[System.IO.File]::WriteAllText($IniFile, $ConfigContent, [System.Text.Encoding]::ASCII)

Write-Host "Starting Isolated MT5 for $Pair (Optimization=$Optimize) [GUI Enabled for Monitoring]..."
Start-Process -FilePath $WorkerTerminal -ArgumentList "/portable", "/config:`"$IniFile`"" -Wait

# 待機とリトライ (MT5のファイル出力ラグ対策)
$GeneratedReport = Join-Path $WorkerDir "MQL5\Files\$ReportFileName"
$WaitCount = 0
$MaxWait = 30
if ($Optimize -gt 0) { $MaxWait = 300 }
while (!(Test-Path $GeneratedReport) -and $WaitCount -lt $MaxWait) {
    Start-Sleep -Seconds 2
    $WaitCount++
    if ($WaitCount % 5 -eq 0) { Write-Host "Waiting for report ($WaitCount/$MaxWait)..." }
}

if (Test-Path $GeneratedReport) {
    if (!(Test-Path $FinalReportDir)) { New-Item -ItemType Directory -Path $FinalReportDir }
    $FinalPath = Join-Path $FinalReportDir $ReportFileName
    Move-Item -Path $GeneratedReport -Destination $FinalPath -Force
    Write-Host "SUCCESS: Report Saved to $FinalPath" -ForegroundColor Green
    
    # クリーンアップ: この WorkerDir を削除
    Write-Host "Cleaning up $WorkerDir..." -ForegroundColor Gray
    Remove-Item -Path $WorkerDir -Recurse -Force -ErrorAction SilentlyContinue 
    
    return $FinalPath
} else {
    Write-Host "FAILED: Report not found after $WaitCount checks. Manual investigation required in $WorkerDir" -ForegroundColor Red
    # 失敗してもクリーンアップ (Debugのため停止)
    # Remove-Item -Path $WorkerDir -Recurse -Force -ErrorAction SilentlyContinue 
    exit 1
}
