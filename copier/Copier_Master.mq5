#property strict
input long MasterMagic = 10001;

// Files are stored in D:/Documents/mt5/ (two levels up from MQL5/Files)
string EVENTS_FILE = "../../copier_events.csv";
string LOCK_FILE   = "../../copier.lock";
string SEQ_FILE    = "../../copier_seq.txt";

long g_seq = 0;

// ---------- LOCK ----------
bool Lock()
{
   while(FileIsExist(LOCK_FILE))
      Sleep(5);

   int h = FileOpen(LOCK_FILE, FILE_WRITE|FILE_TXT);
   if(h == INVALID_HANDLE) return false;
   FileClose(h);
   return true;
}

void Unlock()
{
   FileDelete(LOCK_FILE);
}

// ---------- SEQ ----------
long LoadSeq()
{
   int h = FileOpen(SEQ_FILE, FILE_READ|FILE_TXT);
   if(h == INVALID_HANDLE) return 0;
   long s = (long)StringToInteger(FileReadString(h));
   FileClose(h);
   return s;
}

void SaveSeq(long s)
{
   int h = FileOpen(SEQ_FILE, FILE_WRITE|FILE_TXT);
   if(h == INVALID_HANDLE) return;
   FileWrite(h, (string)s);
   FileClose(h);
}

// ---------- WRITE EVENT ----------
void Emit(string line)
{
   if(!Lock()) return;

   int h = FileOpen(EVENTS_FILE,
      FILE_READ|FILE_WRITE|FILE_TXT|FILE_SHARE_READ);

   if(h == INVALID_HANDLE)
   {
      Unlock();
      return;
   }

   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, line + "\n");
   FileClose(h);
   Unlock();
}

// ---------- INIT ----------
int OnInit()
{
   g_seq = LoadSeq();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   SaveSeq(g_seq);
}

// ---------- EVENTS ----------
void OnTradeTransaction(const MqlTradeTransaction &t,
                        const MqlTradeRequest &r,
                        const MqlTradeResult &res)
{
   // --- SL / TP modification ---
   if(r.action == TRADE_ACTION_SLTP && res.retcode == TRADE_RETCODE_DONE)
   {
      if(r.magic != MasterMagic) return;

      g_seq++;
      Emit(
         (string)g_seq + ";MODIFY;" +
         (string)r.position + ";" +
         r.symbol + ";0;0;" +
         DoubleToString(r.sl, _Digits) + ";" +
         DoubleToString(r.tp, _Digits) + ";" +
         (string)MasterMagic + ";" +
         (string)TimeCurrent()
      );
      SaveSeq(g_seq);
      return;
   }

   // --- Deal events (OPEN / CLOSE) ---
   if(t.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(t.deal)) return;

   long dealMagic = (long)HistoryDealGetInteger(t.deal, DEAL_MAGIC);
   if(dealMagic != MasterMagic) return;

   long entry = (long)HistoryDealGetInteger(t.deal, DEAL_ENTRY);
   long dtype = (long)HistoryDealGetInteger(t.deal, DEAL_TYPE);
   long posid = (long)HistoryDealGetInteger(t.deal, DEAL_POSITION_ID);
   string sym = HistoryDealGetString(t.deal, DEAL_SYMBOL);

   if(entry == DEAL_ENTRY_IN)
   {
      // Get SL/TP and LOT from the opened position
      double sl = 0, tp = 0, lot = 0;
      if(PositionSelectByTicket(posid))
      {
         sl = PositionGetDouble(POSITION_SL);
         tp = PositionGetDouble(POSITION_TP);
         lot = PositionGetDouble(POSITION_VOLUME);
      }

      g_seq++;
      Emit(
         (string)g_seq + ";OPEN;" +
         (string)posid + ";" +
         sym + ";" +
         (dtype==DEAL_TYPE_BUY ? "BUY" : "SELL") + ";" +
         DoubleToString(lot, 2) + ";" +
         DoubleToString(sl, _Digits) + ";" +
         DoubleToString(tp, _Digits) + ";" +
         (string)MasterMagic + ";" +
         (string)TimeCurrent()
      );
      SaveSeq(g_seq);
      return;
   }

   if(entry == DEAL_ENTRY_OUT)
   {
      g_seq++;
      Emit(
         (string)g_seq + ";CLOSE;" +
         (string)posid + ";" +
         sym + ";0;0;0;0;" +
         (string)MasterMagic + ";" +
         (string)TimeCurrent()
      );
      SaveSeq(g_seq);
      return;
   }
}

