//+------------------------------------------------------------------+
//|                                                Gold_Predator.mq5 |
//|                                  Copyright 2024, Gemini CLI Agent |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini CLI Agent"
#property link      "https://www.mql5.com"
#property version   "1.1.0"
#property strict

#include <Trade\Trade.mqh>
#include <AppCore\RiskManager.mqh>
#include <AppCore\NewsFilter.mqh>

//--- Gold_Predator Official Release v1.1.0 "Safety First"
//--- Improved: Added ATR Trailing Stop to smooth out drawdown and protect initial capital.
#define MAX_SPREAD_ALLOWED 50
#define ATR_SL_MULT 1.5
#define ATR_TP_MULT 4.5    // Slightly extended to compensate for tighter trailing

#define MIN_MOMENTUM_RATIO 1.5 
#define TS_ACTIVATION_MULT 2.0 // Start trailing after 2x ATR profit
#define TS_DISTANCE_MULT   1.5 // Trail at 1.5x ATR distance

input double InpRiskPercent = 1.5;   // Lowered to 1.5% for drawdown protection
input long   InpMagic       = 100001;

int handleATR, handleEMA_H4;
CTrade trade;
CRiskManager riskManager;
CNewsFilter newsFilter;

datetime g_lastTradeBar = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   handleATR    = iATR(_Symbol, PERIOD_H1, 14);
   handleEMA_H4 = iMA(_Symbol, PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE);
   
   trade.SetExpertMagicNumber(InpMagic);
   riskManager.Init(_Symbol, true, InpRiskPercent, 0.01);
   newsFilter.Init(_Symbol, InpMagic, true, 60, 60, 7);
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { IndicatorRelease(handleATR); IndicatorRelease(handleEMA_H4); }

//+------------------------------------------------------------------+
void OnTick()
{
   if(newsFilter.IsRestricted()) return;
   if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MAX_SPREAD_ALLOWED) return;

   datetime currentBarTime = iTime(_Symbol, PERIOD_H1, 0);

   double h4EMA[], atr[], high[], low[], open[], close_prev[];
   ArraySetAsSeries(h4EMA, true); ArraySetAsSeries(atr, true);
   ArraySetAsSeries(high, true); ArraySetAsSeries(low, true); 
   ArraySetAsSeries(open, true); ArraySetAsSeries(close_prev, true);

   if(CopyBuffer(handleEMA_H4, 0, 0, 1, h4EMA) <= 0) return;
   if(CopyBuffer(handleATR, 0, 0, 1, atr) <= 0) return;
   if(CopyHigh(_Symbol, PERIOD_H1, 1, 1, high) <= 0) return;
   if(CopyLow(_Symbol, PERIOD_H1, 1, 1, low) <= 0) return;
   if(CopyOpen(_Symbol, PERIOD_H1, 1, 1, open) <= 0) return;
   if(CopyClose(_Symbol, PERIOD_H1, 1, 1, close_prev) <= 0) return;

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

      if(ask > high[0] && ask > h4EMA[0]) {
         if(trade.Buy(lot, _Symbol, ask, ask - slPoints, ask + tpPoints, "Predator_v11"))
            g_lastTradeBar = currentBarTime;
      }
      else if(bid < low[0] && bid < h4EMA[0]) {
         if(trade.Sell(lot, _Symbol, bid, bid + slPoints, bid - tpPoints, "Predator_v11"))
            g_lastTradeBar = currentBarTime;
      }
   }

   // 2. SAFETY: ATR TRAILING STOP
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)) && PositionGetInteger(POSITION_MAGIC) == InpMagic)
      {
         double p_open = PositionGetDouble(POSITION_PRICE_OPEN);
         double p_cur = PositionGetDouble(POSITION_PRICE_CURRENT);
         double p_sl = PositionGetDouble(POSITION_SL);
         double ts_dist = atr[0] * TS_DISTANCE_MULT;
         
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            if(p_cur > p_open + atr[0] * TS_ACTIVATION_MULT) {
               double new_sl = p_cur - ts_dist;
               if(new_sl > p_sl) trade.PositionModify(PositionGetTicket(i), new_sl, PositionGetDouble(POSITION_TP));
            }
         } else {
            if(p_cur < p_open - atr[0] * TS_ACTIVATION_MULT) {
               double new_sl = p_cur + ts_dist;
               if(new_sl < p_sl || p_sl == 0) trade.PositionModify(PositionGetTicket(i), new_sl, PositionGetDouble(POSITION_TP));
            }
         }
      }
   }
}
