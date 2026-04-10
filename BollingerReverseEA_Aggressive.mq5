#property version   "3.13"
#property strict

#include <Trade\Trade.mqh>

//--- 入力パラメータ (v3.13: 極限緩和・超アグレッシブ)
input int      InpBandsPeriod  = 20;          // Bolinger Bands 期間
input double   InpBandsDev     = 1.8;         // 標準偏差 (一律1.8σへ緩和)
input int      InpRSIPeriod    = 14;          // RSI 期間
input double   InpRSILower     = 30.0;        // RSI 下限
input double   InpRSIUpper     = 70.0;        // RSI 上限
input int      InpEMAPeriod    = 200;         // トレンドフィルター (EMA 200)
input int      InpATRPeriod    = 14;          // ATR 期間
input double   InpSLMultiplier = 2.0;         // 損切りのATR倍率
input double   InpTPMultiplier = 1.0;         // 利確のATR倍率
input int      InpStartHour    = 0;           // 取引開始
input int      InpEndHour      = 22;          // 取引終了

//--- v3.13 資金管理
input bool     InpUseMM        = true;        // 複利運用を使用するか
input double   InpRiskPercent  = 5.0;         // リスク (5.0%)
input double   InpMinLot       = 0.01;        // 最小ロット
input int      InpMagicNumber  = 123456;      // マジックナンバー

//--- グローバル変数
int      handleBands, handleRSI, handleATR, handleEMA;
CTrade   trade;
datetime lastTradeBar = 0;

int OnInit()
  {
   handleBands = iBands(_Symbol, _Period, InpBandsPeriod, 0, InpBandsDev, PRICE_CLOSE);
   handleRSI = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   handleATR = iATR(_Symbol, _Period, InpATRPeriod);
   handleEMA = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   if(handleBands == INVALID_HANDLE || handleRSI == INVALID_HANDLE || handleATR == INVALID_HANDLE || handleEMA == INVALID_HANDLE)
      return(INIT_FAILED);
   
   trade.SetExpertMagicNumber(InpMagicNumber);
   PrintFormat("v3.13 (超アグレッシブ) 起動 [%s]", _Symbol);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   IndicatorRelease(handleBands);
   IndicatorRelease(handleRSI);
   IndicatorRelease(handleATR);
   IndicatorRelease(handleEMA);
  }

void OnTick()
  {
   double base[], upper[], lower[], rsi[], atr[], close[], ema[];
   ArraySetAsSeries(base, true); ArraySetAsSeries(upper, true); ArraySetAsSeries(lower, true);
   ArraySetAsSeries(rsi, true); ArraySetAsSeries(atr, true); ArraySetAsSeries(close, true); ArraySetAsSeries(ema, true);
   
   if(CopyBuffer(handleBands, 0, 0, 4, base) < 4 ||
      CopyBuffer(handleBands, 1, 0, 4, upper) < 4 ||
      CopyBuffer(handleBands, 2, 0, 4, lower) < 4 ||
      CopyBuffer(handleRSI, 0, 0, 4, rsi) < 4 ||
      CopyBuffer(handleATR, 0, 0, 4, atr) < 4 ||
      CopyBuffer(handleEMA, 0, 0, 4, ema) < 4 ||
      CopyClose(_Symbol, _Period, 0, 4, close) < 4)
      return;

   bool hasPosition = PositionSelectByMagic(_Symbol, InpMagicNumber);
   
   if(hasPosition)
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      ENUM_POSITION_TYPE pType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      if(pType == POSITION_TYPE_BUY && bid >= base[0])
         trade.PositionClose(_Symbol);
      else if(pType == POSITION_TYPE_SELL && ask <= base[0])
         trade.PositionClose(_Symbol);
     }

   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(!hasPosition && lastTradeBar != currentBarTime)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      bool isTimeOK = (dt.hour >= InpStartHour && dt.hour <= InpEndHour);

      //--- v3.13 では拡大フィルタと乖離フィルタを実質無効化して手数を再優先
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double lot = CalculateLot(atr[1] * InpSLMultiplier);

      if(isTimeOK && iLow(_Symbol, _Period, 1) <= lower[1] && close[1] > lower[1] && rsi[1] <= InpRSILower && close[1] > ema[1])
        {
         double sl = ask - (atr[1] * InpSLMultiplier);
         double tp = ask + (atr[1] * InpTPMultiplier * 1.5);
         if(trade.Buy(lot, _Symbol, ask, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "BB Rev v3.13 Buy"))
            lastTradeBar = currentBarTime;
        }
      else if(isTimeOK && iHigh(_Symbol, _Period, 1) >= upper[1] && close[1] < upper[1] && rsi[1] >= InpRSIUpper && close[1] < ema[1])
        {
         double sl = bid + (atr[1] * InpSLMultiplier);
         double tp = bid - (atr[1] * InpTPMultiplier * 1.5);
         if(trade.Sell(lot, _Symbol, bid, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "BB Rev v3.13 Sell"))
            lastTradeBar = currentBarTime;
        }
     }

   Comment("--- BollingerReverse v3.13 (超アグレッシブ) ---\n",
           "リスク: ", InpRiskPercent, "% / 通信: ", _Symbol, "\n",
           "フィルタ: 極限緩和中");
  }

double CalculateLot(double slDistance)
  {
   if(!InpUseMM) return 0.1;
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(slDistance <= 0 || tickValue <= 0) return InpMinLot;
   double riskAmount = freeMargin * (InpRiskPercent / 100.0);
   double lot = riskAmount / (slDistance / tickSize * tickValue);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / stepLot) * stepLot;
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   return lot;
  }

bool PositionSelectByMagic(string symbol, long magic)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
         if(PositionGetString(POSITION_SYMBOL) == symbol && PositionGetInteger(POSITION_MAGIC) == magic)
            return true;
     }
   return false;
  }
