# MT5 グリッドサーチ・オーケストレーター (v2.0)
param (
    [string]$EAFolder = "BollingerHyper",
    [string]$EAFile = "BollingerReverseEA_Hyper"
)

$ConfigPath = Join-Path (Split-Path $PSCommandPath) "env_config.ps1"
. $ConfigPath

$EAPaths = Get-EA-Paths -EAName $EAFolder
$PS_SCRIPT = Join-Path (Split-Path $PSCommandPath) "AutoBacktest.ps1"
$RESULT_DIR = $EAPaths.ReportDir

# Grid Search Parameters
$PAIRS = @("EURUSD#", "AUDUSD#", "GBPUSD", "USDCAD#")
$PERIODS = @("M15", "M30", "H1")
$DEVIATIONS = @(1.5, 1.8, 2.0, 2.2)
$ADX_LEVELS = @(25, 30, 35)
$NEWS_MINS = 10

$Results = @()

foreach ($pair in $PAIRS) {
    foreach ($period in $PERIODS) {
        foreach ($dev in $DEVIATIONS) {
            foreach ($adx in $ADX_LEVELS) {
                $SafePair = $pair -replace '#', '_SHARP'
                $report_file = Join-Path $RESULT_DIR "OptReport_$($SafePair)_$($period)_R2_D$($dev)_A$($adx).html"
                
                Write-Host ">>> Re-Optimize: $pair ($period) D$dev A$adx..." -ForegroundColor Yellow
                $cmdArgs = @("-ExecutionPolicy", "Bypass", "-File", $PS_SCRIPT, "-EAFolder", $EAFolder, "-EAFile", $EAFile, "-Pair", $pair, "-Risk", 2.0, "-Dev", $dev, "-Period", $period, "-ADX", $adx, "-NewsMins", $NEWS_MINS)
                
                try {
                    Start-Process -FilePath "powershell.exe" -ArgumentList $cmdArgs -Wait -ErrorAction Stop
                } catch { continue }
                
                if (Test-Path $report_file) {
                    try {
                        $html = Get-Content -Path $report_file -Raw -Encoding unicode
                        # Clean HTML formatting for easier matching
                        $cleanHtml = $html -replace '&nbsp;', ' ' -replace '\s+', ' '
                        
                        $netProfit = 0
                        $pf = 0
                        $trades = 0

                        # Match by proximity to bold tags - much more robust
                        $bolds = [regex]::Matches($cleanHtml, '<b>(.*?)</b>') | ForEach-Object { $_.Groups[1].Value.Trim() }
                        
                        # Find the "10 000.00" deposit to anchor indices
                        $anchor = -1
                        for($i=0; $i -lt $bolds.Count; $i++) {
                            if($bolds[$i] -match '10\s*000') { $anchor = $i; break }
                        }

                        if($anchor -ge 0) {
                            # Standard MT5 report offsets after deposit
                            $netProfit = [double]($bolds[$anchor + 5] -replace '[^-\d.]', '')
                            $trades = [int]($bolds[$anchor + 12] -replace '[^-\d.]', '')
                            $pf = [double]($bolds[$anchor + 14] -replace '[^-\d.]', '')

                            $Results += [PSCustomObject]@{
                                Pair = $pair; Period=$period; Dev=$dev; ADX=$adx; NetProfit=$netProfit; PF=$pf; Trades=$trades
                            }
                            $color = if($netProfit -gt 0) { "Green" } else { "Red" }
                            Write-Host "  -> Result: Profit=$netProfit, PF=$pf, Trades=$trades" -ForegroundColor $color
                        } else {
                            Write-Host "  -> Warning: Could not find stats anchor in report." -ForegroundColor Gray
                        }
                    } catch {
                        Write-Host "  -> Error parsing $report_file" -ForegroundColor Red
                    }
                }
            }
        }
    }
}

if (!(Test-Path "$RESULT_DIR\..\data")) { New-Item -ItemType Directory -Path "$RESULT_DIR\..\data" }
$csvPath = "$RESULT_DIR\..\data\re-optimization_v1.03.csv"
$Results | Sort-Object NetProfit -Descending | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host "`nGrid Scan Complete. Results: $csvPath" -ForegroundColor Cyan
$Results | Sort-Object NetProfit -Descending | Format-Table
