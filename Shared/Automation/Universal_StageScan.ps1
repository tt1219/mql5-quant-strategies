# Universal Stage Validation Orchestrator (v1.0)
# Usage: powershell -File Universal_StageScan.ps1 -Stage 1
param (
    [int]$Stage = 1,
    [string]$TargetStrategy = "" # Optional: Limit to one strategy
)

$ManifestPath = Join-Path (Split-Path $PSCommandPath) "validation_manifest.json"
if (!(Test-Path $ManifestPath)) { Write-Error "Manifest not found: $ManifestPath"; exit 1 }

$Manifest = Get-Content $ManifestPath | ConvertFrom-Json
$BacktestScript = Join-Path (Split-Path $PSCommandPath) "AutoBacktest.ps1"
$AggregatorScript = Join-Path (Split-Path $PSCommandPath) "aggregator.js"

Write-Host "=== Universal Stage $Stage Validation Started ===" -ForegroundColor Cyan

foreach ($strategy in $Manifest.strategies) {
    if ($TargetStrategy -ne "" -and $strategy.name -ne $TargetStrategy) { continue }

    Write-Host "`n--- Strategy: $($strategy.name) ---" -ForegroundColor Yellow
    
    $stageName = $Stage.ToString()
    $stageConfig = $strategy.stages.$stageName

    if ($null -eq $stageConfig) {
        Write-Warning "Stage $Stage not defined for $($strategy.name). Skipping."
        continue
    }

    foreach ($symbol in $strategy.symbols) {
        foreach ($tf in $strategy.timeframes) {
            Write-Host "[SCAN] $symbol ($tf) | Range: $($stageConfig.from) - $($stageConfig.to)" -ForegroundColor Gray
            
            $cmdArgs = @("-ExecutionPolicy", "Bypass", "-File", $BacktestScript, 
                         "-EAFolder", "$($strategy.folder)", "-EAFile", "$($strategy.name)", 
                         "-Pair", "$symbol", "-Period", "$tf",
                         "-Risk", "$($stageConfig.risk)", "-Optimize", "0", 
                         "-Model", "$($stageConfig.model)",
                         "-Spread", "$($stageConfig.spread)",
                         "-FromDate", "$($stageConfig.from)", "-ToDate", "$($stageConfig.to)",
                         "-ExtraInputs", "$($stageConfig.extraInputs)",
                         "-CustomSuffix", "STAGE$Stage")

            # Run Backtest
            $process = Start-Process -FilePath "powershell.exe" -ArgumentList $cmdArgs -Wait -NoNewWindow -PassThru
            
            if ($process.ExitCode -ne 0) {
                Write-Error "Backtest failed for $symbol $tf"
            }
        }
    }

    # Aggregate results for this strategy
    Write-Host "`n[INFO] Aggregating results for $($strategy.name)..." -ForegroundColor Green
    node $AggregatorScript $strategy.folder
}

Write-Host "`n=== All Tasks Complete ===" -ForegroundColor Green
