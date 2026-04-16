//+------------------------------------------------------------------+
//|                                                   FullDeploy.mq5 |
//|                                  Copyright 2026, Antigravity AI |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property version   "1.10"
#property strict
#property script_show_inputs

//--- 戦略列挙型
enum ENUM_STRATEGY
{
   STRAT_REVERSE_BOLLINGER, // 守り: 逆張りボリンジャー (Rev_Bollinger)
   STRAT_FOLLOW_TREND       // 攻め: 順張りトレンドスキャル (Fol_TrendScalper)
};

// input ENUM_STRATEGY InpStrategy = STRAT_REVERSE_BOLLINGER; // Legacy Selection (Redundant in Production)

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("HyperTrading プロダクション・デプロイ v1.10 を開始します");

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
   PrintFormat("=== プロダクション・ポートフォリオを配備します ===");

   // --- GOLD SPECIAL ---
   // ゴールドには【10年検証完走済】のトレンドスキャルのみを配備します
   DeployChart("GOLD#", PERIOD_M15, "HyperTrend.tpl");

   // --- EURUSD SPECIAL ---
   // ボリンジャー逆張りは EURUSD (M15) に集約します
   DeployChart("EURUSD#", PERIOD_M15, "HyperTrading.tpl");

   PrintFormat("デプロイが完了しました。GOLD# (Trend Scalper) と EURUSD# (Reverse Bollinger) が展開されました。");
}

//+------------------------------------------------------------------+
//| 指定された銘柄と時間足でEAを適用                                   |
//+------------------------------------------------------------------+
void DeployChart(string symbol, ENUM_TIMEFRAMES period, string templateOverride="")
{
   string tplName = templateOverride;
   if(tplName == "")
   {
      // デフォルト（フォールバック用）
      tplName = "HyperTrend.tpl";
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
