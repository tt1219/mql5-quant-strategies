//+------------------------------------------------------------------+
//|                                                    DataAudit.mq5 |
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
   Print("--- Starting MQL5 Data Audit ---");
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   EventKillTimer();
   
   string fileName = "data_audit.csv";
   int fileHandle = FileOpen(fileName, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   
   if(fileHandle == INVALID_HANDLE)
   {
      Print("Failed to create audit file.");
      return;
   }
   
   FileWrite(fileHandle, "Symbol", "Description", "Bars_H1", "Bars_M1");
   
   int total = SymbolsTotal(false);
   for(int i = 0; i < total; i++)
   {
      string name = SymbolName(i, false);
      
      // Let's check interesting symbols
      if(StringFind(name, "EUR") >= 0 || StringFind(name, "USD") >= 0 || 
         StringFind(name, "JPY") >= 0 || StringFind(name, "GBP") >= 0 ||
         StringFind(name, "AUD") >= 0 || StringFind(name, "XAU") >= 0 ||
         StringFind(name, "JP") >= 0)
      {
         string desc = SymbolInfoString(name, SYMBOL_DESCRIPTION);
         int barsH1 = iBars(name, PERIOD_H1);
         int barsM1 = iBars(name, PERIOD_M1);
         
         FileWrite(fileHandle, name, desc, barsH1, barsM1);
      }
   }
   
   FileClose(fileHandle);
   PrintFormat("--- Data Audit Complete. Results saved to MQL5\\Files\\%s ---", fileName);
}
