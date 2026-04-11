//+------------------------------------------------------------------+
//|                                                   FullDeploy.mq5 |
//|                                  Copyright 2026, Antigravity AI |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property version   "1.03"
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
   PrintFormat("HyperTrading 全自動デプロイを開始します: [%s]", stratName);

   // 1. 現在開いているすべてのチャートを閉じる
   long firstChart = ChartFirst();
   while(firstChart != -1)
   {
      long nextChart = ChartNext(firstChart);
      ChartClose(firstChart);
      firstChart = nextChart;
   }

   // 2. ターゲット銘柄の展開
   // 第3引数のマジックナンバーはテンプレート内で上書きされる可能性がありますが、管理用に指定
   DeployChart("EURUSD#", (InpStrategy == STRAT_FOLLOW_TREND) ? PERIOD_M5 : PERIOD_M15);
   DeployChart("AUDUSD#", (InpStrategy == STRAT_FOLLOW_TREND) ? PERIOD_M5 : PERIOD_H1);
   DeployChart("GBPUSD",  (InpStrategy == STRAT_FOLLOW_TREND) ? PERIOD_M5 : PERIOD_H1);
   DeployChart("USDCAD#", (InpStrategy == STRAT_FOLLOW_TREND) ? PERIOD_M5 : PERIOD_H1);

   PrintFormat("[%s] のデプロイが完了しました。各チャートの設定を確認してください。", stratName);
}

//+------------------------------------------------------------------+
//| 指定された銘柄と時間足でEAを適用                                   |
//+------------------------------------------------------------------+
void DeployChart(string symbol, ENUM_TIMEFRAMES period)
{
   string tplName = (InpStrategy == STRAT_REVERSE_BOLLINGER) ? "HyperTrading.tpl" : "HyperTrend.tpl";
   
   PrintFormat("展開: %s (%s)", symbol, EnumToString(period));
   long chartID = ChartOpen(symbol, period);
   if(chartID > 0)
   {
      Sleep(500); // チャート安定待ち
      
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
