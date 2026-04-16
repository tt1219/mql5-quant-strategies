//+------------------------------------------------------------------+
//|                                                   FullDeploy.mq5 |
//|                                  Copyright 2026, Antigravity AI |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property version   "1.05"
#property strict
#property script_show_inputs

//--- 戦略列挙型
enum ENUM_STRATEGY
{
   STRAT_REVERSE_BOLLINGER, // 守り: 逆張りボリンジャー (Rev_Bollinger)
   STRAT_FOLLOW_TREND       // 攻め: 順張りトレンドスキャル (Fol_TrendScalper)
};

input ENUM_STRATEGY InpStrategy = STRAT_REVERSE_BOLLINGER; // 展開する戦略を選択してください

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   string stratName = (InpStrategy == STRAT_REVERSE_BOLLINGER) ? "逆張りボリンジャー" : "順張りトレンドスキャル";
   PrintFormat("HyperTrading アイアン・デプロイ v1.05 を開始します: [%s]", stratName);

   // 1. 現在開いているすべてのチャートを閉じる
   long firstChart = ChartFirst();
   while(firstChart != -1)
   {
      long nextChart = ChartNext(firstChart);
      // 今自分が動いているチャート以外を閉じる
      if(firstChart != ChartID()) ChartClose(firstChart);
      firstChart = nextChart;
   }

   // 2. ターゲット銘柄の展開
   // --- GOLD SPECIAL ---
   // ゴールドには【10年検証完走済】のトレンドスキャルのみを配備します
   DeployChart("GOLD#", PERIOD_M15, "HyperTrend.tpl");

   // --- 他の主要通貨ペアはグローバル設定に従う ---
   DeployChart("EURUSD#", (InpStrategy == STRAT_FOLLOW_TREND) ? PERIOD_M15 : PERIOD_M15);
   DeployChart("AUDUSD#", (InpStrategy == STRAT_FOLLOW_TREND) ? PERIOD_M15 : PERIOD_H1);
   DeployChart("GBPUSD",  (InpStrategy == STRAT_FOLLOW_TREND) ? PERIOD_M15 : PERIOD_H1);
   DeployChart("USDCAD#", (InpStrategy == STRAT_FOLLOW_TREND) ? PERIOD_M15 : PERIOD_H1);

   PrintFormat("[%s] のデプロイが完了しました。ゴールドは検証済みのトレンドスキャルに固定されています。", stratName);
}

//+------------------------------------------------------------------+
//| 指定された銘柄と時間足でEAを適用                                   |
//+------------------------------------------------------------------+
void DeployChart(string symbol, ENUM_TIMEFRAMES period, string templateOverride="")
{
   string tplName = templateOverride;
   if(tplName == "")
   {
      tplName = (InpStrategy == STRAT_REVERSE_BOLLINGER) ? "HyperTrading.tpl" : "HyperTrend.tpl";
   }
   
   PrintFormat("展開: %s (%s) using [%s]", symbol, EnumToString(period), tplName);
   long chartID = ChartOpen(symbol, period);
   if(chartID > 0)
   {
      Sleep(1000); // チャート安定待ち (重要)
      
      if(ChartApplyTemplate(chartID, tplName))
      {
         PrintFormat("SUCCESS: %s にテンプレート [%s] を適用しました。", symbol, tplName);
      }
      else
      {
         PrintFormat("ERROR: %s へのテンプレート適用に失敗しました。", symbol);
      }
   }
   else 
   {
      PrintFormat("ERROR: %s を開けませんでした。銘柄名が存在するか確認してください。", symbol);
   }
}
