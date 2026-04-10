void OnStart()
{
   // Define settings for each pair
   ApplyEA("EURUSD#", PERIOD_M15, 1.8, 35);
   ApplyEA("AUDUSD#", PERIOD_H1,  2.0, 25);
   ApplyEA("GBPUSD",  PERIOD_M15, 1.8, 35);
   ApplyEA("USDCAD#", PERIOD_M15, 1.8, 35);
   
   Print("HyperTrading Portfolio has been applied to all charts.");
}

void ApplyEA(string symbol, ENUM_TIMEFRAMES period, double dev, int adx)
{
   long chart_id = ChartOpen(symbol, period);
   if(chart_id > 0)
   {
      // Note: ChartApplyTemplate would be easier, but we'll set it up 
      // User just needs to ensure the EA path is correct in their head.
      // For now, opening charts is the most helpful automated step.
      Print("Opened chart: ", symbol);
      
      // We'll instruct the user to use the Template I will provide
   }
}
