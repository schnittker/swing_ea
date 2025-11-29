# MQL5 Expert Advisor - Vollständige Spezifikation
## 4H Swing Trading EA mit Multi-Symbol-Management

---

## 1. PROJEKT-ÜBERSICHT

### 1.1 Zielsetzung
Automatisierung einer profitablen 4H-Swing-Trading-Strategie auf 25 Forex-Paaren + Gold, mit Quality-Scoring, Position-Limiting und dynamischem Risk-Management.

### 1.2 Trading-Umgebung
- **Broker:** Pepperstone MT5 (Master-Account)
- **Timeframe:** H4 (4-Stunden)
- **Symbole:** 25 Forex-Paare + XAUUSD
- **Trade-Replication:** FXBlue Copier zu 8 Prop Firm Accounts
- **Execution:** Timer-basiert (4× täglich nach Candle-Close)

### 1.3 Key-Features
- Multi-Symbol-Scanning (25+ Symbole parallel)
- State-Machine für Trade-Lifecycle
- Quality-Scoring für Setup-Auswahl
- Max. 2 gleichzeitige Positionen
- Trailing-Drawdown-basiertes Risk-Management
- Fibonacci-basierte Entry/Exit-Logik
- ATR-basiertes Stop-Loss-Management

---

## 2. TRADING-STRATEGIE

### 2.1 Trend-Filter (EMA200)

**Long-Setup:**
- Preis ÜBER EMA200(H4)
- EMA200 steigt (EMA200[0] > EMA200[5])
- Preis-Distanz zu EMA200 >= 1.0 × ATR(14)

**Short-Setup:**
- Preis UNTER EMA200(H4)
- EMA200 fällt (EMA200[0] < EMA200[5])
- Preis-Distanz zu EMA200 >= 1.0 × ATR(14)

**No-Trade:**
- EMA200 flach (Änderung < 0.0001 × Symbol-Point)
- Preis zu nah am EMA200 (< 1.0 × ATR)

---

### 2.2 Swing-Detection (Higher Highs / Lower Lows)

**Swing High (retrospektiv, 1 Candle Delay):**
```
High[i] > High[i-1] &&
High[i] > High[i+1] &&
High[i] >= High[i-2] &&
High[i] >= High[i+2] &&
(High[i] - letzter_SwingHigh) > 0.5 × ATR(14)
```

**Erkennungs-Zeitpunkt:**
- Nach Close von Candle i+1 (4 Stunden nach potenziellem Swing)

**Swing Low (analog):**
```
Low[i] < Low[i-1] &&
Low[i] < Low[i+1] &&
Low[i] <= Low[i-2] &&
Low[i] <= Low[i+2] &&
(letzter_SwingLow - Low[i]) > 0.5 × ATR(14)
```

**Swing-Invalidierung:**
- Wenn neuer, höherer/niedrigerer Swing entsteht → alte Fibos werden ungültig
- Bestehende offene Positionen bleiben unberührt

---

### 2.3 Fibonacci-Retracements

**Long-Setup:**
- Von: Letzter Swing Low
- Zu: Letzter Swing High (nach HH)
- Levels: 38.2%, 50%, 61.8%

**Entry-Zone:**
- Preis retraced in Bereich 50% - 61.8%
- Toleranz: ± 0.1 × ATR(14)

**Fibonacci-Update:**
- Sobald neuer Swing bestätigt wird
- Alte Fibos werden ungültig (aber offene Trades bleiben)

---

### 2.4 Entry-Trigger (Candlestick-Patterns)

#### Option A: Rejection Candle (Pinbar)

**Bullish Rejection (für Long):**
```
LowerWick >= 1.8 × Body
UpperWick <= 0.3 × CandleHeight
Close > Open
Close >= Low + 0.67 × CandleHeight
Low im Bereich Fibo-Level ± 0.1 × ATR
```

**Berechnungen:**
```
Body = abs(Close - Open)
LowerWick = min(Open, Close) - Low
UpperWick = High - max(Open, Close)
CandleHeight = High - Low
```

**Bearish Rejection (für Short):**
- Spiegelverkehrt

#### Option B: Engulfing Candle

**Bullish Engulfing:**
```
Close[i] > Open[i]
Close[i-1] < Open[i-1]
(Close[i] - Open[i]) > 1.2 × abs(Close[i-1] - Open[i-1])
Open[i] <= Close[i-1]
Close[i] >= Open[i-1]
Open[i] im Bereich Fibo-Level ± 0.1 × ATR
```

**Entry-Timing:**
- Sofort beim Close der Rejection/Engulfing-Candle (kein Warten auf Breakout-Bestätigung)

---

### 2.5 Stop-Loss (ATR-basiert)

**Standard:**
```
SL_Distance = 1.5 × ATR(14)
```

**Long:**
```
SL = Entry - SL_Distance
```

**Short:**
```
SL = Entry + SL_Distance
```

**Validierung:**
- SL muss unter/über letzter Swing-Struktur liegen
- Minimum SL-Distance: 10 Pips (um zu enge Stops zu vermeiden)

---

### 2.6 Take-Profits (Fibonacci-Extensions)

**Berechnung:**
```
Swing_Range = abs(SwingHigh - SwingLow)
```

**Long:**
```
TP1 = SwingHigh + 1.000 × Swing_Range
TP2 = SwingHigh + 1.272 × Swing_Range
TP3 = SwingHigh + 1.618 × Swing_Range
```

**Short:**
```
TP1 = SwingLow - 1.000 × Swing_Range
TP2 = SwingLow - 1.272 × Swing_Range
TP3 = SwingLow - 1.618 × Swing_Range
```

**Initiale Order:**
- Wird mit TP1 eröffnet

---

### 2.7 Trade-Management

**Bei TP1 erreicht:**
1. 50% der Position schließen
2. Stop-Loss auf Break-Even verschieben (Entry-Preis)
3. Rest läuft mit BE-Stop weiter (Ziel: TP2/TP3)

**Trailing-Stop:**
- NICHT implementiert (nur BE-Shift bei TP1)

**Position-Modification:**
- SL-Verschiebung nur nach oben (Long) / unten (Short)
- Kein nachträgliches Erweitern der Position

---

## 3. MULTI-SYMBOL MANAGEMENT

### 3.1 Symbol-Liste (25 Symbole)

```cpp
string symbols[] = {
   "EURJPY", "XAUUSD", "GBPJPY", "NZDJPY", "EURCAD",
   "EURCHF", "GBPCHF", "USDCAD", "AUDUSD", "USDCHF",
   "GBPNZD", "CADJPY", "AUDNZD", "NZDUSD", "GBPUSD",
   "EURNZD", "AUDCAD", "GBPCAD", "EURUSD", "USDJPY",
   "AUDJPY", "CHFJPY", "CADCHF", "GBPAUD", "EURAUD"
};
```

**Symbol-Properties zu berücksichtigen:**
- Symbol-Point
- Symbol-Digits
- Min/Max Lot-Size
- Lot-Step
- Tick-Value
- Tick-Size

---

### 3.2 State Machine (pro Symbol)

**States:**
```cpp
enum TradingState {
   STATE_NO_TRADE,      // 🔴 ROT: EMA zu nah, kein Trend, etc.
   STATE_TREND_FORMING, // 🟡 GELB: Swing erkannt, Trend vorhanden
   STATE_RETRACEMENT,   // 🟢 GRÜN: Preis retraced Richtung Fibo
   STATE_AT_FIB,        // 🔵 BLAU: Preis bei Fib 50-61.8%, warte auf Entry-Candle
   STATE_TRADE_TAKEN    // 🟣 VIOLETT: Trade aktiv (Position offen)
};
```

**State-Transitions:**
```
NO_TRADE → TREND_FORMING: Swing High/Low erkannt + EMA-Filter OK
TREND_FORMING → RETRACEMENT: Preis bewegt sich Richtung Fibo
RETRACEMENT → AT_FIB: Preis erreicht 50-61.8% Zone
AT_FIB → TRADE_TAKEN: Entry-Candle (Rejection/Engulfing) erscheint
TRADE_TAKEN → NO_TRADE: Position geschlossen
ANY → NO_TRADE: Setup invalidiert (neuer Swing, EMA-Break, etc.)
```

**Struct für Symbol-State:**
```cpp
struct SymbolState {
   string symbol;
   TradingState state;
   double lastSwingHigh;
   double lastSwingLow;
   int swingHighBar;
   int swingLowBar;
   double fib382;
   double fib500;
   double fib618;
   double qualityScore;
   datetime lastUpdate;
   bool isLongSetup; // true = Long, false = Short
};
```

---

### 3.3 Quality-Scoring System

**Scoring-Komponenten (max. 100 Punkte):**

#### 1. Multi-Timeframe-Alignment (0-30 Punkte)

**1D-Trend-Check:**
```cpp
// Für Long-Setup:
if (Price_1D < EMA200_1D && EMA200_1D_Falling) {
   return 0; // Hard Reject (1D ist dagegen)
}

if (Price_1D > EMA200_1D && EMA200_1D_Rising) {
   score += 30; // Perfect Alignment
} else {
   score += 15; // Neutral (1D nicht dagegen, aber auch nicht aligned)
}
```

#### 2. EMA200-Distanz (0-20 Punkte)

```cpp
double distance_in_ATR = abs(Price - EMA200) / ATR(14);

if (distance_in_ATR < 1.0) return 0; // Hard Reject

if (distance_in_ATR >= 2.0) score += 20;
else if (distance_in_ATR >= 1.5) score += 15;
else score += 10;
```

#### 3. Fibonacci-Level-Präzision (0-20 Punkte)

```cpp
// Wie nah ist Preis am idealen 61.8% Level?
double targetLevel = fib618;
double currentPrice = Close[0];
double distanceToIdeal = abs(currentPrice - targetLevel) / ATR(14);

if (distanceToIdeal <= 0.05) score += 20; // Sehr präzise
else if (distanceToIdeal <= 0.1) score += 15;
else if (distanceToIdeal <= 0.15) score += 10;
else score += 5;
```

#### 4. Candlestick-Pattern-Qualität (0-20 Punkte)

```cpp
// Rejection Candle
double wickRatio = LowerWick / Body;
double wickToHeight = LowerWick / CandleHeight;

if (wickRatio >= 2.5) score += 20; // Perfect Rejection
else if (wickRatio >= 2.0) score += 15;
else if (wickRatio >= 1.8) score += 10;

// Engulfing
double engulfSize = (Close[0] - Open[0]) / (Close[1] - Open[1]);

if (engulfSize >= 1.5) score += 20; // Strong Engulfing
else if (engulfSize >= 1.2) score += 15;
else score += 10;
```

#### 5. Swing-Struktur-Qualität (0-10 Punkte)

```cpp
// Clean HH/LL ohne viele Mini-Swings dazwischen
int noisySwings = CountMiniSwingsBetween(swingLowBar, swingHighBar);

if (noisySwings == 0) score += 10; // Perfect Structure
else if (noisySwings <= 1) score += 7;
else if (noisySwings <= 2) score += 4;
else score += 0; // Too noisy
```

**Gesamt-Score:**
```
Max. 100 Punkte = Perfect Setup
Min. 0 Punkte = Rejected Setup
```

**Schwellenwert für Trade:**
```
Score >= 50: Setup wird betrachtet
Score < 50: Setup wird ignoriert
```

---

### 3.4 Setup-Auswahl (Top-2)

**Prozess:**
1. Alle 25 Symbole scannen
2. Für jedes Symbol im State `AT_FIB`: Quality-Score berechnen
3. Setups nach Score sortieren (höchste zuerst)
4. Top-2-Setups auswählen
5. Wenn weniger als 2 offene Positionen → Trade(s) öffnen

**Correlation-Management:**
- NICHT implementiert (wurde explizit verzichtet)
- EA nimmt die besten 2 Setups, unabhängig von Währungs-Korrelation

**Max-Position-Limit:**
- Maximal 2 offene Positionen gleichzeitig (über alle 25 Symbole)

---

## 4. RISK-MANAGEMENT

### 4.1 Trailing-Drawdown-Modell

**Drawdown-Berechnung:**
```cpp
double equityPeak = GlobalVariableGet("EA_EquityPeak");
double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

if (currentEquity > equityPeak) {
   equityPeak = currentEquity;
   GlobalVariableSet("EA_EquityPeak", equityPeak);
}

double drawdown = ((equityPeak - currentEquity) / equityPeak) * 100.0;
```

**Risk-Anpassung:**
```cpp
double riskPercent;

if (drawdown >= 4.0) {
   riskPercent = 0.25; // Letzte Stufe vor Stopp
}
else if (drawdown >= 3.0) {
   riskPercent = 0.5;
}
else {
   riskPercent = 1.0; // Normal
}
```

**Emergency-Stop:**
```cpp
if (drawdown >= 4.0) {
   Comment("MAX DRAWDOWN REACHED (4.0%) - EA STOPPED");
   CloseAllPositions();
   ExpertRemove(); // EA deaktivieren
}
```

**Peak-Reset:**
- Nur wenn neue Equity > alter Peak
- Gespeichert in GlobalVariable (überlebt EA-Restart)

---

### 4.2 Position-Sizing (Dynamic Lot Calculation)

**Formel:**
```cpp
double balance = AccountInfoDouble(ACCOUNT_BALANCE);
double riskAmount = balance * (riskPercent / 100.0);

double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

double slDistanceInPrice = slDistance * point;
double slDistanceInTicks = slDistanceInPrice / tickSize;

double lotSize = riskAmount / (slDistanceInTicks * tickValue);
```

**Normalisierung:**
```cpp
double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

lotSize = MathMax(minLot, lotSize);
lotSize = MathMin(maxLot, lotSize);
lotSize = NormalizeDouble(MathFloor(lotSize / lotStep) * lotStep, 2);
```

**Sicherheits-Check:**
```cpp
if (lotSize < minLot || lotSize > maxLot) {
   Print("ERROR: Invalid lot size: ", lotSize);
   return 0; // Kein Trade
}
```

---

### 4.3 Max-Loss-Limits

**Daily Loss Limit:**
- NICHT implementiert (da Swing-Trading über mehrere Tage)

**Max Drawdown:**
- 4.0% (Hard-Stop, EA deaktiviert sich selbst)

**Max Open Positions:**
- 2 gleichzeitig (über alle Symbole)

---

## 5. EXECUTION & TIMING

### 5.1 Timer-basierte Execution

**OnTimer() statt OnTick():**
```cpp
int OnInit() {
   EventSetTimer(900); // 15 Minuten
   return INIT_SUCCEEDED;
}

void OnTimer() {
   if (!IsInTradingWindow()) return;

   ScanAllSymbols();
   UpdateStates();
   SelectBestSetups();
   ExecuteTrades();
   ManageOpenPositions();
   UpdateTrailingDD();
}
```

**Vorteil:**
- Kein Tick-by-Tick-Processing (Performance)
- Nur zu relevanten Zeiten aktiv

---

### 5.2 Trading-Zeitfenster

**EA scannt nur 4× täglich (nach 4H-Candle-Close):**

```cpp
bool IsInTradingWindow() {
   datetime serverTime = TimeCurrent();
   int hour = TimeHour(serverTime);
   int minute = TimeMinute(serverTime);

   // 06:45 - 07:00 (nach 04:00 Candle)
   if (hour == 6 && minute >= 45) return true;
   if (hour == 7 && minute == 0) return true;

   // 10:45 - 11:00 (nach 08:00 Candle)
   if (hour == 10 && minute >= 45) return true;
   if (hour == 11 && minute == 0) return true;

   // 14:45 - 15:00 (nach 12:00 Candle)
   if (hour == 14 && minute >= 45) return true;
   if (hour == 15 && minute == 0) return true;

   // 18:45 - 19:00 (nach 16:00 Candle)
   if (hour == 18 && minute >= 45) return true;
   if (hour == 19 && minute == 0) return true;

   return false;
}
```

**Timezone:**
- Broker Server Time (Pepperstone = GMT+2/GMT+3)

**Candle-Close-Check:**
```cpp
bool IsNewBar() {
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_H4, 0);

   if (currentBarTime != lastBarTime) {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}
```

---

### 5.3 Order-Execution

**Trade-Class:**
```cpp
#include <Trade\Trade.mqh>
CTrade trade;
```

**Buy-Order:**
```cpp
bool success = trade.Buy(
   lotSize,           // Volume
   symbol,            // Symbol
   0,                 // Price (0 = Market)
   sl,                // Stop-Loss
   tp1,               // Take-Profit (initial TP1)
   "SwingEA_v1"       // Comment
);

if (!success) {
   Print("BUY FAILED: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
}
```

**Sell-Order:**
```cpp
bool success = trade.Sell(lotSize, symbol, 0, sl, tp1, "SwingEA_v1");
```

**Error-Handling:**
```cpp
int retcode = trade.ResultRetcode();

switch(retcode) {
   case TRADE_RETCODE_DONE:
   case TRADE_RETCODE_PLACED:
      Print("Trade executed successfully");
      break;

   case TRADE_RETCODE_REQUOTE:
      Print("Requote - retry");
      // Optional: Retry-Logik
      break;

   case TRADE_RETCODE_REJECT:
      Print("Order rejected by broker");
      break;

   case TRADE_RETCODE_INVALID_STOPS:
      Print("Invalid SL/TP levels");
      break;

   default:
      Print("Unknown error: ", retcode);
}
```

---

## 6. TRADE MANAGEMENT

### 6.1 Partial-Close bei TP1

**Erkennung:**
```cpp
for (int i = PositionsTotal() - 1; i >= 0; i--) {
   ulong ticket = PositionGetTicket(i);
   if (ticket == 0) continue;

   if (PositionGetString(POSITION_COMMENT) != "SwingEA_v1") continue;

   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double tp = PositionGetDouble(POSITION_TP);

   bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

   // TP1 erreicht?
   if (isLong && currentPrice >= tp) {
      ClosePartial(ticket, 0.5);
      MoveToBreakEven(ticket);
   }
   else if (!isLong && currentPrice <= tp) {
      ClosePartial(ticket, 0.5);
      MoveToBreakEven(ticket);
   }
}
```

**Partial-Close-Funktion:**
```cpp
void ClosePartial(ulong ticket, double percent) {
   if (!PositionSelectByTicket(ticket)) return;

   double currentVolume = PositionGetDouble(POSITION_VOLUME);
   double closeVolume = NormalizeDouble(currentVolume * percent, 2);

   string symbol = PositionGetString(POSITION_SYMBOL);

   trade.PositionClosePartial(ticket, closeVolume);

   if (trade.ResultRetcode() == TRADE_RETCODE_DONE) {
      Print("Partial close successful: ", closeVolume, " lots");
   }
}
```

---

### 6.2 Break-Even-Shift

**Funktion:**
```cpp
void MoveToBreakEven(ulong ticket) {
   if (!PositionSelectByTicket(ticket)) return;

   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);

   bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

   // Nur verschieben wenn SL noch nicht auf BE
   if (isLong && currentSL < openPrice) {
      trade.PositionModify(ticket, openPrice, PositionGetDouble(POSITION_TP));
      Print("SL moved to Break-Even: ", openPrice);
   }
   else if (!isLong && currentSL > openPrice) {
      trade.PositionModify(ticket, openPrice, PositionGetDouble(POSITION_TP));
      Print("SL moved to Break-Even: ", openPrice);
   }
}
```

**Wichtig:**
- Nur NACH Partial-Close bei TP1
- Nur EINMAL pro Position (Flag setzen)

---

### 6.3 Position-Tracking

**Global Variables für Tracking:**
```cpp
// Speichert ob Position bereits BE-Shift hatte
GlobalVariableSet("EA_TP1_" + IntegerToString(ticket), 1);

// Beim Check:
if (GlobalVariableCheck("EA_TP1_" + IntegerToString(ticket))) {
   // TP1 wurde bereits behandelt, skip
   continue;
}
```

---

## 7. LOGGING & MONITORING

### 7.1 Log-Levels

**Print-Statements:**
```cpp
// INFO
Print("[INFO] Symbol: ", symbol, " | State: ", EnumToString(state));

// WARNING
Print("[WARNING] EMA too close: ", distance_in_ATR, " ATR");

// ERROR
Print("[ERROR] Trade failed: ", trade.ResultRetcodeDescription());

// DEBUG (nur für Development, später auskommentieren)
Print("[DEBUG] Quality Score: ", score);
```

---

### 7.2 Chart-Comment (Dashboard)

**OnTimer() Update:**
```cpp
void UpdateDashboard() {
   string dashboard = "\n";
   dashboard += "=== SWING EA v1.0 ===\n";
   dashboard += "Account: " + AccountInfoString(ACCOUNT_NAME) + "\n";
   dashboard += "Equity: " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\n";
   dashboard += "Peak: " + DoubleToString(equityPeak, 2) + "\n";
   dashboard += "Drawdown: " + DoubleToString(currentDD, 2) + "%\n";
   dashboard += "Risk: " + DoubleToString(currentRisk, 2) + "%\n";
   dashboard += "Open Positions: " + IntegerToString(PositionsTotal()) + " / 2\n";
   dashboard += "\n--- Top Setups ---\n";

   for (int i = 0; i < 5; i++) {
      if (symbolStates[i].qualityScore > 50) {
         dashboard += symbolStates[i].symbol + ": " +
                      DoubleToString(symbolStates[i].qualityScore, 0) + " | " +
                      EnumToString(symbolStates[i].state) + "\n";
      }
   }

   Comment(dashboard);
}
```

---

### 7.3 File-Logging (Optional)

**Trade-Journal:**
```cpp
void LogTrade(string symbol, bool isLong, double entry, double sl, double tp, double lotSize, double score) {
   int handle = FileOpen("SwingEA_Journal.csv", FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ',');

   if (handle != INVALID_HANDLE) {
      FileSeek(handle, 0, SEEK_END);

      string line = TimeToString(TimeCurrent()) + "," +
                    symbol + "," +
                    (isLong ? "LONG" : "SHORT") + "," +
                    DoubleToString(entry, 5) + "," +
                    DoubleToString(sl, 5) + "," +
                    DoubleToString(tp, 5) + "," +
                    DoubleToString(lotSize, 2) + "," +
                    DoubleToString(score, 0);

      FileWriteString(handle, line + "\n");
      FileClose(handle);
   }
}
```

---

## 8. ERROR-HANDLING & ROBUSTNESS

### 8.1 Indicator-Handle-Management

**Init:**
```cpp
int emaHandle, atrHandle;

int OnInit() {
   emaHandle = iMA(_Symbol, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, PERIOD_H4, 14);

   if (emaHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE) {
      Print("ERROR: Failed to create indicators");
      return INIT_FAILED;
   }

   return INIT_SUCCEEDED;
}
```

**Deinit:**
```cpp
void OnDeinit(const int reason) {
   IndicatorRelease(emaHandle);
   IndicatorRelease(atrHandle);
   EventKillTimer();
}
```

**Multi-Symbol-Handles:**
- Für jedes Symbol separate Handles erstellen
- Array-basiertes Management

---

### 8.2 Restart-Safety

**Problem:**
- EA startet neu (VPS-Restart, MT5-Crash, etc.)
- Offene Positionen müssen wiedererkannt werden

**Lösung:**
```cpp
int OnInit() {
   // Offene Positionen scannen
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      string comment = PositionGetString(POSITION_COMMENT);

      if (comment == "SwingEA_v1") {
         string symbol = PositionGetString(POSITION_SYMBOL);

         // State auf TRADE_TAKEN setzen
         for (int j = 0; j < ArraySize(symbolStates); j++) {
            if (symbolStates[j].symbol == symbol) {
               symbolStates[j].state = STATE_TRADE_TAKEN;
               break;
            }
         }
      }
   }

   return INIT_SUCCEEDED;
}
```

---

### 8.3 Symbol-Validation

**Check ob Symbol verfügbar:**
```cpp
bool IsSymbolValid(string symbol) {
   if (!SymbolSelect(symbol, true)) {
      Print("ERROR: Symbol not available: ", symbol);
      return false;
   }

   if (SymbolInfoDouble(symbol, SYMBOL_BID) == 0) {
      Print("ERROR: No quotes for symbol: ", symbol);
      return false;
   }

   return true;
}
```

---

## 9. INPUT-PARAMETER

### 9.1 User-Inputs

```cpp
//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

// --- Risk Management ---
input double RiskPercent_Normal = 1.0;      // Risk % (Normal, DD < 3%)
input double RiskPercent_Medium = 0.5;      // Risk % (Medium, DD 3-4%)
input double RiskPercent_High = 0.25;       // Risk % (High, DD > 4%)
input double MaxDrawdownPercent = 4.0;      // Max Drawdown % (Stop EA)

// --- Strategy Parameters ---
input int EMA_Period = 200;                 // EMA Period
input int ATR_Period = 14;                  // ATR Period
input double ATR_SL_Multiplier = 1.5;       // ATR SL Multiplier
input double MinEMADistance_ATR = 1.0;      // Min EMA Distance (× ATR)

// --- Fibonacci Levels ---
input double Fib_Level1 = 38.2;             // Fib Level 1 (%)
input double Fib_Level2 = 50.0;             // Fib Level 2 (%)
input double Fib_Level3 = 61.8;             // Fib Level 3 (%)
input double Fib_Tolerance_ATR = 0.1;       // Fib Tolerance (× ATR)

// --- Position Management ---
input int MaxOpenPositions = 2;             // Max Open Positions
input double PartialClosePercent = 50.0;    // Partial Close at TP1 (%)

// --- Quality Scoring ---
input double MinQualityScore = 50.0;        // Min Quality Score (0-100)

// --- Swing Detection ---
input double MinSwingDistance_ATR = 0.5;    // Min Swing Distance (× ATR)

// --- Multi-Timeframe ---
input bool Use1D_Filter = true;             // Use 1D Trend Filter

// --- Timing ---
input bool TradeOnlyInWindows = true;       // Trade only in 4 time windows

// --- Logging ---
input bool EnableFileLogging = false;       // Enable CSV Journal
input bool ShowDashboard = true;            // Show Dashboard on Chart
```

---

## 10. CODE-STRUKTUR

### 10.1 Datei-Organisation

```
SwingEA_v1.mq5              // Main EA File
├── Include Files:
│   ├── SymbolManager.mqh   // Multi-Symbol-Handling
│   ├── StateManager.mqh    // State-Machine-Logik
│   ├── QualityScorer.mqh   // Quality-Scoring
│   ├── RiskManager.mqh     // Risk & Position-Sizing
│   ├── TradeExecutor.mqh   // Order-Execution
│   └── Dashboard.mqh       // Logging & Dashboard
```

### 10.2 Class-Design (Optional, für sauberen Code)

```cpp
class CSymbolManager {
public:
   void Init(string symbols[]);
   void UpdateStates();
   SymbolState GetState(string symbol);
};

class CQualityScorer {
public:
   double CalculateScore(string symbol, SymbolState &state);
};

class CRiskManager {
public:
   void UpdateTrailingDD();
   double GetCurrentRisk();
   double CalculateLotSize(string symbol, double slDistance);
};

class CTradeExecutor {
public:
   bool OpenTrade(string symbol, SymbolState &state);
   void ManagePosition(ulong ticket);
};
```

---

## 11. TESTING-ANFORDERUNGEN

### 11.1 Backtest-Setup

**Strategy Tester Konfiguration:**
- **Zeitraum:** 2020-01-01 bis 2025-01-01 (5 Jahre)
- **Symbole:** Alle 25 (Multi-Symbol-Backtest erforderlich)
- **Timeframe:** H4
- **Modell:** Every Tick (basiert auf echten Ticks)
- **Initial Deposit:** 10.000 EUR
- **Leverage:** 1:100 (typisch für Pepperstone)

**Metrics zu tracken:**
- Total Trades
- Win-Rate (%)
- Average Win / Average Loss
- Profit Factor
- Max Drawdown (%)
- Sharpe Ratio
- Recovery Factor

---

### 11.2 Forward-Test (Demo)

**Dauer:** Mindestens 3 Monate

**Setup:**
- Pepperstone Demo-Account
- 10.000 EUR Balance
- EA 24/7 laufen lassen (VPS)
- FXBlue Copier zu Demo-Prop-Accounts (optional)

**Monitoring:**
- Daily: Dashboard checken
- Weekly: Performance-Report
- Monthly: Vergleich mit manuellen Trading-Erwartungen

---

### 11.3 Acceptance-Criteria

**EA ist "ready for live" wenn:**

✅ Backtest Win-Rate >= 40%
✅ Backtest Profit Factor >= 1.3
✅ Max Drawdown <= 10% (im Backtest)
✅ Forward-Test (3 Monate) ohne kritische Bugs
✅ Forward-Test Performance ähnlich wie Backtest (±10%)
✅ Trade-Frequency: ~10-20 Trades/Monat
✅ Trailing-DD-Modell funktioniert korrekt
✅ Partial-Close + BE-Shift funktioniert
✅ Multi-Symbol-Management stabil

---

## 12. BEKANNTE RISIKEN & EDGE-CASES

### 12.1 Broker-spezifische Issues

**Spread-Spikes:**
- Während News oder Low-Liquidity (z.B. Sonntag-Open)
- Könnte zu ungünstigen Fills führen
- **Mitigation:** Spread-Filter (optional, nicht in v1.0)

**Slippage:**
- Market-Orders können zu anderem Preis gefüllt werden
- **Mitigation:** Akzeptiert (bei Swing-Trading vernachlässigbar)

**Requotes:**
- Broker lehnt Preis ab
- **Mitigation:** Retry-Logik (1× Retry)

---

### 12.2 MT5-Besonderheiten

**Netting vs. Hedging:**
- EA ist für **Netting-Mode** designed (Standard bei Pepperstone)
- Hedging-Mode würde separate Logik benötigen

**GlobalVariables:**
- Werden gelöscht wenn MT5 komplett geschlossen wird
- **Mitigation:** Backup in File (optional)

---

### 12.3 FXBlue-Copier-Issues

**Lot-Scaling:**
- FXBlue muss korrekt konfiguriert sein
- EA hat KEINE Kontrolle darüber
- **Mitigation:** FXBlue-Settings vor Live-Start prüfen

**Symbol-Mapping:**
- Wenn Prop-Firm andere Symbol-Namen hat
- **Mitigation:** FXBlue-Symbol-Mapping nutzen

---

## 13. VERSIONS-ROADMAP

### v1.0 (MVP - Minimum Viable Product)
- Multi-Symbol-Scanner (25 Symbole)
- State-Machine
- Quality-Scoring
- Basic Trade-Execution
- Trailing-DD
- Partial-Close + BE-Shift

### v1.1 (Enhancements)
- News-Filter (optional)
- Spread-Filter
- Advanced Logging (CSV-Export)
- Performance-Dashboard (detaillierter)

### v1.2 (Optimizations)
- Machine-Learning-basiertes Quality-Scoring
- Adaptive ATR-Multiplier
- Correlation-Management (optional)

---

## 14. SUPPORT & MAINTENANCE

### 14.1 Known Issues Log

**Zu dokumentieren:**
- Bug-Reports
- Edge-Cases
- Performance-Issues

**Format:**
```
Date: 2025-01-15
Issue: EA öffnet Trade trotz EMA zu nah
Root Cause: Distanz-Check falsch berechnet
Fix: ATR-Normalisierung korrigiert
Status: FIXED in v1.0.1
```

---

### 14.2 Update-Prozess

**Vor jedem Update:**
1. Backtest mit neuer Version
2. Vergleich mit alter Version
3. Forward-Test auf Demo (1 Monat)
4. Dann erst Live-Update

---

## 15. KONTAKT & FRAGEN

**Bei technischen Fragen:**
- Viktor Petrov (MQL5-Entwickler)
- Tom Fischer (Trading-Strategie-Validierung)

**Bei Strategie-Fragen:**
- Markus (Original-Strategie-Entwickler)

---

**ENDE DER SPEZIFIKATION**

---

**Dokument-Version:** 1.0
**Erstellt:** 2025-01-26
**Autor:** Viktor Petrov
**Für:** Markus Schnittker
**Ziel:** MQL5 EA-Entwicklung (Claude Haiku Implementation)
