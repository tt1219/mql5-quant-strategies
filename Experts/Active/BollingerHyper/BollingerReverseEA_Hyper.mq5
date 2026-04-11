#property copyright "Copyright 2026, Antigravity AI"
#property link      "https://github.com/google-deepmind/antigravity"
#property version   "1.03"
#property strict

#include <Trade\Trade.mqh>

//--- 入力パラメータ (v4.0: ハイパー・アグレッシブ - M15/M5 推奨)
input int      InpBandsPeriod  = 20;          // Bolinger Bands 期間
input double   InpBandsDev     = 2.0;         // 標準偏差 (2.0σ 推奨)
input int      InpRSIPeriod    = 14;          // RSI 期間
input double   InpRSILower     = 35.0;        // RSI 下限 (緩和: 35)
input double   InpRSIUpper     = 65.0;        // RSI 上限 (緩和: 65)
input int      InpEMAPeriod    = 200;         // トレンドフィルター (EMA 200)
input int      InpATRPeriod    = 14;          // ATR 期間
input int      InpADXPeriod    = 14;          // ADX 期間 (v4.3)
input int      InpADXThreshold = 25;          // ADX しきい値 (これ以下で逆張り - v4.3)
input double   InpSLMultiplier = 1.2;         // ストップロス倍率 (ATR x 1.2 - 損小化)
input double   InpTPMultiplier = 1.0;         // 利確倍率 (ATR x N)
input int      InpStartHour    = 8;           // 開始時間 (GMT - 欧州開始)
input int      InpEndHour      = 20;          // 終了時間 (GMT - NY中盤)
input bool     InpUseMM        = true;        // 資金管理を使用
input double   InpRiskPercent  = 10.0;        // 1トレードあたりの許容リスク (%) -> 1000倍レバなら強気設定
input double   InpMinLot       = 0.01;        // 最小ロット
input bool     InpUseMidClose  = true;        // 中央線で利確する
input int      InpMaxSpread    = 30;          // 許容最大スプレッド (points)
input long     InpMagicNumber  = 400000;      // マジックナンバー (v4.3)
input bool     InpAutoPreset   = true;        // 銘柄別オートプリセットを使用 (FullDeploy推奨)
//--- ニュースフィルタ設定
input bool     InpUseNewsFilter   = true;     // ニュースフィルタを使用
input int      InpNewsMinsBefore  = 30;       // 指標の何分前に停止・決済するか
input int      InpNewsMinsAfter   = 30;       // 指標の何分後に再開するか
input int      InpNewsCacheDays   = 3;        // 何日分のニュースを読み込むか

//--- 内部計算用変数 (銘柄別上書きを可能にするため)
double   extBandsDev;
int      extADXThreshold;
double   extRSILower;
double   extRSIUpper;

//--- グローバル変数
CTrade      trade;
int         handleBands;
int         handleRSI;
int         handleEMA;
int         handleATR;
int         handleADX;
datetime    lastTradeBar = 0;
//--- ニュースフィルタ用グローバル変数
datetime    newsTimes[];        // 重要指標の予定時間（キャッシュ）
datetime    lastNewsUpdate = 0; // 最後にキャッシュを更新した時間 
string      baseCur = "";       // 通貨ペアのベース通貨 (例: EUR)
string      quoteCur = "";      // 通貨ペアの決済通貨 (例: USD)

//+------------------------------------------------------------------+
//| EA Initialization                                                |
//+------------------------------------------------------------------+
int OnInit()
{
   // --- デフォルト値のロード
   extBandsDev     = InpBandsDev;
   extADXThreshold = InpADXThreshold;
   extRSILower     = InpRSILower;
   extRSIUpper     = InpRSIUpper;

   string presetStatus = "Manual (Inputs)";

   // --- FullDeploy: オートプリセット・ロジック ---
   if(InpAutoPreset)
   {
      string symbol = _Symbol;
      StringToUpper(symbol);
      
      if(StringFind(symbol, "EURUSD") >= 0)
      {
         extBandsDev = 1.5; extADXThreshold = 25; presetStatus = "EURUSD Opt (M15)";
         if(_Period != PERIOD_M15) Print("Warning: EURUSD is best optimized for M15.");
      }
      else if(StringFind(symbol, "AUDUSD") >= 0)
      {
         extBandsDev = 1.5; extADXThreshold = 25; presetStatus = "AUDUSD Opt (H1)";
         if(_Period != PERIOD_H1) Print("Warning: AUDUSD is best optimized for H1.");
      }
      else if(StringFind(symbol, "USDCAD") >= 0)
      {
         extBandsDev = 1.5; extADXThreshold = 30; presetStatus = "USDCAD Opt (H1)";
         if(_Period != PERIOD_H1) Print("Warning: USDCAD is best optimized for H1.");
      }
      else if(StringFind(symbol, "GBPUSD") >= 0)
      {
         extBandsDev = 1.8; extADXThreshold = 30; presetStatus = "GBPUSD Opt (H1)";
         if(_Period != PERIOD_H1) Print("Warning: GBPUSD is best optimized for H1.");
      }
   }

   PrintFormat("%s: Setup Loaded (%s - Dev: %.1f, ADX: %d)", _Symbol, presetStatus, extBandsDev, extADXThreshold);

   // --- チャート上に設定を表示 (確認用)
   string comment = StringFormat(
      "=== BollingerReverseEA_Hyper v1.02 ===\n"+
      "Symbol: %s\n"+
      "Status: %s\n"+
      "BandsDev: %.1f\n"+
      "RSI Upper/Lower: %.1f / %.1f\n"+
      "ADX Threshold: %d\n"+
      "Risk: %.1f%%",
      _Symbol, presetStatus, extBandsDev, extRSIUpper, extRSILower, extADXThreshold, InpRiskPercent
   );
   Comment(comment);

   handleBands = iBands(_Symbol, _Period, InpBandsPeriod, 0, extBandsDev, PRICE_CLOSE);
   handleRSI   = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   handleEMA   = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   handleATR   = iATR(_Symbol, _Period, InpATRPeriod);
   handleADX   = iADX(_Symbol, _Period, InpADXPeriod);

   if(handleBands == INVALID_HANDLE || handleRSI == INVALID_HANDLE || 
      handleEMA == INVALID_HANDLE || handleATR == INVALID_HANDLE ||
      handleADX == INVALID_HANDLE)
   {
      Print("指標ハンドル取得失敗");
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(InpMagicNumber);

   // --- 通貨ペア情報の取得
   if(!GetSymbolCurrencies(_Symbol, baseCur, quoteCur))
   {
      Print("通貨情報の取得に失敗しました。ニュースフィルタが無効になる可能性があります。");
   }

   // --- 初回のニュースキャッシュ更新
   if(InpUseNewsFilter) UpdateNewsCache();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| EA Deinitialization                                              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(handleBands);
   IndicatorRelease(handleRSI);
   IndicatorRelease(handleEMA);
   IndicatorRelease(handleATR);
   IndicatorRelease(handleADX);
}

//+------------------------------------------------------------------+
//| EA Tick processing                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // --- ニュースフィルタチェック
   if(InpUseNewsFilter)
   {
      if(CheckNewsFilter()) return; // ニュース前後の場合は処理を中断
   }

   // 1バー1トレード制限
   datetime currentBar = iTime(_Symbol, _Period, 0);
   if(lastTradeBar == currentBar) return;

   // 時間フィルタ
   MqlDateTime dt;
   TimeCurrent(dt);
   if(dt.hour < InpStartHour || dt.hour > InpEndHour) return;

   double base[], upper[], lower[], rsi[], ema[], atr[], adx[];
   ArraySetAsSeries(base, true);
   ArraySetAsSeries(upper, true);
   ArraySetAsSeries(lower, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(ema, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(adx, true);
   
   if(CopyBuffer(handleBands, 0, 1, 2, base) <= 0) return;
   if(CopyBuffer(handleBands, 1, 1, 2, upper) <= 0) return;
   if(CopyBuffer(handleBands, 2, 1, 2, lower) <= 0) return;
   if(CopyBuffer(handleRSI, 0, 1, 2, rsi) <= 0) return;
   if(CopyBuffer(handleEMA, 0, 1, 2, ema) <= 0) return;
   if(CopyBuffer(handleATR, 0, 1, 2, atr) <= 0) return;
   if(CopyBuffer(handleADX, 0, 1, 2, adx) <= 0) return;

   double close1 = iClose(_Symbol, _Period, 1);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // 既存ポジション確認（マジックナンバーで識別）
   bool hasPosition = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            hasPosition = true;
            
            // --- v4.1: 中央線決済ロジック ---
            if(InpUseMidClose)
            {
               ENUM_POSITION_TYPE pType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
               if(pType == POSITION_TYPE_BUY && bid >= base[0])
               {
                  trade.PositionClose(ticket);
                  PrintFormat("Hyper MidClose Buy: %s", _Symbol);
                  return;
               }
               else if(pType == POSITION_TYPE_SELL && ask <= base[0])
               {
                  trade.PositionClose(ticket);
                  PrintFormat("Hyper MidClose Sell: %s", _Symbol);
                  return;
               }
            }
            break;
         }
      }
   }
   if(hasPosition) return;

   // スプレッドチェック
   if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpread) return;

   // 買い条件: 下限バンドを下抜けた or タッチ 且つ RSIが売られすぎ 且つ 順張りトレンド(価格 > EMA) 且つ ADXが低い(急なトレンドでない)
   if(close1 < lower[0] && rsi[0] < extRSILower && close1 > ema[0] && adx[0] < extADXThreshold)
   {
      double sl = ask - (atr[0] * InpSLMultiplier);
      double tp = ask + (atr[0] * InpTPMultiplier);
      double lots = CalculateLot(atr[0] * InpSLMultiplier);
      
      if(trade.Buy(lots, _Symbol, ask, sl, tp, "Hyper v4.0 Buy"))
      {
         lastTradeBar = currentBar;
         PrintFormat("Hyper Buy: %s, Lot: %.2f", _Symbol, lots);
      }
   }
   // 売り条件: 上限バンドを上抜けた or タッチ 且つ RSIが買われすぎ 且つ 順張りトレンド(価格 < EMA) 且つ ADXが低い(急なトレンドでない)
   else if(close1 > upper[0] && rsi[0] > extRSIUpper && close1 < ema[0] && adx[0] < extADXThreshold)
   {
      double sl = bid + (atr[0] * InpSLMultiplier);
      double tp = bid - (atr[0] * InpTPMultiplier);
      double lots = CalculateLot(atr[0] * InpSLMultiplier);
      
      if(trade.Sell(lots, _Symbol, bid, sl, tp, "Hyper v4.0 Sell"))
      {
         lastTradeBar = currentBar;
         PrintFormat("Hyper Sell: %s, Lot: %.2f", _Symbol, lots);
      }
   }
}

//+------------------------------------------------------------------+
//| 資金管理に基づいたロット計算                                       |
//+------------------------------------------------------------------+
double CalculateLot(double slDistance)
{
   if(!InpUseMM) return InpMinLot;
   if(slDistance <= 0) return InpMinLot;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (InpRiskPercent / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickValue <= 0 || tickSize <= 0) return InpMinLot;
   
   double lots = riskAmount / (slDistance / tickSize * tickValue);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lots = MathFloor(lots / stepLot) * stepLot;

   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;

   return lots;
}

//+------------------------------------------------------------------+
//| 通貨ペアから通貨コードを取得する                                     |
//+------------------------------------------------------------------+
bool GetSymbolCurrencies(string symbol, string &base, string &quote)
{
   base = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
   quote = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
   return (base != "" && quote != "");
}

//+------------------------------------------------------------------+
//| 経済カレンダーから重要指標のキャッシュを更新する                       |
//+------------------------------------------------------------------+
void UpdateNewsCache()
{
   ArrayFree(newsTimes);
   datetime from = TimeTradeServer();
   datetime to = from + InpNewsCacheDays * 86400;

   MqlCalendarValue values[];
   if(CalendarValueHistory(values, from, to) > 0)
   {
      for(int i = 0; i < ArraySize(values); i++)
      {
         MqlCalendarEvent event;
         if(CalendarEventById(values[i].event_id, event))
         {
            MqlCalendarCountry country;
            if(CalendarCountryById(event.country_id, country))
            {
               // 重要度が「高」で、かつ現在の通貨に関連するもの
               if(event.importance == CALENDAR_IMPORTANCE_HIGH && 
                  (country.currency == baseCur || country.currency == quoteCur))
               {
                  int size = ArraySize(newsTimes);
                  ArrayResize(newsTimes, size + 1);
                  newsTimes[size] = values[i].time;
               }
            }
         }
      }
   }
   ArraySort(newsTimes);
   lastNewsUpdate = TimeTradeServer();
   PrintFormat("News Cache Updated: %d high-impact events found.", ArraySize(newsTimes));
}

//+------------------------------------------------------------------+
//| ニュースの影響範囲にいるかチェックし、必要なら決済・停止する             |
//+------------------------------------------------------------------+
bool CheckNewsFilter()
{
   datetime now = TimeTradeServer();

   // 日付が変わったタイミング、またはキャッシュが空の場合のみ更新
   MqlDateTime dt_now, dt_last;
   TimeToStruct(now, dt_now);
   TimeToStruct(lastNewsUpdate, dt_last);

   if(dt_now.day != dt_last.day || (ArraySize(newsTimes) == 0 && now - lastNewsUpdate > 3600)) 
   {
      UpdateNewsCache();
   }

   bool restricted = false;
   int beforeSec = InpNewsMinsBefore * 60;
   int afterSec = InpNewsMinsAfter * 60;

   for(int i = 0; i < ArraySize(newsTimes); i++)
   {
      // 指標の前後範囲内かチェック
      if(now >= newsTimes[i] - beforeSec && now <= newsTimes[i] + afterSec)
      {
         restricted = true;
         // 指標の直前（B案：決済）
         if(now >= newsTimes[i] - beforeSec && now < newsTimes[i])
         {
            if(PositionsTotal() > 0)
            {
               Print("High-impact news is coming. Closing all positions.");
               CloseAllPositions();
            }
         }
         break;
      }
      // すでに過ぎた古い指標を配列から削除して最適化（任意）
      if(now > newsTimes[i] + afterSec + 3600)
      {
         // 簡易化のためここでは削除せず、UpdateNewsCacheで一掃されるのを待つ
      }
   }

   return restricted;
}

//+------------------------------------------------------------------+
//| このEAが持つポジションをすべて決済する                               |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            trade.PositionClose(ticket);
         }
      }
   }
}
