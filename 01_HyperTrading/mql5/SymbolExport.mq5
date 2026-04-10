void OnStart()
{
   int file_handle = FileOpen("symbol_list.txt", FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(file_handle != INVALID_HANDLE)
   {
      int total = SymbolsTotal(false);
      for(int i=0; i<total; i++)
      {
         string name = SymbolName(i, false);
         FileWrite(file_handle, name);
      }
      FileClose(file_handle);
   }
}
