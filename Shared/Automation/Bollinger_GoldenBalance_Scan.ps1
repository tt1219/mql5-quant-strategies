# Bollinger_GoldenBalance_Scan.ps1
$ErrorActionPreference = "Stop"

$BaseDir = "c:\Users\user\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675\MQL5\Shared\Automation"
$ResultDir = "c:\Users\user\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675\MQL5\Experts\Strategies\Rev_Bollinger\BacktestResults_Opt"
$AutoScript = Join-Path $BaseDir "AutoBacktest.ps1"

if (!(Test-Path $ResultDir)) { New-Item -ItemType Directory -Path $ResultDir }

$Pair = "EURUSD#"
$TF = "M15"
$Devs = @(1.8, 1.9, 2.0)
$RSIs = @(31, 32, 33, 34)

Write-Host "=== Starting Golden Balance Scan (Plan 1) ===" -ForegroundColor Yellow

$Jobs = @()
$MaxConcurrent = 4

foreach ($Dev in $Devs) {
    foreach ($RSI_L in $RSIs) {
        $RSI_U = 100 - $RSI_L
        $Suffix = "Golden_Dev$($Dev)_RSI$($RSI_L)"
        $Inps = "InpBandsDev=$Dev;InpRSILower=$RSI_L;InpRSIUpper=$RSI_U;InpUseNews=true;InpUseEMAFilter=false;InpAutoPreset=false;InpADXThreshold=20"
        
        $Job = Start-Job -ScriptBlock {
            param($Script, $Pair, $TF, $Suffix, $Inps)
            & $Script -EAFolder "Rev_Bollinger" -EAFile "Rev_Bollinger" -Pair $Pair -Period $TF -CustomSuffix $Suffix -ExtraInputs $Inps -FromDate "2025.04.12" -ToDate "2026.04.12" -Model 1
        } -ArgumentList $AutoScript, $Pair, $TF, $Suffix, $Inps
        
        $Jobs += $Job
        Write-Host "Started Job: $Suffix"
        
        while (($Jobs | Where-Object { $_.State -eq 'Running' }).Count -ge $MaxConcurrent) {
            Start-Sleep -Seconds 5
        }
    }
}

Write-Host "Waiting for Golden Balance tests to finish..." -ForegroundColor Cyan
Wait-Job -Job $Jobs | Out-Null

Write-Host "Aggregating Golden Balance Results..." -ForegroundColor Green
node aggregator.js Rev_Bollinger

Write-Host "Golden Balance Scan Complete." -ForegroundColor Green
