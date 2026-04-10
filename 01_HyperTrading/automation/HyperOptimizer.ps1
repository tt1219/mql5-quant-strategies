$PS_SCRIPT = "c:\Users\user\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675\MQL5\Experts\01_HyperTrading\automation\HyperTester.ps1"
$RESULT_DIR = "c:\Users\user\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675\MQL5\Experts\01_HyperTrading\BacktestResults_Opt"

# Verified Winners from v4.54
$PAIRS = @("AUDUSD#", "EURUSD", "GBPUSD", "USDCAD#")

# High Frequency Grid
$PERIODS = @("H1", "M30", "M15")
$DEV_LEVELS = @(2.0, 1.8, 1.5)
$ADX_LEVELS = @(25, 30, 35)

$Results = @()

foreach ($pair in $PAIRS) {
    foreach ($period in $PERIODS) {
        foreach ($dev in $DEV_LEVELS) {
            foreach ($adx in $ADX_LEVELS) {
                Write-Host "High Freq Scan (v4.61): $pair ($period) D$dev A$adx..." -ForegroundColor Yellow
                $cmdArgs = @("-ExecutionPolicy", "Bypass", "-File", $PS_SCRIPT, "-Pair", $pair, "-Risk", 2.0, "-Dev", $dev, "-Period", $period, "-ADX", $adx)
                
                try {
                    Start-Process -FilePath "powershell.exe" -ArgumentList $cmdArgs -Wait -ErrorAction Stop
                } catch {
                    continue
                }
                
                $report_file = Join-Path $RESULT_DIR "OptReport_$($pair)_$($period)_R2_D$($dev)_A$($adx).html"
                
                if (Test-Path $report_file) {
                    $html = Get-Content -Path $report_file -Raw -Encoding Unicode
                    $bold_matches = [regex]::Matches($html, '<b>([-\d\s.,%()]+)</b>')
                    $deposit_index = -1
                    for ($i=0; $i -lt $bold_matches.Count; $i++) {
                        if ($bold_matches[$i].Groups[1].Value -match '^10\s*000') {
                            $deposit_index = $i
                            break
                        }
                    }
                    
                    if ($deposit_index -ge 0) {
                        try {
                            $net_profit = [double]($bold_matches[$deposit_index + 5].Groups[1].Value -replace '[\s,]','')
                            $total_trades = [int]($bold_matches[$deposit_index + 12].Groups[1].Value -replace '[\s,]','')
                            $profit_factor = [double]($bold_matches[$deposit_index + 14].Groups[1].Value -replace '[\s,]','')
                            $Results += [PSCustomObject]@{
                                Pair = $pair; Period=$period; Dev=$dev; ADX=$adx; NetProfit=$net_profit; ProfitFactor=$profit_factor; Trades=$total_trades
                            }
                            Write-Host "Result -> $($pair) ($period, D$dev): PF: $profit_factor, Trades: $total_trades"
                        } catch {}
                    }
                }
            }
        }
    }
}

$Results | Sort-Object Trades -Descending | Export-Csv -Path "c:\Users\user\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675\MQL5\Experts\01_HyperTrading\data\high_freq_results_v4.61.csv" -NoTypeInformation
$Results | Sort-Object Trades -Descending | Format-Table
