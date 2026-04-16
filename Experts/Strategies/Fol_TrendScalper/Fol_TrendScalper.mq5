//+------------------------------------------------------------------+
//|                                           Fol_TrendScalper.mq5   |
//|                                  Copyright 2026, Antigravity AI |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property link      "https://github.com/google-deepmind/antigravity"
#property version   "1.60"
#property strict

#include <Trade\Trade.mqh>
#include <AppCore\NewsFilter.mqh>
#include <AppCore\RiskManager.mqh>
#include <AppCore\TradeGuard.mqh>

//--- 入力パラメータ (順張りトレンドスキャル - Gold Special)
input int      InpADXPeriod    = 14;          // ADX 期間
input int      InpADXThreshold = 30;          // トレンド判定しきい値 (10年検証安定値)
input int      InpRSIPeriod    = 14;          // RSI 期間
input double   InpRSIPullback  = 30.0;        // RSI 押し目/戻り目しきい値
input double   InpBBExpRatio   = 1.1;         // ボラティリティ拡大比率 (エクスパンション)
input int      InpATRPeriod    = 14;          // ATR 期間
input double   InpSLMultiplier = 2.0;         // SL倍率 (Gold用に広め)
input double   InpRiskPercent  = 1.0;         // リスク百分率 (%)
input double   InpTPMultiplier = 1.0;         // TP倍率 (SL x N) [Scalp Mode]
input bool     InpUseBE        = true;        // 建値決済(Breakeven)使用
input double   InpBETrigger    = 0.5;         // BEトリガー (ATR倍数)
input double   InpBEProfit     = 0.5;         // BE時確保利益 (Pips)
input int      InpMaxSpread    = 100;         // Max spread allowed
input long     InpMagicNumber  = 500001;      // マジックナンバー
input bool     InpUseHTF       = true;        // 上位足トレンドフィルタ使用
input bool     InpUseNews      = true;        // ニュースフィルタ使用
input int      InpStartHour    = 1;           // 取引開始時間 (サーバー時間)
input int      InpEndHour      = 23;          // 取引終了時間 (サーバー時間)
input bool     InpUseVolFilter = true;        // ボラティリティ急変フィルタ使用
input double   InpVolMultiplier = 2.0;       // ボラティリティ倍率 (ATR比)
input int      InpEMA_Long     = 200;         // 長期 EMA 期間
input int      InpEMA_Med      = 50;          // 中期 EMA 期間
input int      InpEMA_Short    = 20;          // 短期 EMA 期間
input ENUM_TIMEFRAMES InpHTF   = PERIOD_H1;   // トレンド判定用上位足
input int      InpBBPeriod     = 20;          // BB 期間
input double   InpBBSigma      = 2.0;         // BB 標準偏差

//--- グローバル
CTrade          trade;
CNewsFilter     newsFilter;
CRiskManager    riskManager;
CTradeGuard     tradeGuard;

// 指標ハンドル
int handleEMA_Long, handleEMA_Med, handleEMA_Short, handleHTF_EMA, handleRSI, handleATR, handleADX, handleBB;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   handleEMA_Long  = iMA(_Symbol, _Period, InpEMA_Long, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA_Med   = iMA(_Symbol, _Period, InpEMA_Med, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA_Short = iMA(_Symbol, _Period, InpEMA_Short, 0, MODE_EMA, PRICE_CLOSE);
   handleHTF_EMA   = iMA(_Symbol, InpHTF, 200, 0, MODE_EMA, PRICE_CLOSE);
   handleRSI       = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   handleATR       = iATR(_Symbol, _Period, InpATRPeriod);
   handleADX       = iADX(_Symbol, _Period, InpADXPeriod);
   handleBB        = iBands(_Symbol, _Period, InpBBPeriod, 0, InpBBSigma, PRICE_CLOSE);

   if(handleEMA_Long == INVALID_HANDLE || handleRSI == INVALID_HANDLE || handleBB == INVALID_HANDLE)
      return INIT_FAILED;

   riskManager.Init(_Symbol, true, InpRiskPercent, 0.01);
   tradeGuard.Init(_Symbol, InpMaxSpread, InpStartHour, InpEndHour, InpUseVolFilter, InpVolMultiplier);
   newsFilter.Init(_Symbol, InpMagicNumber, InpUseNews, 60, 60, 7);

   trade.SetExpertMagicNumber(InpMagicNumber);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| EA Tick processing                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(newsFilter.IsRestricted()) return;
   if(!tradeGuard.IsAllowed()) return;

   ManagePositions();

   static datetime lastBar = 0;
   datetime currentBar = iTime(_Symbol, _Period, 0);
   if(lastBar == currentBar) return;

   double emaL[], emaM[], emaS[], htfEma[], rsi[], atr[], adx[], bbUpper[], bbLower[];
   ArraySetAsSeries(emaL, true); ArraySetAsSeries(emaM, true); ArraySetAsSeries(emaS, true);
   ArraySetAsSeries(htfEma, true); ArraySetAsSeries(rsi, true); ArraySetAsSeries(atr, true);
   ArraySetAsSeries(adx, true); ArraySetAsSeries(bbUpper, true); ArraySetAsSeries(bbLower, true);

   if(CopyBuffer(handleEMA_Long, 0, 0, 2, emaL) < 2) return;
   if(CopyBuffer(handleEMA_Med, 0, 0, 2, emaM) < 2) return;
   if(CopyBuffer(handleEMA_Short, 0, 0, 2, emaS) < 2) return;
   if(CopyBuffer(handleHTF_EMA, 0, 0, 2, htfEma) < 2) return;
   if(CopyBuffer(handleRSI, 0, 0, 2, rsi) < 2) return;
   if(CopyBuffer(handleATR, 0, 0, 2, atr) < 2) return;
   if(CopyBuffer(handleADX, 0, 0, 2, adx) < 2) return;
   if(CopyBuffer(handleBB, 1, 0, 21, bbUpper) < 21) return;
   if(CopyBuffer(handleBB, 2, 0, 21, bbLower) < 21) return;

   double close0 = iClose(_Symbol, _Period, 0);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   bool isTrend = (adx[0] > InpADXThreshold);
   double currentWidth = bbUpper[0] - bbLower[0];
   double avgPrevWidth = 0; int count = 0;
   for(int i=1; i<=20; i++) {
      double w = bbUpper[i] - bbLower[i];
      if(w > 0) { avgPrevWidth += w; count++; }
   }
   if(count > 0) avgPrevWidth /= count; else avgPrevWidth = currentWidth;
   bool isExpanding = (currentWidth > avgPrevWidth * InpBBExpRatio);

   if(PositionsTotal() == 0 && isTrend && isExpanding)
   {
      bool htfUp = !InpUseHTF || (close0 > htfEma[0]);
      bool htfDown = !InpUseHTF || (close0 < htfEma[0]);
      bool isUpTrend   = (htfUp && close0 > emaL[0] && emaS[0] > emaM[0]);
      bool isDownTrend = (htfDown && close0 < emaL[0] && emaS[0] < emaM[0]);

      bool buyCondition = (rsi[1] < InpRSIPullback && rsi[0] >= InpRSIPullback) || (rsi[0] >= InpRSIPullback && rsi[1] >= InpRSIPullback && close0 > emaS[0]);
      if(isUpTrend && buyCondition) {
         double sl = ask - (atr[0] * InpSLMultiplier);
         double tp = ask + (atr[0] * InpSLMultiplier * InpTPMultiplier);
         trade.Buy(riskManager.CalculateLot(atr[0] * InpSLMultiplier), _Symbol, ask, sl, tp, "Momentum Buy");
         lastBar = currentBar;
      }

      bool sellCondition = (rsi[1] > (100-InpRSIPullback) && rsi[0] <= (100-InpRSIPullback)) || (rsi[0] <= (100-InpRSIPullback) && rsi[1] <= (100-InpRSIPullback) && close0 < emaS[0]);
      if(isDownTrend && sellCondition) {
         double sl = bid + (atr[0] * InpSLMultiplier);
         double tp = bid - (atr[0] * InpSLMultiplier * InpTPMultiplier);
         trade.Sell(riskManager.CalculateLot(atr[0] * InpSLMultiplier), _Symbol, bid, sl, tp, "Momentum Sell");
         lastBar = currentBar;
      }
   }
}

//+------------------------------------------------------------------+
//| ポジション管理                                                    |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            double emaS[]; ArraySetAsSeries(emaS, true); CopyBuffer(handleEMA_Short, 0, 0, 1, emaS);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double currentSL = PositionGetDouble(POSITION_SL);
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);

            if(InpUseBE) {
               double atr[]; ArraySetAsSeries(atr, true); CopyBuffer(handleATR, 0, 0, 1, atr);
               double triggerDist = atr[0] * InpBETrigger;
               double bePrice = (type == POSITION_TYPE_BUY) ? (openPrice + InpBEProfit * _Point) : (openPrice - InpBEProfit * _Point);
               if(type == POSITION_TYPE_BUY && bid > openPrice + triggerDist && currentSL < openPrice) {
                  trade.PositionModify(ticket, bePrice, PositionGetDouble(POSITION_TP)); continue;
               } else if(type == POSITION_TYPE_SELL && ask < openPrice - triggerDist && (currentSL > openPrice || currentSL == 0)) {
                  trade.PositionModify(ticket, bePrice, PositionGetDouble(POSITION_TP)); continue;
               }
            }

            if(type == POSITION_TYPE_BUY && bid > openPrice && emaS[0] > currentSL)
               trade.PositionModify(ticket, emaS[0], PositionGetDouble(POSITION_TP));
            else if(type == POSITION_TYPE_SELL && ask < openPrice && (emaS[0] < currentSL || currentSL == 0))
               trade.PositionModify(ticket, emaS[0], PositionGetDouble(POSITION_TP));
         }
      }
   }
}
