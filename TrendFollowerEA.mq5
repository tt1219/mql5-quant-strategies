//+------------------------------------------------------------------+
//|                                             TrendFollowerEA.mq5 |
//|                                      Copyright 2026, Your Name   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Your Name"
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>

//--- 入力パラメータ (v2.0: 収益最大化・複利運用モデル)
input int      InpBandsPeriod  = 20;          // Bolinger Bands 期間
input double   InpBandsDev     = 2.0;         // Bolinger Bands 偏差 (σ)
input int      InpRSIPeriod    = 14;          // RSI 期間
input double   InpRSILower     = 30.0;        // RSI 売られすぎ
input double   InpRSIUpper     = 70.0;        // RSI 買われすぎ
input int      InpATRPeriod    = 14;          // ATR 期間
input double   InpSLMultiplier = 2.0;         // 損切りのATR倍率
input double   InpTPMultiplier = 1.0;         // 利確のATR倍率
input int      InpStartHour    = 0;           // 取引開始 (MT5)
input int      InpEndHour      = 9;           // 取引終了 (MT5)

//--- v2.0 新機能パラメータ
input bool     InpUseMM        = true;        // 複利運用を使用するか
input double   InpRiskPercent  = 2.0;         // 1トレードあたりのリスク (%)
input double   InpMinLot       = 0.01;        // 最小ロット
input bool     InpUseTrail     = true;        // トレーリングストップを使用するか
input double   InpTrailStep    = 0.5;         // トレーリングのステップ (ATR倍率)

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
   Print("BollingerReverse EA v2.0 (Profit Maximization) 起動");
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
   
   //--- 決済・トレーリングロジック (v2.0)
   if(hasPosition)
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double currentSL = PositionGetDouble(POSITION_SL);
      ENUM_POSITION_TYPE pType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // トレーリングストップ (利益が出ている場合にSLを引き上げる)
      if(InpUseTrail)
        {
         double step = atr[0] * InpTrailStep;
         if(pType == POSITION_TYPE_BUY)
           {
            double newSL = bid - (atr[0] * InpSLMultiplier);
            if(bid > base[0] && newSL > currentSL + step)
               trade.PositionModify(PositionGetInteger(POSITION_TICKET), NormalizeDouble(newSL, _Digits), PositionGetDouble(POSITION_TP));
           }
         else if(pType == POSITION_TYPE_SELL)
           {
            double newSL = ask + (atr[0] * InpSLMultiplier);
            if(ask < base[0] && (currentSL == 0 || newSL < currentSL - step))
               trade.PositionModify(PositionGetInteger(POSITION_TICKET), NormalizeDouble(newSL, _Digits), PositionGetDouble(POSITION_TP));
           }
        }

      // 基本決済 (センターライン)
      if(pType == POSITION_TYPE_BUY && bid >= base[0] && !InpUseTrail)
         trade.PositionClose(_Symbol);
      else if(pType == POSITION_TYPE_SELL && ask <= base[0] && !InpUseTrail)
         trade.PositionClose(_Symbol);
     }

   //--- エントリーロジック
   if(!hasPosition)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      bool isTimeOK = (dt.hour >= InpStartHour && dt.hour <= InpEndHour);

      double currentWidth = upper[1] - lower[1];
      double prevWidth = upper[2] - lower[2];
      bool isExpanding = (currentWidth > prevWidth * 1.2);

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      // ロット計算 (複利)
      double lot = CalculateLot(atr[1] * InpSLMultiplier);

      if(isTimeOK && !isExpanding && iLow(_Symbol, _Period, 1) <= lower[1] && close[1] > lower[1] && rsi[1] <= InpRSILower)
        {
         double sl = ask - (atr[1] * InpSLMultiplier);
         double tp = ask + (atr[1] * InpTPMultiplier * 2.0); // TPは深めに設定 (Trailで追うため)
         trade.Buy(lot, _Symbol, ask, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "BB Rev v2.0 Buy");
        }
      else if(isTimeOK && !isExpanding && iHigh(_Symbol, _Period, 1) >= upper[1] && close[1] < upper[1] && rsi[1] >= InpRSIUpper)
        {
         double sl = bid + (atr[1] * InpSLMultiplier);
         double tp = bid - (atr[1] * InpTPMultiplier * 2.0);
         trade.Sell(lot, _Symbol, bid, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "BB Rev v2.0 Sell");
        }
     }

   Comment("--- BollingerReverse v2.0 (収益最大化) ---\n",
           "リスク設定: ", InpRiskPercent, "%\n",
           "トレーリング: ", (InpUseTrail ? "ON" : "OFF"), "\n",
           "フィルター: ", ((upper[1]-lower[1] > (upper[2]-lower[2])*1.2) ? "待機" : "正常"));
  }

//--- 複利ロット計算関数
double CalculateLot(double slDistance)
  {
   if(!InpUseMM) return 0.1;
   
   double freeMargin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
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
