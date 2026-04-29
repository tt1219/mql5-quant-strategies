//+------------------------------------------------------------------+
//|                                     Gold_Predator_V210_PRO.mq5  |
//|                                  Copyright 2024, Gemini CLI Agent |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini CLI Agent"
#property link      "https://www.mql5.com"
#property version   "2.5.0"
#property strict

#include <Trade\Trade.mqh>
#include <AppCore\RiskManager.mqh>
#include <AppCore\NewsFilter.mqh>

//--- v2.5.0 THE TRUE PREDATOR (Clean Build Version)
#define MAX_SPREAD_ALLOWED 30
#define ATR_SL_MULT 2.0
#define ATR_TP_MULT 6.0

#define MIN_MOMENTUM_RATIO 2.0
#define BE_START_POINTS 1500
#define BE_TARGET_POINTS 300   

#define UTC_START_HOUR 8
#define UTC_END_HOUR   18

input double InpRiskPercent = 3.0;
input long   InpMagic       = 999500;

int handleATR, handleEMA_H1;
CTrade trade;
CRiskManager riskManager;
CNewsFilter newsFilter;

datetime g_lastTradeBar = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   handleATR    = iATR(_Symbol, PERIOD_M5, 14);
   handleEMA_H1 = iMA(_Symbol, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE);
   trade.SetExpertMagicNumber(InpMagic);
   riskManager.Init(_Symbol, true, InpRiskPercent, 0.01);
   newsFilter.Init(_Symbol, InpMagic, true, 60, 60, 7);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { IndicatorRelease(handleATR); IndicatorRelease(handleEMA_H1); }

//+------------------------------------------------------------------+
void OnTick()
{
   if(newsFilter.IsRestricted()) return;
   if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MAX_SPREAD_ALLOWED) return;

   datetime currentBarTime = iTime(_Symbol, PERIOD_M5, 0);

   double h1EMA[], atr[], high[], low[], open[], close_prev[];
   ArraySetAsSeries(h1EMA, true); ArraySetAsSeries(atr, true);
   ArraySetAsSeries(high, true); ArraySetAsSeries(low, true); 
   ArraySetAsSeries(open, true); ArraySetAsSeries(close_prev, true);

   if(CopyBuffer(handleEMA_H1, 0, 0, 1, h1EMA) <= 0) return;
   if(CopyBuffer(handleATR, 0, 0, 1, atr) <= 0) return;
   if(CopyHigh(_Symbol, PERIOD_M5, 1, 1, high) <= 0) return;
   if(CopyLow(_Symbol, PERIOD_M5, 1, 1, low) <= 0) return;
   if(CopyOpen(_Symbol, PERIOD_M5, 1, 1, open) <= 0) return;
   if(CopyClose(_Symbol, PERIOD_M5, 1, 1, close_prev) <= 0) return;

   double body = MathAbs(close_prev[0] - open[0]);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // 1. ENTRY
   if(PositionsTotal() == 0 && currentBarTime != g_lastTradeBar)
   {
      if(body < atr[0] * MIN_MOMENTUM_RATIO) return;

      double slPoints = atr[0] * ATR_SL_MULT;
      double tpPoints = atr[0] * ATR_TP_MULT;
      double lot = riskManager.CalculateLot(slPoints / _Point);

      if(ask > high[0] && ask > h1EMA[0]) {
         if(trade.Buy(lot, _Symbol, ask, ask - slPoints, ask + tpPoints, "v250_B"))
            g_lastTradeBar = currentBarTime;
      }
      else if(bid < low[0] && bid < h1EMA[0]) {
         if(trade.Sell(lot, _Symbol, bid, bid + slPoints, bid - tpPoints, "v250_S"))
            g_lastTradeBar = currentBarTime;
      }
   }

   // 2. MANAGEMENT
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)) && PositionGetInteger(POSITION_MAGIC) == InpMagic)
      {
         double p_open = PositionGetDouble(POSITION_PRICE_OPEN);
         double p_cur = PositionGetDouble(POSITION_PRICE_CURRENT);
         double p_sl = PositionGetDouble(POSITION_SL);
         
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            if(p_sl < p_open && p_cur > p_open + BE_START_POINTS * _Point)
               trade.PositionModify(PositionGetTicket(i), p_open + BE_TARGET_POINTS * _Point, PositionGetDouble(POSITION_TP));
         } else {
            if((p_sl > p_open || p_sl == 0) && p_cur < p_open - BE_START_POINTS * _Point)
               trade.PositionModify(PositionGetTicket(i), p_open - BE_TARGET_POINTS * _Point, PositionGetDouble(POSITION_TP));
         }
      }
   }
}
