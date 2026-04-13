# Rev_Bollinger 最適化・最終調査報告書 (2026.04.13)

Rev_Bollinger 戦略の収益性と安定性を向上させるため、合計 50 パターンを超えるバックテストを実施しました。その結果、目標である **PF 1.7** を大幅に上回る最終設定を特定しました。

## 1. 最終結論 (黄金バランス設定)

EURUSD (M15) におにおいて、以下の設定が「収益額」と「取引の質（安全性）」のバランスが最も優れていることが確認されました。

| 銘柄 / 足 | 偏差 | RSI 閾値 | フィルタ | PF | 取引数 | 最終利益 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **EURUSD M15** | **2.0** | **33 / 67** | ADX 20 / ニュースON | **2.28** | **46回** | **+35,874円** |

---

## 2. 調査の全工程と分析結果

### Phase 1: 現状診断
- **初期状態**: デフォルト設定では PF 1.0 前後と不安定。
- **発見**: 強いトレンド発生時の逆張りが損失の原因であることを特定。

### Phase 2: 広域グリッドサーチ (32パターン)
- **結果**: USDJPY よりも **EURUSD (M15)** がこのロジックに最適であることを特定。

### Phase 3: 超精密スキャン (偏差の深掘り)
- **分析**: 偏差を 2.1 以上に広げると、逆に PF が低下（1.59 → 1.10）することを解明。

### Phase 4: 最終関門テスト (指標と精度の検証)
- **ニュースフィルタの効果**: ON にすることで指標時の突発的なノイズを回避。
- **RSIの重要性**: RSI を絞る（30/70）と **PF 9.1** という驚異的な精度を出せるが、取引機会が激減（11回/年）することも確認。

### Phase 5: 黄金バランスの特定 (31〜34のスキャン)
- **最終結果**: RSI 33 が「PF 1.7以上の維持」と「利益額の最大化」を両立するスイートスポットであることを特定。

---

## 3. 実行ログ・成果物
- 全バックテスト集計データ: [full_backtest_report.md](file:///c:/Users/user/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/Strategies/Rev_Bollinger/reports/full_backtest_report.md)
- 最適化オーケストレーター: [Bollinger_GoldenBalance_Scan.ps1](file:///c:/Users/user/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Shared/Automation/Bollinger_GoldenBalance_Scan.ps1)
