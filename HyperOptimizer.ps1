$PS_SCRIPT = "c:\Users\user\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675\MQL5\Experts\AutoBacktest.ps1"
$RESULT_DIR = "c:\Users\user\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675\MQL5\Experts\BacktestResults_Opt"
$PAIRS = @("USDJPY", "EURUSD", "GBPUSD")
$RISK_LEVELS = @(2.0)
$PERIODS = @("H1")
$DEV_LEVELS = @(2.0, 2.3)
$ADX_LEVELS = @(20, 25, 30)

$Results = @()

foreach ($pair in $PAIRS) {
    foreach ($period in $PERIODS) {
        foreach ($risk in $RISK_LEVELS) {
            foreach ($dev in $DEV_LEVELS) {
                foreach ($adx in $ADX_LEVELS) {
                    Write-Host "Running: $pair ($period) Dev=$dev ADX=$adx..." -ForegroundColor Yellow
                    $cmdArgs = @("-ExecutionPolicy", "Bypass", "-File", $PS_SCRIPT, "-Pair", $pair, "-Risk", $risk, "-Dev", $dev, "-Period", $period, "-ADX", $adx)
                    
                    # Start the backtest script
                    Start-Process -FilePath "powershell.exe" -ArgumentList $cmdArgs -Wait
                    
                    $report_file = Join-Path $RESULT_DIR "OptReport_$pair`_$period`_R$risk`_D$dev`_A$adx.html"
                    
                    if (Test-Path $report_file) {
                        $html = Get-Content -Path $report_file -Raw -Encoding Unicode
                        
                        $net_profit = 0
                        $profit_factor = 0
                        $drawdown = 0
                        
                        $bold_matches = [regex]::Matches($html, '<b>([-\d\s.,%()]+)</b>')
                        $deposit_index = -1
                        for ($i=0; $i -lt $bold_matches.Count; $i++) {
                            if ($bold_matches[$i].Groups[1].Value -match '^10\s*000') {
                                $deposit_index = $i
                                break
                            }
                        }
                        
                        if ($deposit_index -ge 0) {
                            $net_profit = [double]($bold_matches[$deposit_index + 5].Groups[1].Value -replace '[\s,]','')
                            $profit_factor = [double]($bold_matches[$deposit_index + 14].Groups[1].Value -replace '[\s,]','')
                            if ($bold_matches[$deposit_index + 9].Groups[1].Value -match '\(([\d\.]+)\%\)') {
                                $drawdown = [double]$matches[1]
                            }
                        }
                        
                        $Results += [PSCustomObject]@{
                            Pair = $pair
                            Period = $period
                            Risk = $risk
                            Dev = $dev
                            ADX = $adx
                            NetProfit = $net_profit
                            ProfitFactor = $profit_factor
                            Drawdown = $drawdown
                        }
                        Write-Host "Result -> $pair ($period) NetProfit: $net_profit, ProfitFactor: $profit_factor, Drawdown: $drawdown%" -ForegroundColor Green
                    } else {
                        Write-Host "Failed to find report for $pair ($period) Dev=$dev ADX=$adx" -ForegroundColor Red
                    }
                }
            }
        }
    }
}

$Results | Export-Csv -Path "optimization_results.csv" -NoTypeInformation
Write-Host "`n--- Optimization Complete (v4.30) ---" -ForegroundColor Cyan
$Results | Format-Table
