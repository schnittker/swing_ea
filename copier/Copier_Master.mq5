#property strict
input long MasterMagic = 10001;

string EVENTS_FILE = "copier_events.csv";
string LOCK_FILE   = "copier.lock";
string SEQ_FILE    = "copier_seq.txt";

long g_seq = 0;

// ---------- LOCK ----------
bool Lock()
{
   while(FileIsExist(LOCK_FILE, FILE_COMMON))
      Sleep(5);

   int h = FileOpen(LOCK_FILE, FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(h == INVALID_HANDLE) return false;
   FileClose(h);
   return true;
}

void Unlock()
{
   FileDelete(LOCK_FILE, FILE_COMMON);
}

// ---------- SEQ ----------
long LoadSeq()
{
   int h = FileOpen(SEQ_FILE, FILE_READ|FILE_TXT|FILE_COMMON);
   if(h == INVALID_HANDLE) return 0;
   long s = (long)StringToInteger(FileReadString(h));
   FileClose(h);
   return s;
}

void SaveSeq(long s)
{
   int h = FileOpen(SEQ_FILE, FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(h == INVALID_HANDLE) return;
   FileWrite(h, (string)s);
   FileClose(h);
}

// ---------- WRITE EVENT ----------
void Emit(string line)
{
   if(!Lock()) return;

   int h = FileOpen(EVENTS_FILE,
      FILE_READ|FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_SHARE_READ);

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
   if(t.magic != MasterMagic && r.magic != MasterMagic) return;

   // SL / TP change
   if(r.action == TRADE_ACTION_SLTP && res.retcode == TRADE_RETCODE_DONE)
   {
      g_seq++;
      Emit(StringFormat(
         "%d;MODIFY;%d;%s;0;0;%.5f;%.5f;%d;%d",
         g_seq,
         r.position,
         r.symbol,
         r.sl,
         r.tp,
         MasterMagic,
         TimeCurrent()
      ));
      SaveSeq(g_seq);
      return;
   }

   if(t.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(t.deal)) return;

   long entry = HistoryDealGetInteger(t.deal, DEAL_ENTRY);
   long type  = HistoryDealGetInteger(t.deal, DEAL_TYPE);
   long posid = HistoryDealGetInteger(t.deal, DEAL_POSITION_ID);
   string sym = HistoryDealGetString(t.deal, DEAL_SYMBOL);

   // OPEN
   if(entry == DEAL_ENTRY_IN)
   {
      g_seq++;
      Emit(StringFormat(
         "%d;OPEN;%d;%s;%s;0;0;0;%d;%d",
         g_seq,
         posid,
         sym,
         type==DEAL_TYPE_BUY?"BUY":"SELL",
         MasterMagic,
         TimeCurrent()
      ));
      SaveSeq(g_seq);
   }

   // CLOSE
   if(entry == DEAL_ENTRY_OUT)
   {
      g_seq++;
      Emit(StringFormat(
         "%d;CLOSE;%d;%s;0;0;0;0;%d;%d",
         g_seq,
         posid,
         sym,
         MasterMagic,
         TimeCurrent()
      ));
      SaveSeq(g_seq);
   }
}
