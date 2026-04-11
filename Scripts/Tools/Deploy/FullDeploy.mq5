//+------------------------------------------------------------------+
//|                                                   FullDeploy.mq5 |
//|                                  Copyright 2026, Antigravity AI |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property version   "1.02"
#property strict
#property script_show_inputs

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("HyperTrading 全自動デプロイを開始します (4銘柄版)...");

   // 1. 現在開いているすべてのチャートを閉じる (大掃除)
   long firstChart = ChartFirst();
   while(firstChart != -1)
   {
      long nextChart = ChartNext(firstChart);
      ChartClose(firstChart);
      firstChart = nextChart;
   }

   // 2. 4銘柄を展開してテンプレートを適用
   DeployChart("EURUSD#", PERIOD_M15, 10101);
   DeployChart("AUDUSD#", PERIOD_H1,  10102);
   DeployChart("GBPUSD",  PERIOD_H1,  10103);
   DeployChart("USDCAD#", PERIOD_H1,  10104);

   Print("4銘柄デプロイ完了！すべてのチャートでニコニコマークを確認してください。");
}

//+------------------------------------------------------------------+
//| 指定された銘柄と時間足でEAを適用                                   |
//+------------------------------------------------------------------+
void DeployChart(string symbol, ENUM_TIMEFRAMES period, int magic)
{
   PrintFormat("%s (%s) の展開を開始します...", symbol, EnumToString(period));
   long chartID = ChartOpen(symbol, period);
   if(chartID > 0)
   {
      // チャートが準備できるまで少し待つ (安定性のため)
      Sleep(500);
      
      // 作成したテンプレートを適用してEAを自動起動させる
      if(ChartApplyTemplate(chartID, "HyperTrading.tpl"))
      {
         PrintFormat("%s にEAを自動アタッチしました。", symbol);
      }
      else
      {
         PrintFormat("%s のアタッチに失敗しました。手動でHyperTradingテンプレートを適用してください。", symbol);
      }
   }
   else 
   {
      PrintFormat("%s を開けませんでした。銘柄名を確認してください。", symbol);
   }
}
