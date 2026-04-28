//+------------------------------------------------------------------+
//|                                           Gold_Predator_HF.mq5  |
//|                                  Copyright 2024, Gemini CLI Agent |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini CLI Agent"
#property link      "https://www.mql5.com"
#property version   "0.6.0"
#property strict

#include <Trade\Trade.mqh>
#include <AppCore\RiskManager.mqh>
#include <AppCore\NewsFilter.mqh>

//--- v0.6.0 Price Action & Hyper BE Constants
#define MAX_SPREAD_ALLOWED 80
#define RISK_PERCENT 1.0
#define ATR_SL_MULT 1.5
#define ATR_TP_MULT 2.5

//--- Hyper BE Settings (User Requested Tightness)
#define BE_START_POINTS 300   // 30 points (3.0 USD in Gold terms)
#define BE_TARGET_POINTS 100  // 10 points (1.0 USD protection)

//--- UTC Trading Hours
#define UTC_START_HOUR 7
#define UTC_END_HOUR   17

input long InpMagic = 888200;

int handleATR, handleEMA_H1;
CTrade trade;
CRiskManager riskManager;
CNewsFilter newsFilter;

datetime g_lastTradeBar = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   handleATR    = iATR(_Symbol, _Period, 14);
   handleEMA_H1 = iMA(_Symbol, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE);
   
   if(handleATR == INVALID_HANDLE || handleEMA_H1 == INVALID_HANDLE) return(INIT_FAILED);

   trade.SetExpertMagicNumber(InpMagic);
   riskManager.Init(_Symbol, true, RISK_PERCENT, 0.1);
   newsFilter.Init(_Symbol, InpMagic, true, 60, 60, 7);
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { IndicatorRelease(handleATR); IndicatorRelease(handleEMA_H1); }

//+------------------------------------------------------------------+
void OnTick()
{
   if(newsFilter.IsRestricted()) return;
   if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MAX_SPREAD_ALLOWED) return;

   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   MqlDateTime dt_utc;
   TimeGMT(dt_utc);

   // 1. DATA ACCESS
   double h1EMA[], atr[], high[], low[], close[];
   ArraySetAsSeries(h1EMA, true); ArraySetAsSeries(atr, true);
   ArraySetAsSeries(high, true); ArraySetAsSeries(low, true); ArraySetAsSeries(close, true);

   if(CopyBuffer(handleEMA_H1, 0, 0, 1, h1EMA) <= 0) return;
   if(CopyBuffer(handleATR, 0, 0, 1, atr) <= 0) return;
   if(CopyHigh(_Symbol, _Period, 1, 1, high) <= 0) return;
   if(CopyLow(_Symbol, _Period, 1, 1, low) <= 0) return;
   if(CopyClose(_Symbol, _Period, 0, 1, close) <= 0) return;

   // 2. ENTRY LOGIC (Pure Price Action + UTC Filter)
   if(PositionsTotal() == 0 && currentBarTime != g_lastTradeBar && dt_utc.hour >= UTC_START_HOUR && dt_utc.hour < UTC_END_HOUR)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double slPoints = atr[0] * ATR_SL_MULT;
      double tpPoints = atr[0] * ATR_TP_MULT;

      // Price Breakout of Previous M5 Bar
      if(close[0] > h1EMA[0] && close[0] > high[0]) {
         if(trade.Buy(riskManager.CalculateLot(slPoints/_Point), _Symbol, ask, ask - slPoints, ask + tpPoints, "v0.6.0_PA_B"))
            g_lastTradeBar = currentBarTime;
      }
      else if(close[0] < h1EMA[0] && close[0] < low[0]) {
         if(trade.Sell(riskManager.CalculateLot(slPoints/_Point), _Symbol, bid, bid + slPoints, bid - tpPoints, "v0.6.0_PA_S"))
            g_lastTradeBar = currentBarTime;
      }
   }
   
   // 3. HYPER FAST PROTECTION
   ManageExits();
}

void ManageExits()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)) && PositionGetInteger(POSITION_MAGIC) == InpMagic)
      {
         double open = PositionGetDouble(POSITION_PRICE_OPEN);
         double cur = PositionGetDouble(POSITION_PRICE_CURRENT);
         double sl = PositionGetDouble(POSITION_SL);
         
         // Hyper Fast Break Even
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            if(sl < open && cur > open + BE_START_POINTS * _Point) {
               trade.PositionModify(PositionGetTicket(i), open + BE_TARGET_POINTS * _Point, PositionGetDouble(POSITION_TP));
            }
         } else {
            if((sl > open || sl == 0) && cur < open - BE_START_POINTS * _Point) {
               trade.PositionModify(PositionGetTicket(i), open - BE_TARGET_POINTS * _Point, PositionGetDouble(POSITION_TP));
            }
         }
      }
   }
}
