#property strict
#include <Trade/Trade.mqh>
CTrade trade;

// ---------- INPUT ----------
input string SlaveID             = "01";  // WICHTIG: Für jeden Slave ändern! (01, 02, 03, ... 10)
input long   MasterMagic         = 10001;
input long   SlaveMagic          = 20001;

input double MasterBalance       = 100000.0;  // Master Account Balance für Lot-Skalierung
input double MaxAccountDDPct     = 10.0;      // Stop trading at this DD
input int    TimerSeconds        = 1;
input int    PendingTimeoutSec   = 300;       // 5 minutes timeout for pending positions

// ---------- FILES ----------
// Files are stored in D:/Documents/mt5/ (three levels up from slave/XX/MQL5/Files)
string EVENTS_FILE;
string LOCK_FILE;
string STATE_FILE;
string MAP_FILE;

long lastSeq = 0;

void InitFiles()
{
   EVENTS_FILE = "../../../copier_events.csv";  // Gemeinsam für alle
   LOCK_FILE   = "../../../copier.lock";         // Gemeinsam für alle
   STATE_FILE  = "../../../slave_" + SlaveID + "_state.txt";  // Pro Slave
   MAP_FILE    = "../../../slave_" + SlaveID + "_map.csv";    // Pro Slave
}

// ---------- PENDING POSITIONS ----------
struct PendingPosition
{
   long masterPosId;
   string symbol;
   string side;
   double masterLot;
   datetime openTime;
   bool active;
};

PendingPosition pending[];

void AddPending(long masterPos, string sym, string orderSide, double mLot)
{
   int size = ArraySize(pending);
   ArrayResize(pending, size + 1);
   pending[size].masterPosId = masterPos;
   pending[size].symbol = sym;
   pending[size].side = orderSide;
   pending[size].masterLot = mLot;
   pending[size].openTime = TimeCurrent();
   pending[size].active = true;
   Print("PENDING: Added position ", masterPos, " | ", sym, " | ", orderSide, " | MasterLot=", mLot);
}

bool IsPending(long masterPos)
{
   for(int i = 0; i < ArraySize(pending); i++)
   {
      if(pending[i].active && pending[i].masterPosId == masterPos)
         return true;
   }
   return false;
}

bool GetPending(long masterPos, PendingPosition &pos)
{
   for(int i = 0; i < ArraySize(pending); i++)
   {
      if(pending[i].active && pending[i].masterPosId == masterPos)
      {
         pos = pending[i];
         return true;
      }
   }
   return false;
}

void RemovePending(long masterPos)
{
   for(int i = 0; i < ArraySize(pending); i++)
   {
      if(pending[i].active && pending[i].masterPosId == masterPos)
      {
         pending[i].active = false;
         Print("PENDING: Removed position ", masterPos);
         return;
      }
   }
}

void CleanupTimedOutPending()
{
   datetime now = TimeCurrent();
   for(int i = 0; i < ArraySize(pending); i++)
   {
      if(pending[i].active)
      {
         if(now - pending[i].openTime > PendingTimeoutSec)
         {
            Print("WARNING: Pending position ", pending[i].masterPosId,
                  " timed out after ", PendingTimeoutSec, " seconds - removing");
            pending[i].active = false;
         }
      }
   }
}

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

void Unlock(){ FileDelete(LOCK_FILE); }

// ---------- STATE ----------
long LoadState()
{
   int h = FileOpen(STATE_FILE, FILE_READ|FILE_TXT);
   if(h == INVALID_HANDLE) return 0;
   long s = (long)StringToInteger(FileReadString(h));
   FileClose(h);
   return s;
}

void SaveState(long s)
{
   int h = FileOpen(STATE_FILE, FILE_WRITE|FILE_TXT);
   if(h == INVALID_HANDLE) return;
   FileWrite(h, (string)s);
   FileClose(h);
}

// ---------- MAP ----------
void MapPut(long master, ulong slave)
{
   // Read existing map and update/add entry
   string map_content = "";
   bool found = false;

   int h = FileOpen(MAP_FILE, FILE_READ|FILE_TXT);
   if(h != INVALID_HANDLE)
   {
      while(!FileIsEnding(h))
      {
         string line = FileReadString(h);
         string p[];
         if(StringSplit(line, ';', p) == 2)
         {
            long m = (long)StringToInteger(p[0]);
            if(m == master)
            {
               // Update existing entry
               map_content += (string)master + ";" + (string)slave + "\n";
               found = true;
            }
            else
            {
               // Keep other entries
               map_content += line + "\n";
            }
         }
      }
      FileClose(h);
   }

   // If not found, add new entry
   if(!found)
      map_content += (string)master + ";" + (string)slave + "\n";

   // Write back
   h = FileOpen(MAP_FILE, FILE_WRITE|FILE_TXT);
   if(h != INVALID_HANDLE)
   {
      FileWriteString(h, map_content);
      FileClose(h);
   }
}

void MapDelete(long master)
{
   string map_content = "";

   int h = FileOpen(MAP_FILE, FILE_READ|FILE_TXT);
   if(h != INVALID_HANDLE)
   {
      while(!FileIsEnding(h))
      {
         string line = FileReadString(h);
         string p[];
         if(StringSplit(line, ';', p) == 2)
         {
            long m = (long)StringToInteger(p[0]);
            if(m != master)
            {
               // Keep all entries except the one we want to delete
               map_content += line + "\n";
            }
         }
      }
      FileClose(h);

      // Write back
      h = FileOpen(MAP_FILE, FILE_WRITE|FILE_TXT);
      if(h != INVALID_HANDLE)
      {
         FileWriteString(h, map_content);
         FileClose(h);
      }
   }
}

ulong MapGet(long master)
{
   int h = FileOpen(MAP_FILE, FILE_READ|FILE_TXT);
   if(h == INVALID_HANDLE) return 0;

   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      string p[];
      if(StringSplit(line,';',p)==2)
         if((long)StringToInteger(p[0])==master)
         {
            FileClose(h);
            return (ulong)StringToInteger(p[1]);
         }
   }
   FileClose(h);
   return 0;
}

// ---------- RISK ----------
double DD()
{
   double b = AccountInfoDouble(ACCOUNT_BALANCE);
   if(b <= 0) return 0;

   double e = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd = (b - e) / b * 100.0;

   return MathMax(0, dd);
}

bool IsTradingAllowed()
{
   double dd = DD();
   if(dd >= MaxAccountDDPct)
   {
      Print("WARNING: Trading stopped - DD ", DoubleToString(dd, 2), "% >= Max ", MaxAccountDDPct, "%");
      return false;
   }
   return true;
}

double ScaleLot(string sym, double masterLot)
{
   // Check if trading is allowed (DD limit)
   if(!IsTradingAllowed())
      return 0;

   double slaveBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(slaveBalance <= 0 || MasterBalance <= 0)
   {
      Print("ERROR: Invalid balance - Slave=", slaveBalance, " Master=", MasterBalance);
      return 0;
   }

   // Scale lot proportionally: SlaveLot = MasterLot * (SlaveBalance / MasterBalance)
   double lot = masterLot * (slaveBalance / MasterBalance);

   // Normalize to broker requirements
   double min = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);

   lot = MathMax(min, MathMin(max, lot));
   lot = MathFloor(lot / step) * step;

   return NormalizeDouble(lot, 2);
}

// ---------- INIT ----------
int OnInit()
{
   InitFiles();  // Initialize file paths with SlaveID
   lastSeq = LoadState();
   EventSetTimer(TimerSeconds);
   Print("Slave ", SlaveID, " initialized | State=", lastSeq);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int r)
{
   EventKillTimer();
   SaveState(lastSeq);
   Print("Slave ", SlaveID, " stopped | LastSeq=", lastSeq);
}

// ---------- EXEC ----------
void OnTimer()
{
   // Cleanup timed-out pending positions
   CleanupTimedOutPending();

   if(!Lock()) return;
   int h = FileOpen(EVENTS_FILE, FILE_READ|FILE_TXT);
   if(h==INVALID_HANDLE){ Unlock(); return; }

   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      string p[];
      if(StringSplit(line,';',p)<10) continue;

      long seq = StringToInteger(p[0]);
      if(seq<=lastSeq) continue;

      string ev=p[1];
      long mp = StringToInteger(p[2]);
      string sym=p[3];
      string side=p[4];
      double masterLot=StringToDouble(p[5]);
      double sl=StringToDouble(p[6]);
      double tp=StringToDouble(p[7]);
      long magic=StringToInteger(p[8]);

      if(magic!=MasterMagic){ lastSeq=seq; continue; }

      trade.SetExpertMagicNumber((int)SlaveMagic);

      if(ev=="OPEN")
      {
         // Don't open immediately - wait for MODIFY with SL/TP
         // Add to pending list instead with master's lot size
         AddPending(mp, sym, side, masterLot);
      }

      if(ev=="MODIFY")
      {
         // Check if this is a pending position that needs to be opened
         if(IsPending(mp))
         {
            PendingPosition pendingPos;
            if(GetPending(mp, pendingPos))
            {
               // Now we have SL/TP - scale lot size from master's lot
               double lot = ScaleLot(pendingPos.symbol, pendingPos.masterLot);

               if(lot > 0)
               {
                  bool success = false;
                  if(pendingPos.side == "BUY")
                     success = trade.Buy(lot, pendingPos.symbol, 0, sl, tp);
                  else
                     success = trade.Sell(lot, pendingPos.symbol, 0, sl, tp);

                  if(success)
                  {
                     // Get the actual position ticket from the trade result
                     ulong ticket = trade.ResultDeal();
                     if(ticket > 0)
                     {
                        // Try to get position by the deal
                        if(HistoryDealSelect(ticket))
                        {
                           ulong pos_ticket = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
                           MapPut(mp, pos_ticket);
                           Print("OPEN (from MODIFY): Mapped Master=", mp, " to Slave=", pos_ticket,
                                 " | MasterLot=", pendingPos.masterLot, " | SlaveLot=", lot, " | Symbol=", pendingPos.symbol,
                                 " | SL=", sl, " | TP=", tp);
                        }
                     }
                     RemovePending(mp);
                  }
                  else
                  {
                     Print("ERROR OPEN (from MODIFY): Failed to open position for ", pendingPos.symbol,
                           " | Master=", mp, " | Error=", GetLastError(), " | RetCode=", trade.ResultRetcode());
                  }
               }
               else
               {
                  Print("WARNING: ScaleLot returned 0 for ", pendingPos.symbol,
                        " | Master=", mp, " | MasterLot=", pendingPos.masterLot, " - DD limit reached or invalid parameters");
                  RemovePending(mp);  // Remove from pending since we can't open it
               }
            }
         }
         else
         {
            // Normal modification of existing position
            ulong t = MapGet(mp);
            if(t > 0)
            {
               if(!trade.PositionModify(t, sl, tp))
               {
                  Print("ERROR MODIFY: Failed to modify position ", t, " | Master=", mp,
                        " | Error=", GetLastError(), " | RetCode=", trade.ResultRetcode());
               }
               else
               {
                  Print("MODIFY: Position ", t, " modified | Master=", mp, " | SL=", sl, " | TP=", tp);
               }
            }
            else
            {
               Print("WARNING MODIFY: No slave position found for Master=", mp);
            }
         }
      }

      if(ev=="CLOSE")
      {
         // Check if this position is still pending (closed before SL/TP was set)
         if(IsPending(mp))
         {
            RemovePending(mp);
            Print("CLOSE: Removed pending position ", mp, " (closed before SL/TP was set)");
         }
         else
         {
            // Normal close of existing position
            ulong t = MapGet(mp);
            if(t > 0)
            {
               if(!trade.PositionClose(t))
               {
                  Print("ERROR CLOSE: Failed to close position ", t, " | Master=", mp,
                        " | Error=", GetLastError(), " | RetCode=", trade.ResultRetcode());
               }
               else
               {
                  Print("CLOSE: Position ", t, " closed | Master=", mp);
                  // Clean up the mapping after successful close
                  MapDelete(mp);
               }
            }
            else
            {
               Print("WARNING CLOSE: No slave position found for Master=", mp);
            }
         }
      }

      lastSeq=seq;
      SaveState(lastSeq);
   }

   FileClose(h);
   Unlock();
}
