//+------------------------------------------------------------------+
//|                                                   FullDeploy.mq5 |
//|                                  Copyright 2026, Antigravity AI |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property version   "1.12"
#property strict
#property script_show_inputs

//--- 運用確認用
input bool InpDeployStart = true; // [確認] プロダクション構成（EURUSD + GOLD）を展開しますか？

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Alert("HyperTrading: デプロイ v1.12 (安定版ベース) を開始します...");
   Print("HyperTrading プロダクション・デプロイ v1.12 (安定版ベース)");

   // 1. 現在開いているすべてのチャートを閉じる
   long firstChart = ChartFirst();
   while(firstChart != -1)
   {
      long nextChart = ChartNext(firstChart);
      if(firstChart != ChartID()) ChartClose(firstChart);
      firstChart = nextChart;
   }
   
   Sleep(1000); // チャート安定待ち

   // 2. ターゲット銘柄の展開 (順序を以前の安定版に合わせる)
   PrintFormat("=== プロダクション・ポートフォリオを配備します ===");

   // --- EURUSD SPECIAL (Reverse Bollinger) ---
   DeployChart("EURUSD#", PERIOD_M15, "HyperTrading.tpl");

   // --- GOLD SPECIAL (Trend Scalper) ---
   DeployChart("GOLD#", PERIOD_M15, "HyperTrend.tpl");

   PrintFormat("デプロイが完了しました。各チャートの設定を確認してください。");
   Alert("デプロイ完了: GOLD (Trend) + EURUSD (Reverse)");
}

//+------------------------------------------------------------------+
//| 指定された銘柄と時間足でEAを適用                                   |
//+------------------------------------------------------------------+
void DeployChart(string symbol, ENUM_TIMEFRAMES period, string tplName)
{
   PrintFormat("デプロイ試行: %s (%s) using [%s]", symbol, EnumToString(period), tplName);

   // 銘柄をアクティブにする
   SymbolSelect(symbol, true);

   // チャートを開く
   ResetLastError();
   long chartID = ChartOpen(symbol, period);
   
   if(chartID > 0)
   {
      Sleep(1000); // 描画安定待ち
      if(ChartApplyTemplate(chartID, tplName))
      {
         PrintFormat("SUCCESS: %s にテンプレート [%s] を適用しました。", symbol, tplName);
      }
      else
      {
         PrintFormat("ERROR: %s テンプレート適用失敗 (Err: %d)", symbol, GetLastError());
      }
   }
   else 
   {
      // 予備のリトライ：末尾の記号違いのみ対応
      string alt = (StringSubstr(symbol, StringLen(symbol)-1) == "#") ? 
                   StringSubstr(symbol, 0, StringLen(symbol)-1) : 
                   symbol + "#";
      
      if(SymbolSelect(alt, true))
      {
         chartID = ChartOpen(alt, period);
         if(chartID > 0)
         {
            Sleep(1000);
            if(ChartApplyTemplate(chartID, tplName))
            {
               PrintFormat("SUCCESS (RETRY): %s に [%s] を適用しました。", alt, tplName);
               return;
            }
         }
      }
      PrintFormat("ERROR: %s を開けませんでした (Err: %d)。銘柄名を確認してください。", symbol, GetLastError());
   }
}
