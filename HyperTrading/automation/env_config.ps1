# Shared Environment Configuration for MT5 Automation
$TerminalPath = "C:\Program Files\XMTrading MT5\terminal64.exe"
$EditorPath = "C:\Program Files\XMTrading MT5\metaeditor64.exe"
$DataDir = "c:\Users\user\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675"

# Utility functions
function Get-EA-Paths($EAName) {
    return @{
        Source = "$DataDir\MQL5\Experts\Active\$EAName\$EAName.mq5"
        BaseName = "Active\$EAName\$EAName"
        ReportDir = "$DataDir\MQL5\Experts\Active\$EAName\BacktestResults_Opt"
    }
}
