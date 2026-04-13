# Bollinger Strategy Demo Validation Deployer
# This script launches MT5 and runs FullDeploy.mq5 to set up charts for forward testing.

$ConfigPath = Join-Path (Split-Path $PSCommandPath) "env_config.ps1"
if (Test-Path $ConfigPath) {
    . $ConfigPath
} else {
    Write-Error "env_config.ps1 not found!"
    exit 1
}

Write-Host "--- Bollinger Demo Validation Deployment ---" -ForegroundColor Cyan

# 1. EA とデプロイスクリプトのコンパイル
Write-Host "Compiling assets..." -ForegroundColor Gray
$EA_Path = "$DataDir\MQL5\Experts\Strategies\Rev_Bollinger\Rev_Bollinger.mq5"
$Script_Path = "$DataDir\MQL5\Scripts\Tools\Deploy\FullDeploy.mq5"

Start-Process -FilePath $EditorPath -ArgumentList "/compile:`"$EA_Path`"", "/log" -Wait
Start-Process -FilePath $EditorPath -ArgumentList "/compile:`"$Script_Path`"", "/log" -Wait

# 2. MT5 起動用設定ファイルの作成
$IniFile = "$env:TEMP\mt5_demo_deploy.ini"
$ConfigContent = @"
[Common]
Script=Tools\Deploy\FullDeploy
"@
$ConfigContent | Out-File -FilePath $IniFile -Encoding unicode

# 3. MT5 の起動
Write-Host "Launching MT5 for Demo Validation..." -ForegroundColor Green
Write-Host "Note: Ensure you are logged into your DEMO account." -ForegroundColor Yellow

# /portable モードが必要な場合は追加してください。
# 通常の起動でデプロイスクリプトを走らせます。
Start-Process -FilePath $TerminalPath -ArgumentList "/config:`"$IniFile`""

Write-Host "Deployment command sent. Check MT5 terminal for results." -ForegroundColor Cyan
