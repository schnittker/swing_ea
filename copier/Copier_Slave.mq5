#property strict
#include <Trade/Trade.mqh>
CTrade trade;

// ---------- INPUT ----------
input long   MasterMagic = 10001;
input long   SlaveMagic  = 20001;

input double BaseLotPer10k       = 0.10;
input double MaxRiskPerTradePct = 1.0;
input double SoftDDStartPct     = 5.0;
input double MaxAccountDDPct    = 10.0;
input int    TimerSeconds       = 1;

// ---------- FILES ----------
string EVENTS_FILE = "copier_events.csv";
string LOCK_FILE   = "copier.lock";
string STATE_FILE  = "slave_state.txt";
string MAP_FILE    = "slave_map.csv";

long lastSeq = 0;

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

void Unlock(){ FileDelete(LOCK_FILE, FILE_COMMON); }

// ---------- STATE ----------
long LoadState()
{
   int h = FileOpen(STATE_FILE, FILE_READ|FILE_TXT|FILE_COMMON);
   if(h == INVALID_HANDLE) return 0;
   long s = (long)StringToInteger(FileReadString(h));
   FileClose(h);
   return s;
}

void SaveState(long s)
{
   int h = FileOpen(STATE_FILE, FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(h == INVALID_HANDLE) return;
   FileWrite(h, (string)s);
   FileClose(h);
}

// ---------- MAP ----------
void MapPut(long master, ulong slave)
{
   int h = FileOpen(MAP_FILE, FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_READ);
   if(h == INVALID_HANDLE)
      h = FileOpen(MAP_FILE, FILE_WRITE|FILE_TXT|FILE_COMMON);

   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, (string)master+";"+(string)slave+"\n");
   FileClose(h);
}

ulong MapGet(long master)
{
   int h = FileOpen(MAP_FILE, FILE_READ|FILE_TXT|FILE_COMMON);
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
   double b=AccountInfoDouble(ACCOUNT_BALANCE);
   double e=AccountInfoDouble(ACCOUNT_EQUITY);
   return (b-e)/b*100.0;
}

double RiskFactor()
{
   double dd=DD();
   if(dd>=MaxAccountDDPct) return 0;
   if(dd<=SoftDDStartPct) return 1;
   return MathMax(0.2,
      1-(dd-SoftDDStartPct)/(MaxAccountDDPct-SoftDDStartPct));
}

double CalcLot(string sym)
{
   double rf = RiskFactor();
   if(rf<=0) return 0;
   double lot = BaseLotPer10k*(AccountInfoDouble(ACCOUNT_BALANCE)/10000.0)*rf;
   double min=SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN);
   double max=SymbolInfoDouble(sym,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP);
   lot=MathMax(min,MathMin(max,lot));
   lot=MathFloor(lot/step)*step;
   return NormalizeDouble(lot,2);
}

// ---------- INIT ----------
int OnInit()
{
   lastSeq = LoadState();
   EventSetTimer(TimerSeconds);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int r)
{
   EventKillTimer();
   SaveState(lastSeq);
}

// ---------- EXEC ----------
void OnTimer()
{
   if(!Lock()) return;
   int h = FileOpen(EVENTS_FILE, FILE_READ|FILE_TXT|FILE_COMMON);
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
      double sl=StringToDouble(p[6]);
      double tp=StringToDouble(p[7]);
      long magic=StringToInteger(p[8]);

      if(magic!=MasterMagic){ lastSeq=seq; continue; }

      trade.SetExpertMagicNumber((int)SlaveMagic);

      if(ev=="OPEN")
      {
         double lot=CalcLot(sym);
         if(lot>0)
         {
            if(side=="BUY") trade.Buy(lot,sym);
            else trade.Sell(lot,sym);

            ulong t=PositionGetTicket(PositionsTotal()-1);
            MapPut(mp,t);
         }
      }

      if(ev=="MODIFY")
      {
         ulong t=MapGet(mp);
         if(t>0) trade.PositionModify(t,sl,tp);
      }

      if(ev=="CLOSE")
      {
         ulong t=MapGet(mp);
         if(t>0) trade.PositionClose(t);
      }

      lastSeq=seq;
      SaveState(lastSeq);
   }

   FileClose(h);
   Unlock();
}
