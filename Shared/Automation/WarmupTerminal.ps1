$TerminalPath = "C:\Program Files\XMTrading MT5\terminal64.exe"
$IniFile = "$env:TEMP\mt5_warmup_config.ini"

$ConfigContent = @"
[Common]
Login=56238867
ProxyEnable=0
CertConfirm=0

[Charts]
MaxBars=100000

[Expert]
AllowLiveTrading=0
AllowDllImport=1
Enabled=1

[Tester]
Expert=SymbolDownloader.ex5
Symbol=EURUSD
Period=H1
Visual=0
"@
$ConfigContent | Out-File -FilePath $IniFile -Encoding unicode

Write-Host "--- Warming up MT5 Terminal for History Sync (Estimated 3 mins) ---" -ForegroundColor Cyan
$process = Start-Process -FilePath $TerminalPath -ArgumentList "/config:`"$IniFile`"" -PassThru

# Wait for 3 minutes for the EA to trigger downloads
Start-Sleep -Seconds 180

Write-Host "--- Syncing complete, closing terminal ---" -ForegroundColor Green
Stop-Process -Id $process.Id -Force
