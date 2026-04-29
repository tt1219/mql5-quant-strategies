//+------------------------------------------------------------------+
//|                                                Gold_Predator.mq5 |
//|                                  Copyright 2024, Gemini CLI Agent |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini CLI Agent"
#property link      "https://www.mql5.com"
#property version   "1.3.2"
#property strict

#include <Trade\Trade.mqh>
#include <AppCore\RiskManager.mqh>
#include <AppCore\NewsFilter.mqh>

//--- Gold_Predator v1.3.2 "The Hybrid King - ADX Filtered"
#define MAX_SPREAD_ALLOWED 50
#define ADX_THRESHOLD 25

input double InpTPMult        = 6.5;    
input double InpMomentumRatio = 1.0;    
input double InpRiskPercent   = 3.0;    
input double InpSLMult        = 1.5;
input long   InpMagic         = 777777; 

int handleATR, handleEMA_H4, handleADX;
CTrade trade;
CRiskManager riskManager;
CNewsFilter newsFilter;
datetime g_lastTradeBar = 0;

int OnInit() {
   handleATR    = iATR(_Symbol, PERIOD_H1, 14);
   handleEMA_H4 = iMA(_Symbol, PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE);
   handleADX    = iADX(_Symbol, PERIOD_H1, 14);
   
   trade.SetExpertMagicNumber(InpMagic);
   riskManager.Init(_Symbol, true, InpRiskPercent, 0.01);
   newsFilter.Init(_Symbol, InpMagic, true, 60, 60, 7);
   DisplayStatus();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { 
   IndicatorRelease(handleATR); 
   IndicatorRelease(handleEMA_H4); 
   IndicatorRelease(handleADX);
   Comment(""); 
}

void DisplayStatus() {
   double adx[];
   CopyBuffer(handleADX, 0, 0, 1, adx);
   string status = "=== Gold Predator HF: HYBRID KING ===\n" +
                   "Version: 1.3.2 (ADX Filtered)\n" +
                   "-----------------------------------\n" +
                   "ADX: " + DoubleToString(adx[0], 1) + " (Min: " + (string)ADX_THRESHOLD + ")\n" +
                   "TP Multiplier: " + DoubleToString(InpTPMult, 1) + "\n" +
                   "Risk Percent: " + DoubleToString(InpRiskPercent, 1) + "%\n" +
                   "Status: " + (newsFilter.IsRestricted() ? "NEWS RESTRICTED" : (adx[0] < ADX_THRESHOLD ? "RANGING" : "TRENDING")) + "\n";
   Comment(status);
}

void OnTick() {
   DisplayStatus();
   if(newsFilter.IsRestricted()) return;
   if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MAX_SPREAD_ALLOWED) return;

   datetime currentBarTime = iTime(_Symbol, PERIOD_H1, 0);
   double h4EMA[], atr[], high[], low[], open[], close_prev[], adx[];
   ArraySetAsSeries(h4EMA, true); ArraySetAsSeries(atr, true);
   ArraySetAsSeries(high, true); ArraySetAsSeries(low, true); 
   ArraySetAsSeries(open, true); ArraySetAsSeries(close_prev, true);
   ArraySetAsSeries(adx, true);

   if(CopyBuffer(handleEMA_H4, 0, 0, 1, h4EMA) <= 0) return;
   if(CopyBuffer(handleATR, 0, 0, 1, atr) <= 0) return;
   if(CopyBuffer(handleADX, 0, 0, 1, adx) <= 0) return;
   
   // TREND FILTER: Only trade if trend is strong
   if(adx[0] < ADX_THRESHOLD) return;
   if(CopyHigh(_Symbol, PERIOD_H1, 1, 1, high) <= 0) return;
   if(CopyLow(_Symbol, PERIOD_H1, 1, 1, low) <= 0) return;
   if(CopyOpen(_Symbol, PERIOD_H1, 1, 1, open) <= 0) return;
   if(CopyClose(_Symbol, PERIOD_H1, 1, 1, close_prev) <= 0) return;

   double body = MathAbs(close_prev[0] - open[0]);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(PositionsTotal() == 0 && currentBarTime != g_lastTradeBar) {
      if(body < atr[0] * InpMomentumRatio) return;
      double slPoints = atr[0] * InpSLMult;
      double tpPoints = atr[0] * InpTPMult;
      double lot = riskManager.CalculateLot(slPoints / _Point);

      if(ask > high[0] && ask > h4EMA[0]) {
         if(trade.Buy(lot, _Symbol, ask, ask - slPoints, ask + tpPoints, "v131_KING")) g_lastTradeBar = currentBarTime;
      } else if(bid < low[0] && bid < h4EMA[0]) {
         if(trade.Sell(lot, _Symbol, bid, bid + slPoints, bid - tpPoints, "v131_KING")) g_lastTradeBar = currentBarTime;
      }
   }
}
