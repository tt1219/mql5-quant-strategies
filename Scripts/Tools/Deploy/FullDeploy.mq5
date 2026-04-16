//+------------------------------------------------------------------+
//|                                                   FullDeploy.mq5 |
//|                                  Copyright 2026, Antigravity AI |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property version   "1.11"
#property strict
#property script_show_inputs

//--- 運用確認用
input bool InpDeployStart = true; // [確認] プロダクション構成（GOLD+EURUSD）を展開しますか？

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Alert("HyperTrading: デプロイ v1.11 を開始します...");
   Print("HyperTrading プロダクション・デプロイ v1.11 を開始します");

   // 1. 現在開いているすべてのチャートを閉じる
   long firstChart = ChartFirst();
   while(firstChart != -1)
   {
      long nextChart = ChartNext(firstChart);
      if(firstChart != ChartID()) ChartClose(firstChart);
      firstChart = nextChart;
   }
   
   Sleep(500); // 切替の安定待ち

   // 2. ターゲット銘柄の展開
   PrintFormat("=== プロダクション・ポートフォリオを配備します ===");

   // --- GOLD SPECIAL ---
   DeployChart("GOLD#", PERIOD_M15, "HyperTrend.tpl");

   // --- EURUSD SPECIAL ---
   DeployChart("EURUSD#", PERIOD_M15, "HyperTrading.tpl");

   PrintFormat("デプロイが完了しました。GOLD (Trend) と EURUSD (Reverse) が展開されました。");
}

//+------------------------------------------------------------------+
//| 指定された銘柄と時間足でEAを適用 (銘柄自動補完機能付き)              |
//+------------------------------------------------------------------+
void DeployChart(string symbol, ENUM_TIMEFRAMES period, string templateOverride="")
{
   string tplName = templateOverride;
   if(tplName == "") tplName = "HyperTrend.tpl";

   PrintFormat("デプロイ試行: %s (%s) using [%s]", symbol, EnumToString(period), tplName);

   // 1. シンボルの自動マッチング
   string finalSymbol = "";
   string trials[4];
   trials[0] = symbol;                                      // オリジナル (GOLD#)
   trials[1] = StringSubstr(symbol, 0, StringLen(symbol)-1); // 末尾削除 (GOLD)
   trials[2] = symbol + ".m";                               // 接尾辞 (GOLD.m)
   trials[3] = symbol + ".pro";                             // 接尾辞 (GOLD.pro)

   for(int i=0; i<4; i++)
   {
      if(SymbolSelect(trials[i], true))
      {
         finalSymbol = trials[i];
         if(trials[i] != symbol) PrintFormat("INFO: %s を %s として認識しました", symbol, finalSymbol);
         break;
      }
   }

   if(finalSymbol == "")
   {
      PrintFormat("ERROR: 銘柄 %s が見つかりません。Market Watchを確認してください。", symbol);
      return;
   }

   // 2. チャートを開く
   ResetLastError();
   long chartID = ChartOpen(finalSymbol, period);
   if(chartID > 0)
   {
      Sleep(2000); // 描画と接続の安定待ち (少し長めに)
      
      if(ChartApplyTemplate(chartID, tplName))
      {
         PrintFormat("SUCCESS: %s にテンプレート [%s] を適用しました。", finalSymbol, tplName);
      }
      else
      {
         PrintFormat("ERROR: %s へのテンプレート適用に失敗しました (Err: %d)", finalSymbol, GetLastError());
      }
   }
   else 
   {
      PrintFormat("ERROR: %s を開けませんでした (Err: %d)。", finalSymbol, GetLastError());
   }
}
