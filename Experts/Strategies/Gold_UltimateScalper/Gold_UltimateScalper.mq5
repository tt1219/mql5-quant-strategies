//+------------------------------------------------------------------+
//|                                        Gold_UltimateScalper.mq5  |
//|                                  Copyright 2024, Gemini CLI Agent |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini CLI Agent"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//--- Include
#include <Trade\Trade.mqh>
#include <AppCore\TradeGuard.mqh>
#include <AppCore\RiskManager.mqh>
#include <AppCore\NewsFilter.mqh>
#include <MovingAverages.mqh>

//--- Input Parameters
input group "=== Global Settings ==="
input long      InpMagic             = 888123;      // Magic Number
input double    InpLotSize           = 0.1;         // Fixed Lot Size (if Risk=false)
input int       InpStopLoss          = 200;         // Stop Loss (Points)
input int       InpTakeProfit        = 400;         // Take Profit (Points)
input int       InpMaxSpread         = 30;          // Max Spread (Points)
input int       InpSlippage          = 30;          // Slippage (Points)

input group "=== Risk Management ==="
input bool      InpUseRisk           = true;        // Use Dynamic Risk
input double    InpRiskPercent       = 1.0;         // Risk Percent per Trade

input group "=== News Filter ==="
input bool      InpUseNews           = true;        // Use News Filter
input int       InpNewsMinBefore     = 60;          // Minutes Before News
input int       InpNewsMinAfter      = 60;          // Minutes After News

input group "=== Asian Engine Settings ==="
input bool      InpAsianEnabled      = true;        // Asian Engine Enabled
input int       InpAsianStartHour    = 22;          // Start Hour (Server Time)
input int       InpAsianEndHour      = 6;           // End Hour (Server Time)
input int       InpAsianBBPeriod     = 20;          // BB Period
input double    InpAsianBBDev        = 2.0;         // BB Deviation
input int       InpAsianRSIPeriod    = 14;          // RSI Period
input int       InpAsianRSIUpper     = 70;          // RSI Upper Level
input int       InpAsianRSILower     = 30;          // RSI Lower Level

input group "=== London/NY Breakout Engine Settings ==="
input bool      InpBreakoutEnabled   = true;        // Breakout Engine Enabled
input int       InpBreakoutStartHour = 8;           // Start Hour (Server Time)
input int       InpBreakoutEndHour   = 16;          // End Hour (Server Time)
input int       InpRangeLookback     = 4;           // Range Lookback (Hours)
input double    InpBreakoutBuffer    = 50;          // Breakout Buffer (Points)

input group "=== Liquidity Sweep Engine Settings ==="
input bool      InpLiquidityEnabled  = true;        // Liquidity Engine Enabled
input int       InpLiquidityLookback = 20;          // High/Low Lookback Candles
input int       InpSweepBuffer       = 20;          // Sweep Buffer (Points)
input int       InpATRPeriod         = 14;          // ATR Period for Volatility

//--- Global Variables
int      handleBB, handleRSI, handleATR, handleEMA, handleVolume;
CTrade        trade;
CTradeGuard   tradeGuard;
CRiskManager  riskManager;
CNewsFilter   newsFilter;

enum ENUM_SIGNAL { SIGNAL_NONE, SIGNAL_BUY, SIGNAL_SELL };
string   g_activeEngine = "NONE";

//+------------------------------------------------------------------+
//| Asian Engine: Range Mean Reversion                               |
//+------------------------------------------------------------------+
ENUM_SIGNAL GetAsianSignal()
{
   if(!InpAsianEnabled) return SIGNAL_NONE;
   
   MqlDateTime dt;
   TimeCurrent(dt);
   
   // Check session time
   bool inSession = false;
   if(InpAsianStartHour > InpAsianEndHour) {
      if(dt.hour >= InpAsianStartHour || dt.hour < InpAsianEndHour) inSession = true;
   } else {
      if(dt.hour >= InpAsianStartHour && dt.hour < InpAsianEndHour) inSession = true;
   }
   if(!inSession) return SIGNAL_NONE;
   
   double bbUpper[], bbLower[], rsi[];
   ArraySetAsSeries(bbUpper, true);
   ArraySetAsSeries(bbLower, true);
   ArraySetAsSeries(rsi, true);
   
   if(CopyBuffer(handleBB, 1, 0, 3, bbUpper) <= 0) return SIGNAL_NONE;
   if(CopyBuffer(handleBB, 2, 0, 3, bbLower) <= 0) return SIGNAL_NONE;
   if(CopyBuffer(handleRSI, 0, 0, 3, rsi) <= 0) return SIGNAL_NONE;
   
   double close = iClose(_Symbol, _Period, 0);
   
   // Buy Signal: Price below Lower BB + RSI oversold
   if(close < bbLower[0] && rsi[0] < InpAsianRSILower) return SIGNAL_BUY;
   
   // Sell Signal: Price above Upper BB + RSI overbought
   if(close > bbUpper[0] && rsi[0] > InpAsianRSIUpper) return SIGNAL_SELL;
   
   return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| London/NY Breakout Engine: Momentum Following                    |
//+------------------------------------------------------------------+
ENUM_SIGNAL GetBreakoutSignal()
{
   if(!InpBreakoutEnabled) return SIGNAL_NONE;
   
   MqlDateTime dt;
   TimeCurrent(dt);
   
   // Check session time
   bool inSession = (dt.hour >= InpBreakoutStartHour && dt.hour < InpBreakoutEndHour);
   if(!inSession) return SIGNAL_NONE;
   
   // Calculate range of previous X hours
   datetime end = TimeCurrent();
   datetime start = end - InpRangeLookback * 3600;
   
   double high[], low[];
   if(CopyHigh(_Symbol, PERIOD_H1, 0, InpRangeLookback, high) <= 0) return SIGNAL_NONE;
   if(CopyLow(_Symbol, PERIOD_H1, 0, InpRangeLookback, low) <= 0) return SIGNAL_NONE;
   
   double rangeHigh = high[ArrayMaximum(high)];
   double rangeLow = low[ArrayMinimum(low)];
   
   double close = iClose(_Symbol, _Period, 0);
   double buffer = InpBreakoutBuffer * _Point;
   
   // Buy Signal: Break above range high
   if(close > rangeHigh + buffer) return SIGNAL_BUY;
   
   // Sell Signal: Break below range low
   if(close < rangeLow - buffer) return SIGNAL_SELL;
   
   return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Liquidity Sweep Engine: Reversal after Wick                      |
//+------------------------------------------------------------------+
ENUM_SIGNAL GetLiquiditySignal()
{
   if(!InpLiquidityEnabled) return SIGNAL_NONE;
   
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   if(CopyHigh(_Symbol, _Period, 1, InpLiquidityLookback, high) <= 0) return SIGNAL_NONE;
   if(CopyLow(_Symbol, _Period, 1, InpLiquidityLookback, low) <= 0) return SIGNAL_NONE;
   if(CopyClose(_Symbol, _Period, 0, 1, close) <= 0) return SIGNAL_NONE;
   
   double prevHigh = high[ArrayMaximum(high)];
   double prevLow = low[ArrayMinimum(low)];
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, _Period, 0, 1, rates) <= 0) return SIGNAL_NONE;
   
   double buffer = InpSweepBuffer * _Point;
   
   // Buy Signal: Low sweep (Current Low < Prev Low AND Current Close > Prev Low)
   if(rates[0].low < prevLow - buffer && rates[0].close > prevLow) return SIGNAL_BUY;
   
   // Sell Signal: High sweep (Current High > Prev High AND Current Close < Prev High)
   if(rates[0].high > prevHigh + buffer && rates[0].close < prevHigh) return SIGNAL_SELL;
   
   return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Task 1.3: Initialize Indicator Handles
   handleBB = iBands(_Symbol, _Period, InpAsianBBPediod, 0, InpAsianBBDev, PRICE_CLOSE);
   if(handleBB == INVALID_HANDLE) { Print("Failed to create BB handle"); return(INIT_FAILED); }
   
   handleRSI = iRSI(_Symbol, _Period, InpAsianRSIPeriod, PRICE_CLOSE);
   if(handleRSI == INVALID_HANDLE) { Print("Failed to create RSI handle"); return(INIT_FAILED); }
   
   handleATR = iATR(_Symbol, _Period, InpATRPeriod);
   if(handleATR == INVALID_HANDLE) { Print("Failed to create ATR handle"); return(INIT_FAILED); }
   
   handleEMA = iMA(_Symbol, _Period, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(handleEMA == INVALID_HANDLE) { Print("Failed to create EMA handle"); return(INIT_FAILED); }
   
   handleVolume = iVolumes(_Symbol, _Period, VOLUME_TICK);
   if(handleVolume == INVALID_HANDLE) { Print("Failed to create Volume handle"); return(INIT_FAILED); }

   //--- Initialize Core Modules
   trade.SetExpertMagicNumber(InpMagic);
   if(!tradeGuard.Init(_Symbol, InpMaxSpread, 0, 24)) { Print("TradeGuard Init Failed"); return(INIT_FAILED); }
   if(!riskManager.Init(_Symbol, InpUseRisk, InpRiskPercent, InpLotSize)) { Print("RiskManager Init Failed"); return(INIT_FAILED); }
   if(!newsFilter.Init(_Symbol, InpMagic, InpUseNews, InpNewsMinBefore, InpNewsMinAfter, 7)) { Print("NewsFilter Init Failed"); return(INIT_FAILED); }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(handleBB);
   IndicatorRelease(handleRSI);
   IndicatorRelease(handleATR);
   IndicatorRelease(handleEMA);
   IndicatorRelease(handleVolume);
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check News Restriction
   if(newsFilter.IsRestricted()) {
      g_activeEngine = "NEWS RESTRICTION";
      UpdateDashboard();
      return;
   }

   //--- Task 3.1: Session Manager
   ENUM_SIGNAL signal = SIGNAL_NONE;
   g_activeEngine = "NONE";
   
   // Priority 1: Breakout Engine (London/NY)
   signal = GetBreakoutSignal();
   if(signal != SIGNAL_NONE) g_activeEngine = "BREAKOUT";
   
   // Priority 2: Asian Engine
   if(signal == SIGNAL_NONE) {
      signal = GetAsianSignal();
      if(signal != SIGNAL_NONE) g_activeEngine = "ASIAN";
   }
   
   // Priority 3: Liquidity Engine
   if(signal == SIGNAL_NONE) {
      signal = GetLiquiditySignal();
      if(signal != SIGNAL_NONE) g_activeEngine = "LIQUIDITY";
   }
   
   //--- Execution
   if(signal != SIGNAL_NONE && PositionsTotal() == 0) {
      double slPoints = InpStopLoss * _Point;
      double sl = (signal == SIGNAL_BUY) ? (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - slPoints) : (SymbolInfoDouble(_Symbol, SYMBOL_BID) + slPoints);
      double tp = (signal == SIGNAL_BUY) ? (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + InpTakeProfit * _Point) : (SymbolInfoDouble(_Symbol, SYMBOL_BID) - InpTakeProfit * _Point);
      
      double lot = riskManager.CalculateLot(slPoints);
      
      if(signal == SIGNAL_BUY) trade.Buy(lot, _Symbol, 0, sl, tp, "GS: " + g_activeEngine);
      else trade.Sell(lot, _Symbol, 0, sl, tp, "GS: " + g_activeEngine);
   }
   
   //--- Task 3.2: Position Management
   ManagePositions();
   
   //--- Task 3.3: Dashboard
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Position Management                                              |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket)) {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagic) {
            // Trailing Stop Logic
            double currentSL = PositionGetDouble(POSITION_SL);
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
               if(bid - PositionGetDouble(POSITION_PRICE_OPEN) > InpStopLoss * _Point) {
                  double newSL = bid - InpStopLoss * _Point;
                  if(newSL > currentSL + _Point * 10) trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
               }
            } else {
               if(PositionGetDouble(POSITION_PRICE_OPEN) - ask > InpStopLoss * _Point) {
                  double newSL = ask + InpStopLoss * _Point;
                  if(newSL < currentSL - _Point * 10 || currentSL == 0) trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Dashboard Update                                                 |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   string text = "=== Gold Ultimate Scalper ===\n";
   text += "Status: " + newsFilter.GetStatusString() + "\n";
   text += "Risk: " + riskManager.GetStatusString() + "\n";
   text += "Active Engine: " + g_activeEngine + "\n";
   text += "Magic: " + IntegerToString(InpMagic) + "\n";
   text += "Positions: " + IntegerToString(PositionsTotal()) + "\n";
   Comment(text);
}
//+------------------------------------------------------------------+
