void OnStart()
{
   int total = SymbolsTotal(false);
   Print("--- MARKET WATCH SYMBOLS ---");
   for(int i=0; i<total; i++)
   {
      string name = SymbolName(i, false);
      if(StringFind(name, "EURUSD") >= 0 || StringFind(name, "AUDUSD") >= 0)
      {
         Print("FOUND: ", name);
      }
   }
   Print("----------------------------");
}
