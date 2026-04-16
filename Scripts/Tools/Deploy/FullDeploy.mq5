//+------------------------------------------------------------------+
//|                                                   FullDeploy.mq5 |
//|                                  Copyright 2026, Antigravity AI |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property version   "1.13"
#property strict
#property script_show_inputs

//--- 運用確認用
input bool InpDeployStart = true; // [確認] 自動検索で最適な銘柄名を特定し、デプロイを開始しますか？

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Alert("HyperTrading: デプロイ v1.13 (自動銘柄特定エンジン) を開始します...");
   Print("HyperTrading プロダクション・デプロイ v1.13 (Intelligent Discovery)");

   // 1. シンボルの自動特定
   string goldSym = FindVerifiedSymbol("GOLD");
   string eurusdSym = FindVerifiedSymbol("EURUSD");
   
   if(goldSym == "" || eurusdSym == "")
   {
      string msg = "深刻なエラー: ターゲット銘柄を特定できませんでした。\n";
      if(goldSym == "") msg += " - GOLD 系の銘柄が見つかりません\n";
      if(eurusdSym == "") msg += " - EURUSD 系の銘柄が見つかりません\n";
      Alert(msg);
      Print(msg);
      return;
   }

   PrintFormat("INFO: 銘柄を特定しました: GOLD -> [%s], EURUSD -> [%s]", goldSym, eurusdSym);

   // 1. すべてのチャートを閉じる (安定版の挙動を完全復元)
   long chartID = ChartFirst();
   while(chartID != -1)
   {
      long nextChart = ChartNext(chartID);
      ChartClose(chartID);
      chartID = nextChart;
   }
   
   Sleep(500); 

   // 3. ターゲット銘柄の展開
   PrintFormat("=== プロダクション・ポートフォリオを配備します ===");

   // 順序：EURUSD -> GOLD (安定版の順序)
   DeployChart(eurusdSym, PERIOD_M15, "HyperTrading.tpl");
   DeployChart(goldSym, PERIOD_M15, "HyperTrend.tpl");

   PrintFormat("デプロイが完了しました。[%s] と [%s] のチャート設定を確認してください。", goldSym, eurusdSym);
   Alert("デプロイ完了: " + goldSym + " & " + eurusdSym);
}

//+------------------------------------------------------------------+
//| ターミナルから最適な銘柄名を特定する                                |
//+------------------------------------------------------------------+
string FindVerifiedSymbol(string baseName)
{
   string found = "";
   int total = SymbolsTotal(false); // 全銘柄を検索
   
   for(int i=0; i<total; i++)
   {
      string name = SymbolName(i, false);
      if(StringFind(name, baseName) >= 0)
      {
         // 優先順位：
         // 1. 文字列が含まれている
         // 2. かつ「気配値表示」に既に選ばれているものを最優先
         if(SymbolInfoInteger(name, SYMBOL_SELECT))
         {
            return name; // 即決
         }
         // まだ見つかっていない場合、最初の候補として保持
         if(found == "") found = name;
      }
   }
   return found;
}

//+------------------------------------------------------------------+
//| 指定された銘柄と時間足でEAを適用                                   |
//+------------------------------------------------------------------+
void DeployChart(string symbol, ENUM_TIMEFRAMES period, string tplName)
{
   PrintFormat("デプロイ試行: %s (%s) using [%s]", symbol, EnumToString(period), tplName);

   // 念のため再度気配値に登録
   if(!SymbolSelect(symbol, true))
   {
      PrintFormat("ERROR: %s を気配値に登録できませんでした。", symbol);
      return;
   }

   // チャートを開く
   ResetLastError();
   long chartID = ChartOpen(symbol, period);
   
   if(chartID > 0)
   {
      Sleep(1500); // 描画安定待ち
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
      PrintFormat("ERROR: %s を開けませんでした (Err: %d / Params: %s, %s)", 
                  symbol, GetLastError(), symbol, EnumToString(period));
   }
}
