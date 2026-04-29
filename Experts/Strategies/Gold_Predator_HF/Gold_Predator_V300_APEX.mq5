//+------------------------------------------------------------------+
//|                                     Gold_Predator_V210_PRO.mq5  |
//|                                  Copyright 2024, Gemini CLI Agent |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini CLI Agent"
#property link      "https://www.mql5.com"
#property version   "3.0.0"
#property strict

#include <Trade\Trade.mqh>
#include <AppCore\RiskManager.mqh>
#include <AppCore\NewsFilter.mqh>

//--- v3.0.0 THE APEX PREDATOR (H1 Trend Follower)
//--- Designed to ignore noise and dominate with long-term trends.
#define MAX_SPREAD_ALLOWED 50  // H1 is spread-resistant
#define ATR_SL_MULT 1.5
#define ATR_TP_MULT 4.0

//--- Apex Precision (H1 Focus)
#define MIN_MOMENTUM_RATIO 1.5 
#define UTC_START_HOUR 0       // Trade all day to catch H1 trends
#define UTC_END_HOUR   23

input double InpRiskPercent = 3.0;
input long   InpMagic       = 333000; // Apex Series Magic

int handleATR, handleEMA_H4;
CTrade trade;
CRiskManager riskManager;
CNewsFilter newsFilter;

datetime g_lastTradeBar = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   // Higher timeframes for maximum stability
   handleATR    = iATR(_Symbol, PERIOD_H1, 14);
   handleEMA_H4 = iMA(_Symbol, PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE);
   
   trade.SetExpertMagicNumber(InpMagic);
   riskManager.Init(_Symbol, true, InpRiskPercent, 0.01);
   newsFilter.Init(_Symbol, InpMagic, true, 60, 60, 7);
   
   Print("EA_LOAD: v3.0.0 APEX PREDATOR (H1). Ready to dominate Gold.");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { IndicatorRelease(handleATR); IndicatorRelease(handleEMA_H4); }

//+------------------------------------------------------------------+
void OnTick()
{
   if(newsFilter.IsRestricted()) return;
   if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MAX_SPREAD_ALLOWED) return;

   datetime currentBarTime = iTime(_Symbol, PERIOD_H1, 0);
   MqlDateTime dt_utc;
   TimeGMT(dt_utc);

   // 1. H1 DATA ACCESS
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

   // 2. APEX ENTRY (H1 Breakout)
   if(PositionsTotal() == 0 && currentBarTime != g_lastTradeBar)
   {
      // Momentum Filter on H1
      if(body < atr[0] * MIN_MOMENTUM_RATIO) return;

      double slPoints = atr[0] * ATR_SL_MULT;
      double tpPoints = atr[0] * ATR_TP_MULT;
      double lot = riskManager.CalculateLot(slPoints / _Point);

      // Buy when breaking H1 high and H4 trend is UP
      if(ask > high[0] && ask > h4EMA[0]) {
         if(trade.Buy(lot, _Symbol, ask, ask - slPoints, ask + tpPoints, "v300_APEX"))
            g_lastTradeBar = currentBarTime;
      }
      // Sell when breaking H1 low and H4 trend is DOWN
      else if(bid < low[0] && bid < h4EMA[0]) {
         if(trade.Sell(lot, _Symbol, bid, bid + slPoints, bid - tpPoints, "v300_APEX"))
            g_lastTradeBar = currentBarTime;
      }
   }
}
