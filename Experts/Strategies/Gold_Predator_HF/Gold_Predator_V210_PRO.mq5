//+------------------------------------------------------------------+
//|                                     Gold_Predator_V210_PRO.mq5  |
//|                                  Copyright 2024, Gemini CLI Agent |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini CLI Agent"
#property link      "https://www.mql5.com"
#property version   "2.4.0"
#property strict

#include <Trade\Trade.mqh>
#include <AppCore\RiskManager.mqh>
#include <AppCore\NewsFilter.mqh>

//--- v2.4.0 PROFESSIONAL EDGE (Final Release)
#define MAX_SPREAD_ALLOWED 40
#define ATR_SL_MULT 1.5
#define ATR_TP_MULT 5.0

#define MIN_MOMENTUM_RATIO 1.2
#define BE_START_POINTS 1000
#define BE_TARGET_POINTS 200

#define UTC_START_HOUR 7
#define UTC_END_HOUR   20

//--- Parameters
input double InpFixedLot    = 0.0;   // 固定ロット (0.0で複利)
input double InpRiskPercent = 2.0;   // 1トレードの許容損失(%)
input long   InpMagic       = 999100;

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
   // 資金管理の初期化
   riskManager.Init(_Symbol, (InpFixedLot == 0), InpRiskPercent, 0.01);
   // ニュースフィルタの初期化 (重要度：高のみ、前後60分回避)
   newsFilter.Init(_Symbol, InpMagic, true, 60, 60, 7);
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { IndicatorRelease(handleATR); IndicatorRelease(handleEMA_H1); }

//+------------------------------------------------------------------+
void OnTick()
{
   // 1. 安全装置 (指標 & スプレッド)
   if(newsFilter.IsRestricted()) return;
   if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MAX_SPREAD_ALLOWED) return;

   datetime currentBarTime = iTime(_Symbol, PERIOD_M5, 0);
   MqlDateTime dt_utc;
   TimeGMT(dt_utc);

   // 2. データの取得
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

   // 3. エントリーロジック
   if(PositionsTotal() == 0 && currentBarTime != g_lastTradeBar && dt_utc.hour >= UTC_START_HOUR && dt_utc.hour < UTC_END_HOUR)
   {
      if(body < atr[0] * MIN_MOMENTUM_RATIO) return;

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double slPoints = atr[0] * ATR_SL_MULT;
      double tpPoints = atr[0] * ATR_TP_MULT;
      
      // ロットの動的計算
      double lot = (InpFixedLot > 0) ? InpFixedLot : riskManager.CalculateLot(slPoints / _Point);

      if(close[0] > h1EMA[0] && close[0] > high[0]) {
         if(trade.Buy(lot, _Symbol, ask, ask - slPoints, ask + tpPoints, "v240_FINAL"))
            g_lastTradeBar = currentBarTime;
      }
      else if(close[0] < h1EMA[0] && close[0] < low[0]) {
         if(trade.Sell(lot, _Symbol, bid, bid + slPoints, bid - tpPoints, "v240_FINAL"))
            g_lastTradeBar = currentBarTime;
      }
   }

   // 4. 決済管理 (BE)
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
