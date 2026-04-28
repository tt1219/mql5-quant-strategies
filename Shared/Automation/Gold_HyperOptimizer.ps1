# Gold Ultimate Scalper 最適化オーケストレーター (Gold_HyperOptimizer.ps1)
param (
    [string]$EAFolder = "Gold_UltimateScalper",
    [string]$EAFile = "Gold_UltimateScalper"
)

$ConfigPath = Join-Path (Split-Path $PSCommandPath) "env_config.ps1"
. $ConfigPath

$EAPaths = Get-EA-Paths -EAFolder $EAFolder -EAName $EAFile
$PS_SCRIPT = Join-Path (Split-Path $PSCommandPath) "AutoBacktest.ps1"
$JS_AGGREGATOR = Join-Path (Split-Path $PSCommandPath) "aggregator.js"
$RESULT_DIR = $EAPaths.ReportDir

# 探索パラメータ設定 (start||step||stop)
# 1. アジアエンジン: 偏差とRSIのしきい値
# 2. ブレイクアウト: バッファ距離
# 3. 共通: TP/SLのバランス
$ExtraParams = "InpAsianBBDev=1.5||0.1||2.5||Y;InpAsianRSILower=25||5||35||Y;InpAsianRSIUpper=65||5||75||Y;InpBreakoutBuffer=30||10||80||Y;InpRangeLookback=4||2||8||Y;InpStopLoss=150||50||300||Y;InpTakeProfit=300||50||600||Y"

$PAIRS = @("GOLD#")
$PERIODS = @("M5", "M15", "M30")
$RISK = 1.0

Write-Host "`n=== Starting Gold Parameter Optimization === " -ForegroundColor Cyan
Write-Host "Target: $EAFile on $PAIRS"

$Jobs = @()

foreach ($period in $PERIODS) {
    Write-Host ">>> Starting Optimization Job for $period ..." -ForegroundColor Yellow
    
    $cmdArgs = @("-ExecutionPolicy", "Bypass", "-File", $PS_SCRIPT, 
                 "-EAFolder", $EAFolder, "-EAFile", $EAFile, 
                 "-Optimize", "2", # 2 = 遺伝的アルゴリズム (Genetic)
                 "-Pair", "GOLD#", "-Risk", $RISK, 
                 "-Period", $period, "-ExtraInputs", $ExtraParams,
                 "-CustomSuffix", "OPT")

    # 並列実行するとMT5のインスタンスが衝突する可能性があるため、各時間軸を順番に実行
    Start-Process -FilePath "powershell.exe" -ArgumentList $cmdArgs -Wait -NoNewWindow
}

Write-Host "`nOptimization Complete. Reports generated in $RESULT_DIR" -ForegroundColor Green

# 集計 (もしaggregatorが.xmlに対応していれば)
# node $JS_AGGREGATOR $EAFolder
