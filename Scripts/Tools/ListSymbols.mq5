void OnStart()
{
   int total = SymbolsTotal(false);
   for(int i=0; i<total; i++)
   {
      Print(SymbolName(i, false));
   }
}
