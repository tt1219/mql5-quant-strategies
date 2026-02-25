//+------------------------------------------------------------------+
//|                                             TrendFollowerEA.mq5 |
//|                                      Copyright 2026, Your Name   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Your Name"
#property link      "https://www.mql5.com"
#property version   "1.10"
#property strict

#include <Trade\Trade.mqh>

//--- 入力パラメータ (v1.10: 機会損失の解消とバランス再考)
input int      InpBandsPeriod  = 20;          // Bolinger Bands 期間
input double   InpBandsDev     = 2.0;         // Bolinger Bands 偏差 (σ)
input int      InpRSIPeriod    = 14;          // RSI 期間
input double   InpRSILower     = 30.0;        // RSI 売られすぎ (25->30へ緩和)
input double   InpRSIUpper     = 70.0;        // RSI 買われすぎ (75->70へ緩和)
input int      InpATRPeriod    = 14;          // ATR 期間
input double   InpSLMultiplier = 2.0;         // 損切りのATR倍率 (2.5->2.0回帰: リスク管理)
input double   InpTPMultiplier = 1.0;         // 利確のATR倍率 (1.2->1.0: 確実な利確)
input int      InpStartHour    = 0;           // 取引開始 (MT5: 0時 = 日本中盤〜後半)
input int      InpEndHour      = 9;           // 取引終了 (MT5: 9時 = ロンドン前)
input double   InpLotSize      = 0.1;         // ロット
input int      InpMagicNumber  = 123456;      // マジックナンバー

//--- グローバル変数
int      handleBands, handleRSI, handleATR;
CTrade   trade;

int OnInit()
  {
   handleBands = iBands(_Symbol, _Period, InpBandsPeriod, 0, InpBandsDev, PRICE_CLOSE);
   handleRSI = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   handleATR = iATR(_Symbol, _Period, InpATRPeriod);
   
   if(handleBands == INVALID_HANDLE || handleRSI == INVALID_HANDLE || handleATR == INVALID_HANDLE)
      return(INIT_FAILED);
   
   trade.SetExpertMagicNumber(InpMagicNumber);
   Print("BollingerReverse EA v1.10 (Balanced Mode) 起動");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   IndicatorRelease(handleBands);
   IndicatorRelease(handleRSI);
   IndicatorRelease(handleATR);
  }

void OnTick()
  {
   double base[], upper[], lower[], rsi[], atr[], close[];
   ArraySetAsSeries(base, true); ArraySetAsSeries(upper, true); ArraySetAsSeries(lower, true);
   ArraySetAsSeries(rsi, true); ArraySetAsSeries(atr, true); ArraySetAsSeries(close, true);
   
   if(CopyBuffer(handleBands, 0, 0, 4, base) < 4 ||
      CopyBuffer(handleBands, 1, 0, 4, upper) < 4 ||
      CopyBuffer(handleBands, 2, 0, 4, lower) < 4 ||
      CopyBuffer(handleRSI, 0, 0, 4, rsi) < 4 ||
      CopyBuffer(handleATR, 0, 0, 4, atr) < 4 ||
      CopyClose(_Symbol, _Period, 0, 4, close) < 4)
      return;

   bool hasPosition = PositionSelectByMagic(_Symbol, InpMagicNumber);
   
   //--- 決済ロジック
   if(hasPosition)
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      ENUM_POSITION_TYPE pType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // センターライン（base[0]）に到達したら即座に手仕舞い
      if(pType == POSITION_TYPE_BUY && bid >= base[0])
         trade.PositionClose(_Symbol);
      else if(pType == POSITION_TYPE_SELL && ask <= base[0])
         trade.PositionClose(_Symbol);
     }

   //--- エントリーロジック
   if(!hasPosition)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      bool isTimeOK = (dt.hour >= InpStartHour && dt.hour <= InpEndHour);

      // バンド拡大チェック (1.2倍ルール継続)
      double currentWidth = upper[1] - lower[1];
      double prevWidth = upper[2] - lower[2];
      bool isExpanding = (currentWidth > prevWidth * 1.2);

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      // 買い：拡大なし + 安値がバンド下 + 終値が戻った + RSI
      if(isTimeOK && !isExpanding && iLow(_Symbol, _Period, 1) <= lower[1] && close[1] > lower[1] && rsi[1] <= InpRSILower)
        {
         double sl = ask - (atr[1] * InpSLMultiplier);
         double tp = ask + (atr[1] * InpTPMultiplier);
         trade.Buy(InpLotSize, _Symbol, ask, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "BB Rev v1.10 Buy");
        }
      // 売り：拡大なし + 高値がバンド上 + 終値が戻った + RSI
      else if(isTimeOK && !isExpanding && iHigh(_Symbol, _Period, 1) >= upper[1] && close[1] < upper[1] && rsi[1] >= InpRSIUpper)
        {
         double sl = bid + (atr[1] * InpSLMultiplier);
         double tp = bid - (atr[1] * InpTPMultiplier);
         trade.Sell(InpLotSize, _Symbol, bid, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "BB Rev v1.10 Sell");
        }
     }

   Comment("--- BollingerReverse v1.10 (バランス型) ---\n",
           "フィルター: ", ((upper[1]-lower[1] > (upper[2]-lower[2])*1.2) ? "トレンド回避" : "レンジ待機"), "\n",
           "RSI[1]: ", NormalizeDouble(rsi[1], 1), " / 取引窓口: ", InpStartHour, "-", InpEndHour);
  }

bool PositionSelectByMagic(string symbol, long magic)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
         if(PositionGetString(POSITION_SYMBOL) == symbol && PositionGetInteger(POSITION_MAGIC) == magic)
            return true;
     }
   return false;
  }
