# MQL5 Deployment & Integration Manual

This manual documents the "FullDeploy" system and the validation results of the "Fol_TrendScalper" (Gold) strategy, established after a 10-year Ironman Every-Tick validation run.

## 🏆 Validation Milestone (Stage 3 Complete)
- **Period**: 2016.01.01 - 2026.04.16 (Continuous Run)
- **Model**: Every-Tick (Real-Tick data)
- **Symbol**: GOLD# (M15)
- **Key Result**: Survived 2020 Covid Crash and 2022-2024 inflation spikes without a single Stop Out.
- **Validated Params**:
    - `InpADXThreshold`: 30 (Crucial for filtering non-trending noise)
    - `InpBBExpRatio`: 1.1 (Volatility expansion trigger)
    - `InpRSIPullback`: 30.0

## 🛠 The "FullDeploy" System (v1.05)

### 1. Concepts: Sword and Shield
The system supports a "Hybrid" layout. By default:
- **Major FX**: Deploys either Trend-Following or Mean Reversion (Bollinger) based on `InpStrategy`.
- **Gold (XAU/USD)**: Always deployed with the **TrendScalper (M15)** because it is the only validated high-performer for this symbol.

### 2. The "Immortal" Guard (Critical Lesson)
MQL5 scripts will terminate if they close the chart they are running on. v1.05 implements the following guard to ensure full execution:
```mql5
if(firstChart != ChartID()) ChartClose(firstChart);
```
Never remove this check, or the script will self-terminate during the cleanup phase.

### 3. How to add a new EA
To integrate a new strategy (e.g., `NewStrategy`):
1.  **Create Template**: Atop a chart with the EA attached, save a template named `NewStrategy.tpl`.
2.  **Update Enum**: Add `STRAT_NEW` to `ENUM_STRATEGY` in `FullDeploy.mq5`.
3.  **Update OnStart**: 
    - Use `DeployChart("SYMBOL", PERIOD, "NewStrategy.tpl");` to force specific deployment.
4.  **Update DeployChart**: Ensure the template selection logic maps correctly.

## 📂 File Locations
- **Source**: `Experts\Strategies\Fol_TrendScalper\Fol_TrendScalper.mq5`
- **Deployer**: `Scripts\Tools\Deploy\FullDeploy.mq5` (v1.05)
- **Templates**: `MQL5\Profiles\Templates\HyperTrend.tpl`
