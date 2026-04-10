void OnStart()
{
   string acc_curr = AccountInfoString(ACCOUNT_CURRENCY);
   double acc_bal = AccountInfoDouble(ACCOUNT_BALANCE);
   long acc_lev = AccountInfoInteger(ACCOUNT_LEVERAGE);
   
   int file_handle = FileOpen("account_diagnostic.txt", FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(file_handle != INVALID_HANDLE)
   {
      FileWrite(file_handle, "ACCOUNT_CURRENCY: " + acc_curr);
      FileWrite(file_handle, "ACCOUNT_BALANCE: " + DoubleToString(acc_bal, 2));
      FileWrite(file_handle, "ACCOUNT_LEVERAGE: " + IntegerToString(acc_lev));
      
      int total = SymbolsTotal(false);
      FileWrite(file_handle, "--- SYMBOLS ---");
      for(int i=0; i<total; i++)
      {
         string name = SymbolName(i, false);
         if(StringFind(name, "EURUSD") >= 0 || StringFind(name, "USDJPY") >= 0)
            FileWrite(file_handle, name);
      }
      FileClose(file_handle);
   }
}
