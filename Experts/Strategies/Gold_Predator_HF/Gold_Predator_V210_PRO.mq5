//+------------------------------------------------------------------+
//|                                     Gold_Predator_V210_PRO.mq5  |
//|                                  Copyright 2024, Gemini CLI Agent |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini CLI Agent"
#property link      "https://www.mql5.com"
#property version   "2.2.0"
#property strict

#include <Trade\Trade.mqh>
#include <AppCore\RiskManager.mqh>
#include <AppCore\NewsFilter.mqh>

//--- v2.2.0 THE SCALPING MASTER
#define MAX_SPREAD_ALLOWED 80
#define FIXED_LOT 0.1
#define ATR_SL_MULT 1.5
#define ATR_TP_MULT 3.0    // Increased to dominate spread cost

//--- Performance Guards
#define MIN_MOMENTUM_RATIO 0.7 // Body must be > 70% of ATR
#define BE_START_POINTS 500    // 5.0 USD to allow Gold to breathe
#define BE_TARGET_POINTS 100   // Lock in 1.0 USD

#define UTC_START_HOUR 7
#define UTC_END_HOUR   20

input long InpMagic = 999100;

int handleATR, handleEMA_H1;
CTrade trade;

//+------------------------------------------------------------------+
int OnInit()
{
   handleATR    = iATR(_Symbol, PERIOD_M5, 14);
   handleEMA_H1 = iMA(_Symbol, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE);
   trade.SetExpertMagicNumber(InpMagic);
   return(INIT_SUCCEEDED);
}

void OnTick()
{
   datetime currentBarTime = iTime(_Symbol, PERIOD_M5, 0);
   static datetime lastTradeBar = 0;

   double h1EMA[], atr[], high[], low[], close[], open[];
   ArraySetAsSeries(h1EMA, true); ArraySetAsSeries(atr, true);
   ArraySetAsSeries(high, true); ArraySetAsSeries(low, true); 
   ArraySetAsSeries(close, true); ArraySetAsSeries(open, true);

   if(CopyBuffer(handleEMA_H1, 0, 0, 1, h1EMA) <= 0) return;
   if(CopyBuffer(handleATR, 0, 0, 1, atr) <= 0) return;
   if(CopyHigh(_Symbol, PERIOD_M5, 1, 1, high) <= 0) return;
   if(CopyLow(_Symbol, PERIOD_M5, 1, 1, low) <= 0) return;
   if(CopyOpen(_Symbol, PERIOD_M5, 1, 1, open) <= 0) return;
   if(CopyClose(_Symbol, PERIOD_M5, 1, 1, close) <= 0) return;

   double body = MathAbs(close[0] - open[0]);

   // 1. ENTRY LOGIC (Strict Momentum)
   if(PositionsTotal() == 0 && currentBarTime != lastTradeBar)
   {
      // Only enter if the momentum (body) is strong enough to beat spread
      if(body < atr[0] * MIN_MOMENTUM_RATIO) return;

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double slPoints = atr[0] * ATR_SL_MULT;
      double tpPoints = atr[0] * ATR_TP_MULT;

      if(close[0] > h1EMA[0] && close[0] > high[0]) {
         if(trade.Buy(FIXED_LOT, _Symbol, ask, ask - slPoints, ask + tpPoints, "v220_MASTER")) lastTradeBar = currentBarTime;
      }
      else if(close[0] < h1EMA[0] && close[0] < low[0]) {
         if(trade.Sell(FIXED_LOT, _Symbol, bid, bid + slPoints, bid - tpPoints, "v220_MASTER")) lastTradeBar = currentBarTime;
      }
   }

   // 2. MANAGEMENT (Anti-Noise BE)
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
