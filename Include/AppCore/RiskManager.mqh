//+------------------------------------------------------------------+
//|                                             RiskManager.mqh      |
//|                                  Copyright 2026, Antigravity AI |
//+------------------------------------------------------------------+
#ifndef RISK_MANAGER_MQH
#define RISK_MANAGER_MQH

class CRiskManager
{
private:
   string   m_symbol;
   bool     m_useRisk;
   double   m_riskPercent;
   double   m_minLot;

public:
   CRiskManager() : m_symbol(_Symbol), m_useRisk(false), m_riskPercent(1.0), m_minLot(0.01) {}

   //--- 初期化
   bool Init(string symbol, bool useRisk, double percent, double minLot)
   {
      m_symbol = symbol;
      m_useRisk = useRisk;
      m_riskPercent = percent;
      m_minLot = minLot;
      return(true);
   }

   //--- ロット計算 (損切り価格距離から計算)
   double CalculateLot(double slPriceDistance)
   {
      if(!m_useRisk) return(m_minLot);
      if(slPriceDistance <= 0) return(m_minLot);

      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmt = balance * (m_riskPercent / 100.0);
      
      double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      
      if(tickValue == 0 || tickSize == 0) return(m_minLot);

      // ロット = リスク金額 / ( (損切り距離 / 最小ティックサイズ) * ティック単位利益 )
      double lot = riskAmt / ((slPriceDistance / tickSize) * tickValue);
      
      // ロットステップで補正
      double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      if(lotStep > 0)
         lot = MathFloor(lot / lotStep) * lotStep;
      
      // 最小/最大ロットの制約
      double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      double terminalMinLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      
      double finalMinLot = (m_minLot > terminalMinLot) ? m_minLot : terminalMinLot;
      
      if(lot < finalMinLot) lot = finalMinLot;
      if(lot > maxLot) lot = maxLot;
      
      return(NormalizeDouble(lot, 2));
   }

   //--- ステータスを文字列で取得
   string GetStatusString()
   {
      string txt = "RiskManager: ";
      if(!m_useRisk) txt += "Fixed Lot (" + DoubleToString(m_minLot, 2) + ")";
      else txt += "Dynamic Risk (" + DoubleToString(m_riskPercent, 1) + "%)";
      return(txt);
   }
};

#endif
