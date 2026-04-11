//+------------------------------------------------------------------+
//|                                           Fol_TrendScalper.mq5   |
//|                                  Copyright 2026, Antigravity AI |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property link      "https://github.com/google-deepmind/antigravity"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <AppCore\NewsFilter.mqh>
#include <AppCore\RiskManager.mqh>
#include <AppCore\TradeGuard.mqh>

//--- 入力パラメータ (順張りトレンドスキャル)
input int      InpEMA_Long     = 200;         // 長期トレンド (EMA 200)
input int      InpEMA_Med      = 50;          // 中期 momentum (EMA 50)
input int      InpEMA_Short    = 20;          // 短期 momentum (EMA 20)
input ENUM_TIMEFRAMES InpHTF   = PERIOD_H1;   // 上位足トレンドフィルタ
input int      InpRSIPeriod    = 14;          // RSI 期間
input double   InpRSIPullback  = 35.0;        // 押し目しきい値 (通常35/65)
input int      InpATRPeriod    = 14;          // ATR 期間
input double   InpSLMultiplier = 1.5;         // SL倍率 (ATR x N)
input double   InpRiskPercent  = 1.0;         // リスク百分率 (%)
input int      InpMaxSpread    = 25;          // 許容最大スプレッド
input long     InpMagicNumber  = 500001;      // マジックナンバー
input bool     InpUseNews      = true;        // ニュースフィルタ使用

//--- グローバル
CTrade          trade;
CNewsFilter     newsFilter;
CRiskManager    riskManager;
CTradeGuard     tradeGuard;

int handleEMA_Long, handleEMA_Med, handleEMA_Short, handleHTF_EMA;
int handleRSI, handleATR;

//+------------------------------------------------------------------+
//| EA Initialization                                                |
//+------------------------------------------------------------------+
int OnInit()
{
   // ライブラリ初期化
   if(!newsFilter.Init(_Symbol, InpMagicNumber, InpUseNews, 30, 60, 3)) return INIT_FAILED;
   riskManager.Init(_Symbol, true, InpRiskPercent, 0.01);
   tradeGuard.Init(_Symbol, InpMaxSpread, 0, 24);

   // 指標ハンドル
   handleEMA_Long  = iMA(_Symbol, _Period, InpEMA_Long, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA_Med   = iMA(_Symbol, _Period, InpEMA_Med, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA_Short = iMA(_Symbol, _Period, InpEMA_Short, 0, MODE_EMA, PRICE_CLOSE);
   handleHTF_EMA   = iMA(_Symbol, InpHTF, InpEMA_Long, 0, MODE_EMA, PRICE_CLOSE);
   handleRSI       = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   handleATR       = iATR(_Symbol, _Period, InpATRPeriod);

   if(handleEMA_Long == INVALID_HANDLE || handleHTF_EMA == INVALID_HANDLE || handleRSI == INVALID_HANDLE)
   {
      Print("指標ハンドル取得に失敗しました。");
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(InpMagicNumber);
   DisplayInfo();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| EA Tick processing                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // 共通ガードチェック
   if(newsFilter.IsRestricted()) return;
   if(!tradeGuard.IsAllowed()) return;

   // ポジション管理 & トレーリングストップ
   ManagePositions();

   // 1バー1トレード
   static datetime lastBar = 0;
   datetime currentBar = iTime(_Symbol, _Period, 0);
   if(lastBar == currentBar) return;

   // データ取得
   double emaL[], emaM[], emaS[], htfEma[], rsi[], atr[];
   ArraySetAsSeries(emaL, true);
   ArraySetAsSeries(emaM, true);
   ArraySetAsSeries(emaS, true);
   ArraySetAsSeries(htfEma, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(atr, true);

   if(CopyBuffer(handleEMA_Long, 0, 0, 2, emaL) < 2) return;
   if(CopyBuffer(handleEMA_Med, 0, 0, 2, emaM) < 2) return;
   if(CopyBuffer(handleEMA_Short, 0, 0, 2, emaS) < 2) return;
   if(CopyBuffer(handleHTF_EMA, 0, 0, 2, htfEma) < 2) return;
   if(CopyBuffer(handleRSI, 0, 0, 2, rsi) < 2) return;
   if(CopyBuffer(handleATR, 0, 0, 2, atr) < 2) return;

   double close0 = iClose(_Symbol, _Period, 0);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // --- エントリーロジック ---
   
   // 1. 上位足トレンド(HTF) と 局所トレンド(EMA200) の一致
   bool isUpTrend   = (close0 > htfEma[0] && close0 > emaL[0] && emaS[0] > emaM[0]);
   bool isDownTrend = (close0 < htfEma[0] && close0 < emaL[0] && emaS[0] < emaM[0]);

   if(PositionsTotal() == 0)
   {
      // 買い: トレンド中 + RSIが押し目(35以下)から反転
      if(isUpTrend && rsi[1] < InpRSIPullback && rsi[0] >= InpRSIPullback)
      {
         double sl = ask - (atr[0] * InpSLMultiplier);
         double tp = ask + (atr[0] * InpSLMultiplier * 2.5); // 順張りなので広め
         double lots = riskManager.CalculateLot(atr[0] * InpSLMultiplier);
         
         if(trade.Buy(lots, _Symbol, ask, sl, tp, "TrendFol M5 Buy")) lastBar = currentBar;
      }
      // 売り: トレンド中 + RSIが戻り(65以上)から反転
      else if(isDownTrend && rsi[1] > (100-InpRSIPullback) && rsi[0] <= (100-InpRSIPullback))
      {
         double sl = bid + (atr[0] * InpSLMultiplier);
         double tp = bid - (atr[0] * InpSLMultiplier * 2.5);
         double lots = riskManager.CalculateLot(atr[0] * InpSLMultiplier);
         
         if(trade.Sell(lots, _Symbol, bid, sl, tp, "TrendFol M5 Sell")) lastBar = currentBar;
      }
   }

   DisplayInfo();
}

//+------------------------------------------------------------------+
//| ポジション管理 & トレーリングストップ                                 |
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
            double emaS[];
            ArraySetAsSeries(emaS, true);
            CopyBuffer(handleEMA_Short, 0, 0, 1, emaS);

            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double currentSL = PositionGetDouble(POSITION_SL);
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

            // 短期EMA(20)をベースにした動的トレーリングストップ
            if(type == POSITION_TYPE_BUY)
            {
               // 含み益が出ており、EMA20が現在のSLより上にある場合のみ更新
               if(bid > PositionGetDouble(POSITION_PRICE_OPEN) && emaS[0] > currentSL)
               {
                  trade.PositionModify(ticket, emaS[0], PositionGetDouble(POSITION_TP));
               }
            }
            else if(type == POSITION_TYPE_SELL)
            {
               if(ask < PositionGetDouble(POSITION_PRICE_OPEN) && (emaS[0] < currentSL || currentSL == 0))
               {
                  trade.PositionModify(ticket, emaS[0], PositionGetDouble(POSITION_TP));
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| チャート上に情報を表示する                                         |
//+------------------------------------------------------------------+
void DisplayInfo()
{
   string text = "=== Fol_TrendScalper v1.00 ===\n";
   text += "Symbol: " + _Symbol + " (" + EnumToString(_Period) + ")\n";
   text += "HTF Trend: " + EnumToString(InpHTF) + "\n";
   text += "---------------------------\n";
   text += newsFilter.GetStatusString() + "\n";
   text += riskManager.GetStatusString() + "\n";
   text += tradeGuard.GetStatusString() + "\n";
   text += "---------------------------\n";
   text += "Strategy Params (Scalping):\n";
   text += StringFormat(" - Long EMA: %d\n", InpEMA_Long);
   text += StringFormat(" - RSI Pullback: %.1f\n", InpRSIPullback);
   text += StringFormat(" - SL Multiplier: %.1f\n", InpSLMultiplier);
   text += "---------------------------\n";
   
   Comment(text);
}
