//+------------------------------------------------------------------+
//|                                                Rev_Bollinger.mq5 |
//|                                  Copyright 2026, Antigravity AI |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property link      "https://github.com/google-deepmind/antigravity"
#property version   "1.03"
#property strict

#include <Trade\Trade.mqh>
#include <AppCore\NewsFilter.mqh>
#include <AppCore\RiskManager.mqh>
#include <AppCore\TradeGuard.mqh>

//--- 入力パラメータ
input int      InpBandsPeriod  = 20;          // Bolinger Bands 期間
input double   InpBandsDev     = 2.0;         // 標準偏差
input int      InpRSIPeriod    = 14;          // RSI 期間
input double   InpRSILower     = 35.0;        // RSI 下限
input double   InpRSIUpper     = 65.0;        // RSI 上限
input int      InpEMAPeriod    = 200;         // トレンドフィルター (EMA 200)
input int      InpATRPeriod    = 14;          // ATR 期間
input int      InpADXPeriod    = 14;          // ADX 期間
input int      InpADXThreshold = 25;          // ADX しきい値
input double   InpSLMultiplier = 1.2;         // ストップロス倍率
input double   InpTPMultiplier = 1.0;         // 利確倍率
input int      InpStartHour    = 8;           // 開始時間 (GMT)
input int      InpEndHour      = 22;          // 終了時間 (GMT)
input bool     InpUseMM        = true;        // 資金管理を使用
input double   InpRiskPercent  = 2.0;         // 1トレードあたりの許容リスク (%)
input double   InpMinLot       = 0.01;        // 最小ロット
input bool     InpUseMidClose  = true;        // 中央線で利確する
input int      InpMaxSpread    = 30;          // 許容最大スプレッド
input long     InpMagicNumber  = 400000;      // マジックナンバー
input bool     InpAutoPreset   = true;        // オートプリセットを使用
input bool     InpUseNews      = true;        // ニュースフィルタ

//--- ライブラリ
CTrade          trade;
CNewsFilter     newsFilter;
CRiskManager    riskManager;
CTradeGuard     tradeGuard;

//--- 内部計算用
double   extBandsDev;
int      extADXThreshold;
double   extRSILower;
double   extRSIUpper;

int handleBands, handleRSI, handleEMA, handleATR, handleADX;
datetime lastTradeBar = 0;

//+------------------------------------------------------------------+
//| EA Initialization                                                |
//+------------------------------------------------------------------+
int OnInit()
{
   // デフォルト値
   extBandsDev     = InpBandsDev;
   extADXThreshold = InpADXThreshold;
   extRSILower     = InpRSILower;
   extRSIUpper     = InpRSIUpper;

   // 銘柄別プリセット
   if(InpAutoPreset)
   {
      string symbol = _Symbol;
      StringToUpper(symbol);
      if(StringFind(symbol, "EURUSD") >= 0) { extBandsDev = 1.5; extADXThreshold = 25; }
      else if(StringFind(symbol, "AUDUSD") >= 0) { extBandsDev = 1.5; extADXThreshold = 25; }
      else if(StringFind(symbol, "USDCAD") >= 0) { extBandsDev = 1.5; extADXThreshold = 30; }
      else if(StringFind(symbol, "GBPUSD") >= 0) { extBandsDev = 1.8; extADXThreshold = 30; }
   }

   // ライブラリ初期化
   if(!newsFilter.Init(_Symbol, InpMagicNumber, InpUseNews, 30, 30, 3)) return INIT_FAILED;
   riskManager.Init(_Symbol, InpUseMM, InpRiskPercent, InpMinLot);
   tradeGuard.Init(_Symbol, InpMaxSpread, InpStartHour, InpEndHour);

   // 指標ハンドル
   handleBands = iBands(_Symbol, _Period, InpBandsPeriod, 0, extBandsDev, PRICE_CLOSE);
   handleRSI   = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   handleEMA   = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   handleATR   = iATR(_Symbol, _Period, InpATRPeriod);
   handleADX   = iADX(_Symbol, _Period, InpADXPeriod);

   if(handleBands == INVALID_HANDLE || handleRSI == INVALID_HANDLE) return INIT_FAILED;

   trade.SetExpertMagicNumber(InpMagicNumber);
   DisplayInfo();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| EA Tick processing                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(newsFilter.IsRestricted()) return;
   if(!tradeGuard.IsAllowed()) return;

   datetime currentBar = iTime(_Symbol, _Period, 0);
   if(lastTradeBar == currentBar) return;

   double base[], upper[], lower[], rsi[], ema[], atr[], adx[];
   ArraySetAsSeries(base, true);
   ArraySetAsSeries(upper, true);
   ArraySetAsSeries(lower, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(ema, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(adx, true);
   
   if(CopyBuffer(handleBands, 0, 0, 2, base) <= 0) return;
   if(CopyBuffer(handleBands, 1, 1, 2, upper) <= 0) return;
   if(CopyBuffer(handleBands, 2, 1, 2, lower) <= 0) return;
   if(CopyBuffer(handleRSI, 0, 1, 2, rsi) <= 0) return;
   if(CopyBuffer(handleEMA, 0, 1, 2, ema) <= 0) return;
   if(CopyBuffer(handleATR, 0, 1, 2, atr) <= 0) return;
   if(CopyBuffer(handleADX, 0, 1, 2, adx) <= 0) return;

   double close1 = iClose(_Symbol, _Period, 1);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // ポジションチェック
   bool hasPosition = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            hasPosition = true;
            if(InpUseMidClose)
            {
               ENUM_POSITION_TYPE pType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
               if((pType == POSITION_TYPE_BUY && bid >= base[0]) || (pType == POSITION_TYPE_SELL && ask <= base[0]))
               {
                  trade.PositionClose(ticket);
                  return;
               }
            }
         }
      }
   }
   if(hasPosition) return;

   // エントリー
   if(close1 < lower[0] && rsi[0] < extRSILower && close1 > ema[0] && adx[0] < extADXThreshold)
   {
      double sl = ask - (atr[0] * InpSLMultiplier);
      double tp = ask + (atr[0] * InpTPMultiplier);
      double lots = riskManager.CalculateLot(atr[0] * InpSLMultiplier);
      if(trade.Buy(lots, _Symbol, ask, sl, tp, "Rev Bollinger Buy")) lastTradeBar = currentBar;
   }
   else if(close1 > upper[0] && rsi[0] > extRSIUpper && close1 < ema[0] && adx[0] < extADXThreshold)
   {
      double sl = bid + (atr[0] * InpSLMultiplier);
      double tp = bid - (atr[0] * InpTPMultiplier);
      double lots = riskManager.CalculateLot(atr[0] * InpSLMultiplier);
      if(trade.Sell(lots, _Symbol, bid, sl, tp, "Rev Bollinger Sell")) lastTradeBar = currentBar;
   }
   
   DisplayInfo();
}

//+------------------------------------------------------------------+
//| チャート上に情報を表示する                                         |
//+------------------------------------------------------------------+
void DisplayInfo()
{
   string text = "=== Rev_Bollinger v1.03 ===\n";
   text += "Symbol: " + _Symbol + " (" + EnumToString(_Period) + ")\n";
   text += "---------------------------\n";
   text += newsFilter.GetStatusString() + "\n";
   text += riskManager.GetStatusString() + "\n";
   text += tradeGuard.GetStatusString() + "\n";
   text += "---------------------------\n";
   text += "Strategy Params (Symbol Optimized):\n";
   text += StringFormat(" - StdDev: %.2f (Preset: %s)\n", extBandsDev, InpAutoPreset ? "ON" : "OFF");
   text += StringFormat(" - ADX Limit: %d\n", extADXThreshold);
   text += StringFormat(" - RSI: %.1f / %.1f\n", extRSILower, extRSIUpper);
   text += "---------------------------\n";
   
   Comment(text);
}
