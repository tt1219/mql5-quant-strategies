import subprocess
import os
import re
import pandas as pd
from bs4 import BeautifulSoup

# 設定
PS_SCRIPT = r"c:\Users\user\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675\MQL5\Experts\AutoBacktest.ps1"
RESULT_DIR = r"c:\Users\user\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675\MQL5\Experts\BacktestResults_Opt"
PAIRS = ["USDJPY", "EURUSD", "GBPUSD"]
RISK_LEVELS = [2.0, 5.0]
DEV_LEVELS = [1.5, 2.0]

def run_backtest(pair, risk, dev):
    cmd = [
        "powershell.exe",
        "-ExecutionPolicy", "Bypass",
        "-File", PS_SCRIPT,
        "-Pair", pair,
        "-Risk", str(risk),
        "-Dev", str(dev)
    ]
    print(f"Running: {pair} Risk={risk} Dev={dev}...")
    subprocess.run(cmd, check=True)
    
    report_file = os.path.join(RESULT_DIR, f"OptReport_{pair}_R{risk}_D{dev}.html")
    return report_file

def parse_report(file_path):
    if not os.path.exists(file_path):
        return None
    
    try:
        with open(file_path, "r", encoding="utf-16le") as f:
            soup = BeautifulSoup(f, "html.parser")
        
        # MT5レポートから数値を抽出 (テキストマッチング)
        text = soup.get_text()
        
        net_profit = float(re.search(r"Total Net Profit\s+([-\d\.\s]+)", text).group(1).replace(" ", ""))
        profit_factor = float(re.search(r"Profit Factor\s+([\d\.\s]+)", text).group(1).replace(" ", ""))
        drawdown = float(re.search(r"Maximal Drawdown\s+[\d\.\s]+\(([\d\.]+)\%\)", text).group(1))
        
        return {
            "NetProfit": net_profit,
            "ProfitFactor": profit_factor,
            "Drawdown": drawdown
        }
    except Exception as e:
        print(f"Error parsing {file_path}: {e}")
        return None

def main():
    results = []
    
    for pair in PAIRS:
        for risk in RISK_LEVELS:
            for dev in DEV_LEVELS:
                report = run_backtest(pair, risk, dev)
                metrics = parse_report(report)
                if metrics:
                    metrics.update({"Pair": pair, "Risk": risk, "Dev": dev})
                    results.append(metrics)
                    print(f"Result: {metrics}")
                else:
                    print(f"Failed to get metrics for {pair}")

    df = pd.DataFrame(results)
    df.to_csv("optimization_results.csv", index=False)
    print("\n--- Optimization Complete ---")
    print(df)

if __name__ == "__main__":
    main()
