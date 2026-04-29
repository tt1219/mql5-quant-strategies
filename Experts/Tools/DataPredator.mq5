//+------------------------------------------------------------------+
//|                                           DataPredator.mq5     |
//|                                  Copyright 2024, Gemini CLI Agent |
//|        Tool to force download historical data from broker server |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gemini CLI Agent"
#property version   "1.00"
#property strict

//--- Input
input datetime InpStartDate = D'2023.01.01 00:00'; // Target Start Date

//+------------------------------------------------------------------+
int OnInit()
{
   Print("--- DataPredator: Initiating Force Sync for ", _Symbol, " ---");
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   // Request data from server by copying rates from target start date
   int copied = CopyRates(_Symbol, PERIOD_M1, 0, InpStartDate, rates);
   
   if(copied > 0) {
      Print("SUCCESS: Requested data from ", TimeToString(InpStartDate), ". Copied bars: ", copied);
      Print("First Bar Date: ", TimeToString(rates[copied-1].time));
   } else {
      Print("FAILED: Could not fetch data. Error: ", GetLastError());
   }
   
   return(INIT_FAILED); // Exit immediately after sync attempt
}
