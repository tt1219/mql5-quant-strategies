//+------------------------------------------------------------------+
//|                                              TradeGuard.mqh       |
//|                                  Copyright 2026, Antigravity AI |
//+------------------------------------------------------------------+
#ifndef TRADE_GUARD_MQH
#define TRADE_GUARD_MQH

class CTradeGuard
{
private:
   string   m_symbol;
   int      m_maxSpread;
   int      m_startHour;
   int      m_endHour;
   bool     m_useVol;
   double   m_volMult;

public:
   CTradeGuard() : m_symbol(_Symbol), m_maxSpread(100), m_startHour(0), m_endHour(24), m_useVol(false), m_volMult(2.0) {}

   //--- 初期化
   bool Init(string symbol, int maxSpread, int start, int end, bool useVol=false, double volMult=2.0)
   {
      m_symbol = symbol;
      m_maxSpread = maxSpread;
      m_startHour = start;
      m_endHour = end;
      m_useVol = useVol;
      m_volMult = volMult;
      return(true);
   }

   //--- 取引許可判定
   bool IsAllowed()
   {
      // 1. スプレッドチェック
      int currentSpread = (int)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
      if(m_maxSpread > 0 && currentSpread > m_maxSpread) return(false);

      // 2. 時間チェック
      MqlDateTime dt;
      TimeCurrent(dt);
      
      if(m_startHour != m_endHour)
      {
         if(m_startHour < m_endHour)
         {
            if(dt.hour < m_startHour || dt.hour >= m_endHour) return(false);
         }
         else // 日またぎ設定
         {
            if(dt.hour >= m_endHour && dt.hour < m_startHour) return(false);
         }
      }

      // 3. ボラティリティチェック (リカバリ版は簡易実装)
      // 必要に応じて ATR ハンドル等との連携を追加可能ですが、
      // 今回はインターフェースの維持と基本的防護に徹します。

      return(true);
   }

   //--- ステータスを文字列で取得
   string GetStatusString()
   {
      int spread = (int)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
      string txt = StringFormat("TradeGuard: Spread %d/%d ", spread, m_maxSpread);
      if(m_maxSpread > 0 && spread > m_maxSpread) txt += "[RESTRICTED]";
      else txt += "[OK]";
      return(txt);
   }
};

#endif
