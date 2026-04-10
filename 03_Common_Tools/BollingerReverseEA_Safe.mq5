//+------------------------------------------------------------------+
//|                                     BollingerReverseEA_Safe.mq5 |
//|                                      Copyright 2026, Your Name   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Your Name"
#property link      "https://www.mql5.com"
#property version   "2.22"
#property strict

#include <Trade\Trade.mqh>

//--- 入力パラメータ (Safeモデル: 高精度・低リスク運用)
input int      InpBandsPeriod  = 20;          // Bolinger Bands 期間
input double   InpBandsDev     = 2.3;         // Bolinger Bands 偏差 (2.3σ: 厳選)
input int      InpRSIPeriod    = 14;          // RSI 期間
input double   InpRSILower     = 30.0;        // RSI 売られすぎ
input double   InpRSIUpper     = 70.0;        // RSI 買われすぎ
input int      InpEMAPeriod    = 200;         // トレンドフィルター (EMA 200)
input int      InpATRPeriod    = 14;          // ATR 期間
input double   InpSLMultiplier = 2.0;         // 損切りのATR倍率
input double   InpTPMultiplier = 1.0;         // 利確のATR倍率
input int      InpStartHour    = 0;           // 取引開始
input int      InpEndHour      = 22;          // 取引終了

//--- 資金管理
input bool     InpUseMM        = true;        // 複利運用を使用するか
input double   InpRiskPercent  = 2.0;         // リスク (%) / 安定運用の2%
input double   InpMinLot       = 0.01;        // 最小ロット
input int      InpMagicNumber  = 123456;      // マジックナンバー

//--- グローバル変数
int      handleBands, handleRSI, handleATR, handleEMA;
CTrade   trade;
datetime lastTradeBar = 0; // 同一足での連続エントリー防止用

int OnInit()
  {
   handleBands = iBands(_Symbol, _Period, InpBandsPeriod, 0, InpBandsDev, PRICE_CLOSE);
   handleRSI = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   handleATR = iATR(_Symbol, _Period, InpATRPeriod);
   handleEMA = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   if(handleBands == INVALID_HANDLE || handleRSI == INVALID_HANDLE || handleATR == INVALID_HANDLE || handleEMA == INVALID_HANDLE)
      return(INIT_FAILED);
   
   trade.SetExpertMagicNumber(InpMagicNumber);
   Print("BollingerReverse EA Safe v2.22 起動");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   IndicatorRelease(handleBands);
   IndicatorRelease(handleRSI);
   IndicatorRelease(handleATR);
   IndicatorRelease(handleEMA);
  }

void OnTick()
  {
   double base[], upper[], lower[], rsi[], atr[], close[], ema[];
   ArraySetAsSeries(base, true); ArraySetAsSeries(upper, true); ArraySetAsSeries(lower, true);
   ArraySetAsSeries(rsi, true); ArraySetAsSeries(atr, true); ArraySetAsSeries(close, true); ArraySetAsSeries(ema, true);
   
   if(CopyBuffer(handleBands, 0, 0, 4, base) < 4 ||
      CopyBuffer(handleBands, 1, 0, 4, upper) < 4 ||
      CopyBuffer(handleBands, 2, 0, 4, lower) < 4 ||
      CopyBuffer(handleRSI, 0, 0, 4, rsi) < 4 ||
      CopyBuffer(handleATR, 0, 0, 4, atr) < 4 ||
      CopyBuffer(handleEMA, 0, 0, 4, ema) < 4 ||
      CopyClose(_Symbol, _Period, 0, 4, close) < 4)
      return;

   bool hasPosition = PositionSelectByMagic(_Symbol, InpMagicNumber);
   
   //--- 決済ロジック
   if(hasPosition)
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      ENUM_POSITION_TYPE pType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      if(pType == POSITION_TYPE_BUY && bid >= base[0])
         trade.PositionClose(_Symbol);
      else if(pType == POSITION_TYPE_SELL && ask <= base[0])
         trade.PositionClose(_Symbol);
     }

   //--- エントリーロジック (Safeモデル: 同一足制限 + 厳格なフィルター)
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(!hasPosition && lastTradeBar != currentBarTime)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      bool isTimeOK = (dt.hour >= InpStartHour && dt.hour <= InpEndHour);

      double currentWidth = upper[1] - lower[1];
      double prevWidth = upper[2] - lower[2];
      bool isExpanding = (currentWidth > prevWidth * 1.2);

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      double lot = CalculateLot(atr[1] * InpSLMultiplier);

      if(isTimeOK && !isExpanding && iLow(_Symbol, _Period, 1) <= lower[1] && close[1] > lower[1] && rsi[1] <= InpRSILower && close[1] > ema[1])
        {
         double sl = ask - (atr[1] * InpSLMultiplier);
         double tp = ask + (atr[1] * InpTPMultiplier * 1.5);
         if(trade.Buy(lot, _Symbol, ask, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "BB Rev Safe Buy"))
            lastTradeBar = currentBarTime;
        }
      else if(isTimeOK && !isExpanding && iHigh(_Symbol, _Period, 1) >= upper[1] && close[1] < upper[1] && rsi[1] >= InpRSIUpper && close[1] < ema[1])
        {
         double sl = bid + (atr[1] * InpSLMultiplier);
         double tp = bid - (atr[1] * InpTPMultiplier * 1.5);
         if(trade.Sell(lot, _Symbol, bid, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "BB Rev Safe Sell"))
            lastTradeBar = currentBarTime;
        }
     }

   Comment("--- BollingerReverse Safe v2.22 ---\n",
           "リスク/回: ", InpRiskPercent, "%\n",
           "フィルター: ", ((upper[1]-lower[1] > (upper[2]-lower[2])*1.2) ? "トレンド回避中" : "正常"));
  }

double CalculateLot(double slDistance)
  {
   if(!InpUseMM) return 0.1;
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(slDistance <= 0 || tickValue <= 0) return InpMinLot;
   double riskAmount = freeMargin * (InpRiskPercent / 100.0);
   double lot = riskAmount / (slDistance / tickSize * tickValue);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / stepLot) * stepLot;
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   return lot;
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
