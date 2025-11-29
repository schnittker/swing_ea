# MQL5 EA - Implementation Task-Liste für Claude Haiku

---

## PROJEKT-STRUKTUR

```
SwingEA_v1/
├── SwingEA_v1.mq5              # Main EA File
├── Include/
│   ├── SymbolManager.mqh       # Multi-Symbol-Handling
│   ├── StateManager.mqh        # State-Machine
│   ├── QualityScorer.mqh       # Quality-Scoring-System
│   ├── RiskManager.mqh         # Risk & Position-Sizing
│   ├── TradeExecutor.mqh       # Trade-Execution
│   └── Dashboard.mqh           # Logging & Dashboard
└── README.md                   # Dokumentation
```

---

## PRIORITÄTEN

- **P0 (Critical):** Muss funktionieren, sonst kein MVP
- **P1 (High):** Wichtig für Production-Readiness
- **P2 (Medium):** Nice-to-have, kann später
- **P3 (Low):** Optional, für zukünftige Versionen

---

## PHASE 1: GRUNDGERÜST (P0)

### Task 1.1: Projekt-Setup
**Priorität:** P0
**Geschätzte Zeit:** 30 Min
**Beschreibung:**
- MQL5-Projekt erstellen
- Ordnerstruktur anlegen (Include-Folder)
- Main-File `SwingEA_v1.mq5` erstellen
- Basis-Struktur (OnInit, OnDeinit, OnTimer)

**Acceptance-Criteria:**
- ✅ Projekt kompiliert ohne Fehler
- ✅ EA kann auf Chart geladen werden
- ✅ OnInit() gibt "EA Initialized" aus

**Code-Gerüst:**
```cpp
//+------------------------------------------------------------------+
//| SwingEA_v1.mq5                                                    |
//| Copyright 2025, Markus Schnittker                                 |
//+------------------------------------------------------------------+
#property copyright "Markus Schnittker"
#property version   "1.00"

int OnInit() {
   Print("SwingEA v1.0 initialized");
   EventSetTimer(900); // 15 Min
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   EventKillTimer();
   Print("SwingEA v1.0 deinitialized");
}

void OnTimer() {
   Print("Timer fired");
}
```

---

### Task 1.2: Input-Parameter definieren
**Priorität:** P0
**Geschätzte Zeit:** 20 Min
**Beschreibung:**
- Alle Input-Parameter aus Spezifikation (Kapitel 9.1) implementieren
- Sinnvolle Defaults setzen

**Acceptance-Criteria:**
- ✅ Alle Parameter im EA-Properties sichtbar
- ✅ Parameter können geändert werden

**Referenz:** Siehe Spezifikation Kapitel 9.1

---

### Task 1.3: Symbol-Array definieren
**Priorität:** P0
**Geschätzte Zeit:** 10 Min
**Beschreibung:**
- Array mit 25 Symbolen erstellen

**Code:**
```cpp
string symbols[] = {
   "EURJPY", "XAUUSD", "GBPJPY", "NZDJPY", "EURCAD",
   "EURCHF", "GBPCHF", "USDCAD", "AUDUSD", "USDCHF",
   "GBPNZD", "CADJPY", "AUDNZD", "NZDUSD", "GBPUSD",
   "EURNZD", "AUDCAD", "GBPCAD", "EURUSD", "USDJPY",
   "AUDJPY", "CHFJPY", "CADCHF", "GBPAUD", "EURAUD"
};
```

**Acceptance-Criteria:**
- ✅ Array korrekt deklariert
- ✅ Anzahl Symbole = 25

---

### Task 1.4: State-Machine Enum & Struct definieren
**Priorität:** P0
**Geschätzte Zeit:** 15 Min
**Beschreibung:**
- Enum für TradingState
- Struct für SymbolState

**Code:**
```cpp
enum TradingState {
   STATE_NO_TRADE,
   STATE_TREND_FORMING,
   STATE_RETRACEMENT,
   STATE_AT_FIB,
   STATE_TRADE_TAKEN
};

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
   bool isLongSetup;
};
```

**Acceptance-Criteria:**
- ✅ Enum & Struct kompilieren
- ✅ Array von SymbolStates kann erstellt werden

---

## PHASE 2: INDIKATOR-HANDLING (P0)

### Task 2.1: EMA200-Handle für alle Symbole
**Priorität:** P0
**Geschätzte Zeit:** 45 Min
**Beschreibung:**
- Für jedes Symbol ein EMA200(H4)-Handle erstellen
- Handle-Array verwalten
- Im OnDeinit() alle Handles freigeben

**Code-Struktur:**
```cpp
int emaHandles[25];

int OnInit() {
   for (int i = 0; i < ArraySize(symbols); i++) {
      emaHandles[i] = iMA(symbols[i], PERIOD_H4, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);

      if (emaHandles[i] == INVALID_HANDLE) {
         Print("ERROR: EMA Handle failed for ", symbols[i]);
         return INIT_FAILED;
      }
   }
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   for (int i = 0; i < ArraySize(emaHandles); i++) {
      IndicatorRelease(emaHandles[i]);
   }
}
```

**Acceptance-Criteria:**
- ✅ Alle 25 EMA-Handles erfolgreich erstellt
- ✅ Handles werden korrekt freigegeben

---

### Task 2.2: ATR(14)-Handle für alle Symbole
**Priorität:** P0
**Geschätzte Zeit:** 30 Min
**Beschreibung:**
- ATR-Handles analog zu EMA

**Acceptance-Criteria:**
- ✅ Alle 25 ATR-Handles erfolgreich erstellt

---

### Task 2.3: Indikator-Werte auslesen (Helper-Funktionen)
**Priorität:** P0
**Geschätzte Zeit:** 1 Stunde
**Beschreibung:**
- Funktionen zum Auslesen von EMA/ATR-Werten

**Code:**
```cpp
double GetEMA(string symbol, int shift) {
   int index = GetSymbolIndex(symbol);
   if (index < 0) return 0;

   double buffer[1];
   if (CopyBuffer(emaHandles[index], 0, shift, 1, buffer) <= 0) {
      Print("ERROR: CopyBuffer failed for EMA");
      return 0;
   }
   return buffer[0];
}

double GetATR(string symbol, int shift) {
   int index = GetSymbolIndex(symbol);
   if (index < 0) return 0;

   double buffer[1];
   if (CopyBuffer(atrHandles[index], 0, shift, 1, buffer) <= 0) {
      Print("ERROR: CopyBuffer failed for ATR");
      return 0;
   }
   return buffer[0];
}

int GetSymbolIndex(string symbol) {
   for (int i = 0; i < ArraySize(symbols); i++) {
      if (symbols[i] == symbol) return i;
   }
   return -1;
}
```

**Acceptance-Criteria:**
- ✅ GetEMA() liefert korrekte Werte
- ✅ GetATR() liefert korrekte Werte
- ✅ Error-Handling funktioniert

---

## PHASE 3: SWING-DETECTION (P0)

### Task 3.1: Swing High Detection
**Priorität:** P0
**Geschätzte Zeit:** 2 Stunden
**Beschreibung:**
- Implementierung der Swing-High-Logik (retrospektiv, 1 Candle Delay)

**Referenz:** Spezifikation Kapitel 2.2

**Code-Struktur:**
```cpp
bool IsSwingHigh(string symbol, int bar) {
   double high_i = iHigh(symbol, PERIOD_H4, bar);
   double high_i1 = iHigh(symbol, PERIOD_H4, bar - 1);
   double high_i2 = iHigh(symbol, PERIOD_H4, bar - 2);
   double high_ip1 = iHigh(symbol, PERIOD_H4, bar + 1);
   double high_ip2 = iHigh(symbol, PERIOD_H4, bar + 2);

   // Basic Structure
   if (!(high_i > high_i1 && high_i > high_ip1)) return false;
   if (!(high_i >= high_i2 && high_i >= high_ip2)) return false;

   // ATR-Filter
   double atr = GetATR(symbol, bar);
   int symbolIndex = GetSymbolIndex(symbol);
   double lastSwingHigh = symbolStates[symbolIndex].lastSwingHigh;

   if (lastSwingHigh > 0) {
      if ((high_i - lastSwingHigh) < 0.5 * atr) return false;
   }

   return true;
}
```

**Acceptance-Criteria:**
- ✅ Swing-Highs werden korrekt erkannt
- ✅ ATR-Filter funktioniert
- ✅ Keine False-Positives bei engen Swings

---

### Task 3.2: Swing Low Detection
**Priorität:** P0
**Geschätzte Zeit:** 1 Stunde
**Beschreibung:**
- Analog zu Swing High (spiegelverkehrt)

**Acceptance-Criteria:**
- ✅ Swing-Lows werden korrekt erkannt

---

### Task 3.3: Swing-Update-Logik
**Priorität:** P0
**Geschätzte Zeit:** 1.5 Stunden
**Beschreibung:**
- Für jedes Symbol: Swings scannen und in SymbolState speichern

**Code-Struktur:**
```cpp
void UpdateSwings(string symbol) {
   int symbolIndex = GetSymbolIndex(symbol);
   if (symbolIndex < 0) return;

   // Check letzte X Bars für neue Swings (z.B. 100 Bars)
   for (int i = 2; i <= 100; i++) {
      if (IsSwingHigh(symbol, i)) {
         double newHigh = iHigh(symbol, PERIOD_H4, i);

         // Nur updaten wenn höher als letzter Swing High
         if (newHigh > symbolStates[symbolIndex].lastSwingHigh) {
            symbolStates[symbolIndex].lastSwingHigh = newHigh;
            symbolStates[symbolIndex].swingHighBar = i;

            Print("New Swing High detected: ", symbol, " at ", newHigh);
            break; // Nur der neueste Swing
         }
      }

      if (IsSwingLow(symbol, i)) {
         // Analog für Swing Low
      }
   }
}
```

**Acceptance-Criteria:**
- ✅ Swings werden korrekt in SymbolState gespeichert
- ✅ Nur neueste Swings werden gespeichert

---

## PHASE 4: FIBONACCI-BERECHNUNG (P0)

### Task 4.1: Fibonacci-Levels berechnen
**Priorität:** P0
**Geschätzte Zeit:** 1 Stunde
**Beschreibung:**
- Fib-Levels 38.2%, 50%, 61.8% aus Swing-Range berechnen

**Code:**
```cpp
void CalculateFibLevels(int symbolIndex) {
   double swingHigh = symbolStates[symbolIndex].lastSwingHigh;
   double swingLow = symbolStates[symbolIndex].lastSwingLow;

   if (swingHigh == 0 || swingLow == 0) return;

   double range = swingHigh - swingLow;

   // Für Long-Setup (Retracement von High nach unten)
   if (symbolStates[symbolIndex].isLongSetup) {
      symbolStates[symbolIndex].fib382 = swingHigh - 0.382 * range;
      symbolStates[symbolIndex].fib500 = swingHigh - 0.500 * range;
      symbolStates[symbolIndex].fib618 = swingHigh - 0.618 * range;
   }
   // Für Short-Setup (Retracement von Low nach oben)
   else {
      symbolStates[symbolIndex].fib382 = swingLow + 0.382 * range;
      symbolStates[symbolIndex].fib500 = swingLow + 0.500 * range;
      symbolStates[symbolIndex].fib618 = swingLow + 0.618 * range;
   }
}
```

**Acceptance-Criteria:**
- ✅ Fib-Levels korrekt berechnet
- ✅ Long/Short-Richtung berücksichtigt

---

### Task 4.2: Preis-in-Fib-Zone-Check
**Priorität:** P0
**Geschätzte Zeit:** 45 Min
**Beschreibung:**
- Check ob aktueller Preis im Bereich 50%-61.8% ist

**Code:**
```cpp
bool IsPriceAtFibZone(int symbolIndex) {
   double currentPrice = iClose(symbolStates[symbolIndex].symbol, PERIOD_H4, 0);
   double fib50 = symbolStates[symbolIndex].fib500;
   double fib618 = symbolStates[symbolIndex].fib618;
   double atr = GetATR(symbolStates[symbolIndex].symbol, 0);

   double tolerance = Fib_Tolerance_ATR * atr;

   // Long: Preis zwischen fib618 und fib50 (von unten nach oben)
   if (symbolStates[symbolIndex].isLongSetup) {
      return (currentPrice >= fib618 - tolerance && currentPrice <= fib50 + tolerance);
   }
   // Short: analog
   else {
      return (currentPrice <= fib618 + tolerance && currentPrice >= fib50 - tolerance);
   }
}
```

**Acceptance-Criteria:**
- ✅ Funktion liefert true wenn Preis in Zone
- ✅ Toleranz (ATR-basiert) funktioniert

---

## PHASE 5: TREND-FILTER (P0)

### Task 5.1: EMA200-Trend-Check (4H)
**Priorität:** P0
**Geschätzte Zeit:** 1 Stunde
**Beschreibung:**
- Check ob Preis über/unter EMA200 und EMA steigend/fallend

**Code:**
```cpp
bool IsEMATrendValid(string symbol, bool isLong) {
   double ema0 = GetEMA(symbol, 0);
   double ema5 = GetEMA(symbol, 5);
   double price = iClose(symbol, PERIOD_H4, 0);
   double atr = GetATR(symbol, 0);

   double distance = MathAbs(price - ema0);

   // Min-Distanz-Check
   if (distance < MinEMADistance_ATR * atr) return false;

   // Long: Preis über EMA, EMA steigt
   if (isLong) {
      return (price > ema0 && ema0 > ema5);
   }
   // Short: Preis unter EMA, EMA fällt
   else {
      return (price < ema0 && ema0 < ema5);
   }
}
```

**Acceptance-Criteria:**
- ✅ Trend-Richtung korrekt erkannt
- ✅ Min-Distanz-Filter funktioniert

---

### Task 5.2: 1D-Trend-Check (Multi-Timeframe)
**Priorität:** P0
**Geschätzte Zeit:** 1.5 Stunden
**Beschreibung:**
- EMA200 auf 1D-Chart checken
- Hard-Reject wenn 1D dagegen, Bonus wenn aligned

**Code:**
```cpp
int Check1DTrend(string symbol, bool is4H_Long) {
   // EMA200 auf 1D
   int ema1D_Handle = iMA(symbol, PERIOD_D1, 200, 0, MODE_EMA, PRICE_CLOSE);
   if (ema1D_Handle == INVALID_HANDLE) return 0;

   double ema1D_buffer[2];
   if (CopyBuffer(ema1D_Handle, 0, 0, 2, ema1D_buffer) <= 0) {
      IndicatorRelease(ema1D_Handle);
      return 0;
   }

   double ema1D_0 = ema1D_buffer[0];
   double ema1D_1 = ema1D_buffer[1];
   double price1D = iClose(symbol, PERIOD_D1, 0);

   IndicatorRelease(ema1D_Handle);

   bool uptrend1D = (price1D > ema1D_0 && ema1D_0 > ema1D_1);
   bool downtrend1D = (price1D < ema1D_0 && ema1D_0 < ema1D_1);

   // Für Long-Setup:
   if (is4H_Long) {
      if (downtrend1D) return -1; // Hard Reject (1D gegen uns)
      if (uptrend1D) return 2;    // Perfect Alignment
      return 1;                   // Neutral OK
   }
   // Für Short-Setup:
   else {
      if (uptrend1D) return -1;
      if (downtrend1D) return 2;
      return 1;
   }
}
```

**Acceptance-Criteria:**
- ✅ 1D-Trend korrekt erkannt
- ✅ Return-Werte korrekt (-1 = reject, 1 = neutral, 2 = aligned)

---

## PHASE 6: CANDLESTICK-PATTERN-ERKENNUNG (P0)

### Task 6.1: Rejection-Candle-Erkennung
**Priorität:** P0
**Geschätzte Zeit:** 2 Stunden
**Beschreibung:**
- Bullish/Bearish Rejection (Pinbar) erkennen

**Referenz:** Spezifikation Kapitel 2.4

**Code:**
```cpp
bool IsBullishRejection(string symbol, int bar) {
   double open = iOpen(symbol, PERIOD_H4, bar);
   double close = iClose(symbol, PERIOD_H4, bar);
   double high = iHigh(symbol, PERIOD_H4, bar);
   double low = iLow(symbol, PERIOD_H4, bar);

   double body = MathAbs(close - open);
   double lowerWick = MathMin(open, close) - low;
   double upperWick = high - MathMax(open, close);
   double candleHeight = high - low;

   // Rejection-Kriterien
   if (lowerWick < 1.8 * body) return false;
   if (upperWick > 0.3 * candleHeight) return false;
   if (close <= open) return false; // Muss bullish sein
   if (close < low + 0.67 * candleHeight) return false;

   return true;
}

bool IsBearishRejection(string symbol, int bar) {
   // Analog, spiegelverkehrt
}
```

**Acceptance-Criteria:**
- ✅ Rejection-Candles korrekt erkannt
- ✅ False-Positives minimiert

---

### Task 6.2: Engulfing-Candle-Erkennung
**Priorität:** P1
**Geschätzte Zeit:** 1.5 Stunden
**Beschreibung:**
- Bullish/Bearish Engulfing erkennen

**Code:**
```cpp
bool IsBullishEngulfing(string symbol, int bar) {
   double open0 = iOpen(symbol, PERIOD_H4, bar);
   double close0 = iClose(symbol, PERIOD_H4, bar);
   double open1 = iOpen(symbol, PERIOD_H4, bar + 1);
   double close1 = iClose(symbol, PERIOD_H4, bar + 1);

   double body0 = close0 - open0;
   double body1 = MathAbs(close1 - open1);

   // Kriterien
   if (close0 <= open0) return false; // Candle 0 muss bullish sein
   if (close1 >= open1) return false; // Candle 1 muss bearish sein
   if (body0 < 1.2 * body1) return false; // Engulfing-Größe
   if (open0 > close1) return false;
   if (close0 < open1) return false;

   return true;
}
```

**Acceptance-Criteria:**
- ✅ Engulfing-Candles korrekt erkannt

---

## PHASE 7: STATE-MACHINE (P0)

### Task 7.1: State-Update-Logik
**Priorität:** P0
**Geschätzte Zeit:** 3 Stunden
**Beschreibung:**
- Für jedes Symbol: State basierend auf Bedingungen updaten

**Code-Struktur:**
```cpp
void UpdateSymbolState(int symbolIndex) {
   string symbol = symbolStates[symbolIndex].symbol;
   TradingState currentState = symbolStates[symbolIndex].state;

   // State-Transition-Logik
   switch (currentState) {
      case STATE_NO_TRADE:
         // Check ob Swing erkannt + EMA-Filter OK
         if (HasValidSwing(symbolIndex) && IsEMATrendValid(symbol, true)) {
            symbolStates[symbolIndex].state = STATE_TREND_FORMING;
         }
         break;

      case STATE_TREND_FORMING:
         CalculateFibLevels(symbolIndex);
         // Check ob Preis Richtung Fibo retraced
         if (IsPriceRetracing(symbolIndex)) {
            symbolStates[symbolIndex].state = STATE_RETRACEMENT;
         }
         break;

      case STATE_RETRACEMENT:
         // Check ob Preis Fib-Zone erreicht hat
         if (IsPriceAtFibZone(symbolIndex)) {
            symbolStates[symbolIndex].state = STATE_AT_FIB;
         }
         break;

      case STATE_AT_FIB:
         // Check ob Entry-Candle (Rejection/Engulfing) erscheint
         if (HasEntryCandle(symbol)) {
            // Trade wird später geöffnet (in ExecuteTrades)
            // State wechselt zu TRADE_TAKEN nach Trade-Open
         }
         break;

      case STATE_TRADE_TAKEN:
         // Check ob Position geschlossen wurde
         if (!HasOpenPosition(symbol)) {
            symbolStates[symbolIndex].state = STATE_NO_TRADE;
         }
         break;
   }
}
```

**Acceptance-Criteria:**
- ✅ States wechseln korrekt basierend auf Bedingungen
- ✅ Keine "hängenden" States

---

### Task 7.2: State-Reset bei Invalidierung
**Priorität:** P1
**Geschätzte Zeit:** 1 Stunde
**Beschreibung:**
- Wenn neuer Swing entsteht → altes Setup invalidieren

**Code:**
```cpp
void CheckForInvalidation(int symbolIndex) {
   // Wenn neuer Swing erkannt wird, reset State
   if (symbolStates[symbolIndex].state != STATE_TRADE_TAKEN) {
      // Neue Swing-Detection
      UpdateSwings(symbolStates[symbolIndex].symbol);

      // Wenn Swing sich geändert hat → Reset
      // (Logik hier)
   }
}
```

**Acceptance-Criteria:**
- ✅ State wird bei neuem Swing resettet

---

## PHASE 8: QUALITY-SCORING (P0)

### Task 8.1: Score-Berechnung implementieren
**Priorität:** P0
**Geschätzte Zeit:** 2.5 Stunden
**Beschreibung:**
- Quality-Score (0-100) für jedes Symbol berechnen

**Referenz:** Spezifikation Kapitel 3.3

**Code-Struktur:**
```cpp
double CalculateQualityScore(int symbolIndex) {
   double score = 0.0;
   string symbol = symbolStates[symbolIndex].symbol;

   // 1. Multi-Timeframe-Alignment (0-30)
   int mtfResult = Check1DTrend(symbol, symbolStates[symbolIndex].isLongSetup);
   if (mtfResult == -1) return 0; // Hard Reject
   if (mtfResult == 2) score += 30;
   else score += 15;

   // 2. EMA200-Distanz (0-20)
   score += ScoreEMADistance(symbol);

   // 3. Fib-Level-Präzision (0-20)
   score += ScoreFibPrecision(symbolIndex);

   // 4. Candle-Pattern-Qualität (0-20)
   score += ScoreCandlePattern(symbol);

   // 5. Swing-Struktur (0-10)
   if (HasCleanSwingStructure(symbolIndex)) score += 10;

   return score;
}
```

**Acceptance-Criteria:**
- ✅ Score wird korrekt berechnet
- ✅ Score liegt zwischen 0-100

---

### Task 8.2: Top-2-Setup-Auswahl
**Priorität:** P0
**Geschätzte Zeit:** 1.5 Stunden
**Beschreibung:**
- Alle Setups nach Score sortieren, Top-2 auswählen

**Code:**
```cpp
void SelectBestSetups(int &bestIndexes[]) {
   // Array mit (Index, Score) Paaren
   struct ScorePair {
      int index;
      double score;
   };

   ScorePair scoredSetups[];
   ArrayResize(scoredSetups, 0);

   // Alle Symbole im State AT_FIB sammeln
   for (int i = 0; i < ArraySize(symbolStates); i++) {
      if (symbolStates[i].state == STATE_AT_FIB) {
         double score = CalculateQualityScore(i);

         if (score >= MinQualityScore) {
            int newSize = ArraySize(scoredSetups) + 1;
            ArrayResize(scoredSetups, newSize);
            scoredSetups[newSize - 1].index = i;
            scoredSetups[newSize - 1].score = score;
         }
      }
   }

   // Sortieren (höchster Score zuerst)
   // ... Sorting-Logik ...

   // Top-2 auswählen
   ArrayResize(bestIndexes, 0);
   int maxCount = MathMin(2, ArraySize(scoredSetups));
   for (int i = 0; i < maxCount; i++) {
      ArrayResize(bestIndexes, i + 1);
      bestIndexes[i] = scoredSetups[i].index;
   }
}
```

**Acceptance-Criteria:**
- ✅ Top-2-Setups korrekt ausgewählt
- ✅ Nur Setups mit Score >= MinQualityScore

---

## PHASE 9: RISK-MANAGEMENT (P0)

### Task 9.1: Trailing-Drawdown berechnen
**Priorität:** P0
**Geschätzte Zeit:** 2 Stunden
**Beschreibung:**
- Equity-Peak tracken, Drawdown berechnen, Risk anpassen

**Referenz:** Spezifikation Kapitel 4.1

**Code:**
```cpp
double equityPeak = 0.0;
double currentDD = 0.0;
double currentRisk = 1.0;

void UpdateTrailingDD() {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   // Peak-Update
   if (GlobalVariableCheck("EA_EquityPeak")) {
      equityPeak = GlobalVariableGet("EA_EquityPeak");
   } else {
      equityPeak = equity;
      GlobalVariableSet("EA_EquityPeak", equityPeak);
   }

   if (equity > equityPeak) {
      equityPeak = equity;
      GlobalVariableSet("EA_EquityPeak", equityPeak);
   }

   // DD berechnen
   currentDD = ((equityPeak - equity) / equityPeak) * 100.0;

   // Risk anpassen
   if (currentDD >= 4.0) {
      currentRisk = RiskPercent_High;
   } else if (currentDD >= 3.0) {
      currentRisk = RiskPercent_Medium;
   } else {
      currentRisk = RiskPercent_Normal;
   }

   // Emergency-Stop
   if (currentDD >= MaxDrawdownPercent) {
      Comment("MAX DRAWDOWN REACHED - EA STOPPED");
      CloseAllPositions();
      ExpertRemove();
   }
}
```

**Acceptance-Criteria:**
- ✅ Equity-Peak wird korrekt getrackt
- ✅ Risk passt sich dynamisch an
- ✅ EA stoppt bei Max-DD

---

### Task 9.2: Position-Sizing (Lot-Berechnung)
**Priorität:** P0
**Geschätzte Zeit:** 2 Stunden
**Beschreibung:**
- Dynamische Lot-Size basierend auf Risk% und SL-Distanz

**Referenz:** Spezifikation Kapitel 4.2

**Code:**
```cpp
double CalculateLotSize(string symbol, double slDistanceInPoints) {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (currentRisk / 100.0);

   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

   double slDistanceInPrice = slDistanceInPoints * point;
   double slDistanceInTicks = slDistanceInPrice / tickSize;

   double lotSize = riskAmount / (slDistanceInTicks * tickValue);

   // Normalisierung
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   lotSize = MathMax(minLot, lotSize);
   lotSize = MathMin(maxLot, lotSize);
   lotSize = NormalizeDouble(MathFloor(lotSize / lotStep) * lotStep, 2);

   return lotSize;
}
```

**Acceptance-Criteria:**
- ✅ Lot-Size korrekt berechnet
- ✅ Normalisierung funktioniert
- ✅ Min/Max-Limits eingehalten

---

## PHASE 10: TRADE-EXECUTION (P0)

### Task 10.1: Trade öffnen (Buy/Sell)
**Priorität:** P0
**Geschätzte Zeit:** 2.5 Stunden
**Beschreibung:**
- Trade mit SL/TP öffnen

**Code:**
```cpp
#include <Trade\Trade.mqh>
CTrade trade;

bool OpenTrade(int symbolIndex) {
   string symbol = symbolStates[symbolIndex].symbol;
   bool isLong = symbolStates[symbolIndex].isLongSetup;

   // SL-Distanz berechnen
   double atr = GetATR(symbol, 0);
   double slDistance = ATR_SL_Multiplier * atr;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double slDistanceInPoints = slDistance / point;

   // Entry-Preis
   double entry = isLong ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);

   // SL/TP berechnen
   double sl = isLong ? entry - slDistance : entry + slDistance;
   double tp1 = CalculateFibTP(symbolIndex, 1.000);

   // Lot-Size
   double lotSize = CalculateLotSize(symbol, slDistanceInPoints);

   if (lotSize == 0) {
      Print("ERROR: Invalid lot size");
      return false;
   }

   // Order öffnen
   bool success = false;
   if (isLong) {
      success = trade.Buy(lotSize, symbol, 0, sl, tp1, "SwingEA_v1");
   } else {
      success = trade.Sell(lotSize, symbol, 0, sl, tp1, "SwingEA_v1");
   }

   if (success) {
      symbolStates[symbolIndex].state = STATE_TRADE_TAKEN;
      Print("Trade opened: ", symbol, " | Lot: ", lotSize, " | Risk: ", currentRisk, "%");
   } else {
      Print("ERROR: Trade failed: ", trade.ResultRetcodeDescription());
   }

   return success;
}
```

**Acceptance-Criteria:**
- ✅ Trade wird korrekt geöffnet
- ✅ SL/TP korrekt gesetzt
- ✅ Error-Handling funktioniert

---

### Task 10.2: Fibonacci-TP berechnen
**Priorität:** P0
**Geschätzte Zeit:** 1 Stunde
**Beschreibung:**
- TP1/TP2/TP3 basierend auf Fib-Extensions

**Code:**
```cpp
double CalculateFibTP(int symbolIndex, double extension) {
   double swingHigh = symbolStates[symbolIndex].lastSwingHigh;
   double swingLow = symbolStates[symbolIndex].lastSwingLow;
   double range = swingHigh - swingLow;

   if (symbolStates[symbolIndex].isLongSetup) {
      return swingHigh + extension * range;
   } else {
      return swingLow - extension * range;
   }
}
```

**Acceptance-Criteria:**
- ✅ TPs korrekt berechnet

---

### Task 10.3: Max-Position-Check
**Priorität:** P0
**Geschätzte Zeit:** 30 Min
**Beschreibung:**
- Nur traden wenn < 2 offene Positionen

**Code:**
```cpp
bool CanOpenNewPosition() {
   int openCount = 0;

   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (PositionGetString(POSITION_COMMENT) == "SwingEA_v1") {
         openCount++;
      }
   }

   return (openCount < MaxOpenPositions);
}
```

**Acceptance-Criteria:**
- ✅ Max-Position-Limit funktioniert

---

## PHASE 11: TRADE-MANAGEMENT (P0)

### Task 11.1: TP1-Erkennung & Partial-Close
**Priorität:** P0
**Geschätzte Zeit:** 2 Stunden
**Beschreibung:**
- Bei TP1: 50% schließen

**Code:**
```cpp
void ManageOpenPositions() {
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (PositionGetString(POSITION_COMMENT) != "SwingEA_v1") continue;

      // Check ob TP1 bereits behandelt wurde
      string flagName = "EA_TP1_" + IntegerToString(ticket);
      if (GlobalVariableCheck(flagName)) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double tp = PositionGetDouble(POSITION_TP);
      bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

      // TP1 erreicht?
      if ((isLong && currentPrice >= tp) || (!isLong && currentPrice <= tp)) {
         ClosePartial(ticket, PartialClosePercent / 100.0);
         MoveToBreakEven(ticket);
         GlobalVariableSet(flagName, 1); // Flag setzen
      }
   }
}

void ClosePartial(ulong ticket, double percent) {
   if (!PositionSelectByTicket(ticket)) return;

   double currentVolume = PositionGetDouble(POSITION_VOLUME);
   double closeVolume = NormalizeDouble(currentVolume * percent, 2);

   trade.PositionClosePartial(ticket, closeVolume);

   if (trade.ResultRetcode() == TRADE_RETCODE_DONE) {
      Print("Partial close: ", closeVolume, " lots");
   }
}
```

**Acceptance-Criteria:**
- ✅ Partial-Close funktioniert bei TP1
- ✅ Nur einmal pro Position

---

### Task 11.2: Break-Even-Shift
**Priorität:** P0
**Geschätzte Zeit:** 1 Stunde
**Beschreibung:**
- SL auf Entry-Preis verschieben nach TP1

**Code:**
```cpp
void MoveToBreakEven(ulong ticket) {
   if (!PositionSelectByTicket(ticket)) return;

   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

   // Nur verschieben wenn SL noch nicht auf BE
   if ((isLong && currentSL < openPrice) || (!isLong && currentSL > openPrice)) {
      trade.PositionModify(ticket, openPrice, currentTP);
      Print("SL moved to Break-Even");
   }
}
```

**Acceptance-Criteria:**
- ✅ SL wird auf BE verschoben

---

## PHASE 12: TIMING & WORKFLOW (P0)

### Task 12.1: Trading-Window-Check
**Priorität:** P0
**Geschätzte Zeit:** 1 Stunde
**Beschreibung:**
- Nur 4× täglich scannen (nach Candle-Close)

**Referenz:** Spezifikation Kapitel 5.2

**Code:** Siehe Spezifikation

**Acceptance-Criteria:**
- ✅ EA scannt nur zu definierten Zeiten

---

### Task 12.2: Main-Loop (OnTimer)
**Priorität:** P0
**Geschätzte Zeit:** 1.5 Stunden
**Beschreibung:**
- Workflow zusammensetzen

**Code:**
```cpp
void OnTimer() {
   if (!IsInTradingWindow()) return;

   // 1. Trailing-DD updaten
   UpdateTrailingDD();

   // 2. Alle Symbole scannen & States updaten
   for (int i = 0; i < ArraySize(symbolStates); i++) {
      UpdateSwings(symbolStates[i].symbol);
      UpdateSymbolState(i);
   }

   // 3. Quality-Scores berechnen
   for (int i = 0; i < ArraySize(symbolStates); i++) {
      if (symbolStates[i].state == STATE_AT_FIB) {
         symbolStates[i].qualityScore = CalculateQualityScore(i);
      }
   }

   // 4. Top-2-Setups auswählen
   int bestIndexes[];
   SelectBestSetups(bestIndexes);

   // 5. Trades öffnen (wenn Kapazität vorhanden)
   for (int i = 0; i < ArraySize(bestIndexes); i++) {
      if (!CanOpenNewPosition()) break;
      OpenTrade(bestIndexes[i]);
   }

   // 6. Offene Positionen managen
   ManageOpenPositions();

   // 7. Dashboard updaten
   UpdateDashboard();
}
```

**Acceptance-Criteria:**
- ✅ Main-Loop funktioniert
- ✅ Alle Komponenten laufen durch

---

## PHASE 13: LOGGING & DASHBOARD (P1)

### Task 13.1: Chart-Comment (Dashboard)
**Priorität:** P1
**Geschätzte Zeit:** 1.5 Stunden
**Beschreibung:**
- Übersicht auf Chart anzeigen

**Referenz:** Spezifikation Kapitel 7.2

**Acceptance-Criteria:**
- ✅ Dashboard zeigt Equity, DD, Risk, offene Positionen

---

### Task 13.2: File-Logging (Optional)
**Priorität:** P2
**Geschätzte Zeit:** 2 Stunden
**Beschreibung:**
- Trade-Journal als CSV

**Acceptance-Criteria:**
- ✅ Trades werden in CSV geloggt

---

## PHASE 14: ERROR-HANDLING & ROBUSTNESS (P1)

### Task 14.1: Symbol-Validation
**Priorität:** P1
**Geschätzte Zeit:** 1 Stunde
**Beschreibung:**
- Check ob alle Symbole verfügbar

**Referenz:** Spezifikation Kapitel 8.3

**Acceptance-Criteria:**
- ✅ EA warnt bei fehlenden Symbolen

---

### Task 14.2: Restart-Safety
**Priorität:** P1
**Geschätzte Zeit:** 1.5 Stunden
**Beschreibung:**
- Offene Positionen nach EA-Restart wiedererkennen

**Referenz:** Spezifikation Kapitel 8.2

**Acceptance-Criteria:**
- ✅ States werden nach Restart korrekt gesetzt

---

## PHASE 15: TESTING (P0)

### Task 15.1: Compile & Syntax-Check
**Priorität:** P0
**Geschätzte Zeit:** 30 Min
**Beschreibung:**
- EA kompiliert ohne Fehler

**Acceptance-Criteria:**
- ✅ 0 Errors, 0 Warnings

---

### Task 15.2: Unit-Tests (Manual)
**Priorität:** P0
**Geschätzte Zeit:** 3 Stunden
**Beschreibung:**
- Jedes Modul einzeln testen:
  - Swing-Detection auf bekannten Charts
  - Fibonacci-Berechnung validieren
  - Quality-Score manuell nachrechnen
  - Lot-Size-Berechnung validieren

**Acceptance-Criteria:**
- ✅ Alle Module liefern erwartete Ergebnisse

---

### Task 15.3: Strategy-Tester (Backtest)
**Priorität:** P0
**Geschätzte Zeit:** 2 Stunden (Setup + Analyse)
**Beschreibung:**
- Backtest über 2020-2025 (5 Jahre)
- Multi-Symbol-Test

**Acceptance-Criteria:**
- ✅ Backtest läuft durch ohne Crashes
- ✅ Trades werden geöffnet
- ✅ Win-Rate >= 40%
- ✅ Profit-Factor >= 1.2

---

### Task 15.4: Demo-Account-Test
**Priorität:** P0
**Geschätzte Zeit:** 1 Woche (Live-Monitoring)
**Beschreibung:**
- EA auf Demo-Account laufen lassen
- 1 Woche beobachten

**Acceptance-Criteria:**
- ✅ Keine Crashes
- ✅ Trades werden korrekt ausgeführt
- ✅ Trailing-DD funktioniert

---

## GESAMT-ZEITSCHÄTZUNG

| Phase | Geschätzte Zeit |
|-------|----------------|
| Phase 1-4 (Grundgerüst, Indikatoren, Swings, Fib) | ~10 Stunden |
| Phase 5-8 (Trend-Filter, Candles, State-Machine, Scoring) | ~12 Stunden |
| Phase 9-11 (Risk, Execution, Management) | ~10 Stunden |
| Phase 12-14 (Timing, Logging, Error-Handling) | ~6 Stunden |
| Phase 15 (Testing) | ~6 Stunden |
| **TOTAL** | **~44 Stunden** |

---

## PRIORITÄTEN-ZUSAMMENFASSUNG

**P0 (Critical) - Für MVP nötig:**
- Phase 1-12 (ohne File-Logging)
- Phase 15 (Testing)

**P1 (High) - Wichtig für Production:**
- Dashboard
- Restart-Safety
- Symbol-Validation

**P2 (Medium) - Nice-to-have:**
- File-Logging (CSV)
- Engulfing-Candles (Rejection reicht für MVP)

**P3 (Low) - Zukünftige Versionen:**
- News-Filter
- Spread-Filter
- ML-basiertes Scoring

---

## DEVELOPMENT-WORKFLOW FÜR HAIKU

**Empfohlene Reihenfolge:**

1. **Start mit Phase 1** (Grundgerüst) → kompilieren & testen
2. **Phase 2** (Indikatoren) → validieren dass Werte korrekt ausgelesen werden
3. **Phase 3** (Swing-Detection) → auf bekannten Charts testen
4. **Phase 4** (Fibonacci) → manuell nachrechnen
5. **Phase 5-6** (Trend-Filter, Candles) → einzeln testen
6. **Phase 7** (State-Machine) → Logs prüfen
7. **Phase 8** (Scoring) → Scores manuell validieren
8. **Phase 9** (Risk-Management) → mit Demo-Account testen
9. **Phase 10-11** (Execution, Management) → KRITISCH, gründlich testen
10. **Phase 12** (Timing) → auf VPS testen
11. **Phase 13-14** (Logging, Error-Handling) → Robustheit
12. **Phase 15** (Testing) → Backtest + Forward-Test

**Nach jeder Phase:**
- Kompilieren
- Testen
- Commit (falls Git verwendet wird)

---

**ENDE DER TASK-LISTE**

**Erstellt:** 2025-01-26
**Autor:** Viktor Petrov
**Für:** Markus Schnittker (Implementation durch Claude Haiku)
