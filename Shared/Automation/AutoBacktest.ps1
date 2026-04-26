# MT5 Direct Context Backtest (v5.2 - Official Stage 2 Support)
param (
    [string]$EAFolder = "BollingerHyper",
    [string]$EAFile = "BollingerReverseEA_Hyper",
    [string]$Pair = "USDJPY",
    [double]$Risk = 2.0,
    [double]$Dev = 1.5,
    [string]$Period = "M15",
    [int]$ADX = 25,
    [string]$ExtraInputs = "", 
    [string]$FromDate = "2026.01.01",
    [string]$ToDate = "2026.04.16",
    [int]$Deposit = 1000000,
    [int]$Model = 0,
    [int]$Optimize = 0,
    [int]$Spread = 0,
    [string]$CustomSuffix = "" 
)

$ConfigPath = Join-Path (Split-Path $PSCommandPath) "env_config.ps1"
. $ConfigPath

# --- NO ISOLATION MODE ---
$TargetDir = $DataDir
$TerminalExe = $TerminalPath

Write-Host "DIRECT ENGINE IGNITION: Running in Main MQL5 Directory ($TargetDir)" -ForegroundColor Magenta

# パスの解決
$EAPaths = Get-EA-Paths -EAFolder $EAFolder -EAName $EAFile
$SafePairFileName = $Pair -replace '#', '_SHARP'
$ReportExt = if ($Optimize -gt 0) { ".xml" } else { ".html" }
$ReportFileName = "OptReport_$($SafePairFileName)_$($Period)_R$($Risk)$($CustomSuffix)$ReportExt"
$IniFile = Join-Path $TargetDir "final_direct_diag.ini"
$ReportPathForIni = "MQL5\Files\$ReportFileName"
$ParamsForIni = $ExtraInputs -replace ';', "`r`n"

# INI の生成
$ConfigContent = @"
[Tester]
Expert=$($EAPaths.BaseName)
Symbol=$Pair
Period=$Period
Model=$Model
Optimization=$Optimize
FromDate=$($FromDate)
ToDate=$($ToDate)
Deposit=$Deposit
Currency=JPY
Leverage=1000
Spread=$Spread
Report=$ReportPathForIni
ReplaceReport=1
ShutdownTerminal=1
Visual=0

[TesterInputs]
InpRiskPercent=$Risk
$ParamsForIni
"@
[System.IO.File]::WriteAllText($IniFile, $ConfigContent, [System.Text.Encoding]::Unicode)

Write-Host "`n--- MT5 Verification Run: $($CustomSuffix) for $Pair ---" -ForegroundColor Cyan
Write-Host "Expert: $($EAPaths.BaseName)"
Write-Host "Model: $Model, Spread: $Spread, Range: $FromDate - $ToDate"

# コマンド実行 (メイン環境)
Stop-Process -Name terminal64 -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process -FilePath $TerminalExe -ArgumentList "/config:`"$IniFile`"" -Wait -NoNewWindow

# Report Move
if ($ReportFileName -eq "") { Write-Error "ReportFileName empty"; exit 1 }
$GeneratedReport = Join-Path $DataDir "MQL5\Files\$ReportFileName"
if (Test-Path $GeneratedReport) {
    if (!(Test-Path $EAPaths.ReportDir)) { New-Item -ItemType Directory -Path $EAPaths.ReportDir }
    Move-Item -Path $GeneratedReport -Destination (Join-Path $EAPaths.ReportDir $ReportFileName) -Force
    Write-Host "SUCCESS: $ReportFileName" -ForegroundColor Green
} else {
    Write-Host "FAILED: No report generated for $Pair" -ForegroundColor Red
}
