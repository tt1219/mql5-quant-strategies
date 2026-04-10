void OnStart()
{
   int total = SymbolsTotal(false);
   PrintFormat("Total Symbols: %d", total);
   for(int i = 0; i < total; i++)
   {
      string name = SymbolName(i, false);
      if(SymbolSelect(name, true))
         PrintFormat("Selected: %s", name);
      else
         PrintFormat("Failed to select: %s", name);
   }
}
