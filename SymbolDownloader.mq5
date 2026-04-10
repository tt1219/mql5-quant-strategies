//+------------------------------------------------------------------+
//|                                            SymbolDownloader.mq5  |
//|                                  Copyright 2026, Antigravity AI  |
//|                                                   v1.00          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("--- Starting Symbol Downloader (H1 History Sync) ---");
   EventSetTimer(1); // Set timer to start processing
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   EventKillTimer(); // Run only once
   
   int total = SymbolsTotal(false); // Get all symbols on server
   PrintFormat("Total symbols on server: %d", total);
   
   int syncedCount = 0;
   for(int i = 0; i < total; i++)
   {
      string name = SymbolName(i, false);
      
      // Select major/cross forex and metals
      if(StringFind(name, "EUR") >= 0 || StringFind(name, "USD") >= 0 || 
         StringFind(name, "JPY") >= 0 || StringFind(name, "GBP") >= 0 ||
         StringFind(name, "AUD") >= 0 || StringFind(name, "XAU") >= 0 ||
         StringFind(name, "JP") >= 0)
      {
         PrintFormat("Syncing: %s...", name);
         
         // 1. Add to MarketWatch
         if(!SymbolSelect(name, true)) continue;
         
         // 2. Request H1 Bars (triggers download)
         int bars = iBars(name, PERIOD_H1);
         
         // 3. Force check history
         datetime from = TimeCurrent() - (365 * 24 * 3600); // 1 year ago
         datetime to = TimeCurrent();
         
         // This triggers the terminal to request data from the server
         SeriesInfoInteger(name, PERIOD_H1, SERIES_BARS_COUNT);
         
         syncedCount++;
      }
      
      if(syncedCount > 50) break; // Limit to 50 for speed
   }
   
   PrintFormat("Synchronization request sent for %d symbols.", syncedCount);
   Print("--- Downloader Complete. Keep terminal open for 5 mins to finish sync ---");
   
   // Self-shutdown is not possible via MQ5 easily without closing terminal
   // We will rely on the PowerShell script to kill the terminal after 5 mins.
}
