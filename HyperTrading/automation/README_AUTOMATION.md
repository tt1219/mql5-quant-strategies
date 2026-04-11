# Hyper Strategy Automation Tools

BollingerReverseEA_Hyper の最適化と集計を行うためのコアツール群です。

## 主要スクリプト

1. **`HyperOptimizer.ps1`**  
   - **役割**: グリッドサーチ全体の司令官。
   - **機能**: 108通りの「銘柄 × 時間軸 × 偏差 × ADX」を順番に `AutoBacktest.ps1` に投げ、全レポートを自動生成します。

2. **`AutoBacktest.ps1`**  
   - **役割**: MT5 の実行エンジン。
   - **機能**: 指定されたパラメータで MT5 を起動し、バックテストを実行して HTML レポートを出力・保存します。ニュースフィルター設定もここで管理されます。

3. **`aggregator.js`** (Node.js)  
   - **役割**: 全レポートの超高速集計。
   - **機能**: 生成された 108 本以上の HTML レポートをスキャンし、利益と PF を抽出して、ソート済みの比較表（Markdown）を生成します。

4. **`WarmupTerminal.ps1`**  
   - **役割**: テスト前の準備。
   - **機能**: MT5 を一度起動し、各銘柄のヒストリーデータをあらかじめ読み込んでテスト速度を向上させます。

## 実行結果の保存先
- **HTMLレポート**: `BacktestResults_Opt\` フォルダ内に全て保存されます。
- **総合比較表**: `MQL5\Experts\Active\BollingerHyper\full_backtest_report.md` に最新の結果が反映されます。
