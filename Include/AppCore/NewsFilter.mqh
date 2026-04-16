//+------------------------------------------------------------------+
//|                                              NewsFilter.mqh       |
//|                                  Copyright 2026, Antigravity AI |
//+------------------------------------------------------------------+
#ifndef NEWS_FILTER_MQH
#define NEWS_FILTER_MQH

class CNewsFilter
{
private:
   string   m_symbol;
   long     m_magic;
   bool     m_useNews;
   int      m_minBefore;
   int      m_minAfter;
   int      m_impactLimit;

public:
   CNewsFilter() : m_symbol(_Symbol), m_magic(0), m_useNews(false), m_minBefore(60), m_minAfter(60), m_impactLimit(7) {}

   //--- 初期化
   bool Init(string symbol, long magic, bool useNews, int minBefore, int minAfter, int impactLimit)
   {
      m_symbol = symbol;
      m_magic = magic;
      m_useNews = useNews;
      m_minBefore = minBefore;
      m_minAfter = minAfter;
      m_impactLimit = impactLimit;
      return(true);
   }

   //--- 取引制限判定
   bool IsRestricted()
   {
      if(!m_useNews) return(false);
      
      // リカバリ版スタブ実装
      return(false);
   }

   //--- 現在の状態を文字列で取得
   string GetStatusString()
   {
      if(!m_useNews) return("NewsFilter: DISABLED");
      return("NewsFilter: ACTIVE (Wait-and-Watch)");
   }
};

#endif
