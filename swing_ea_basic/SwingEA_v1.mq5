//+------------------------------------------------------------------+
//| SwingEA_v1.mq5                                                    |
//| Copyright 2025, Markus Schnittker                                 |
//+------------------------------------------------------------------+
#property copyright "Markus Schnittker"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Include Files                                                     |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

// --- Risk Management ---
input double RiskPercent_Normal = 1.0;      // Risk % (Normal, DD 0-2%)
input double RiskPercent_Medium = 0.5;      // Risk % (Medium, DD 2-3%)
input double RiskPercent_High = 0.25;       // Risk % (High, DD 3-10%)
input double MaxDrawdownPercent = 10.0;     // Max Drawdown % (Stop EA)

// --- Strategy Parameters ---
input int EMA_Period = 200;                 // EMA Period
input int ATR_Period = 14;                  // ATR Period
input double ATR_SL_Multiplier = 1.0;       // ATR SL Multiplier
input double ATR_TP_Multiplier = 2.0;       // ATR TP Multiplier
input double MinEMADistance_ATR = 0.7;      // Min EMA Distance (× ATR) - OPTIMIERT

// --- Fibonacci Levels ---
input double Fib_Level1 = 38.2;             // Fib Level 1 (%)
input double Fib_Level2 = 50.0;             // Fib Level 2 (%)
input double Fib_Level3 = 61.8;             // Fib Level 3 (%)
input double Fib_Tolerance_ATR = 0.25;      // Fib Tolerance (× ATR) - OPTIMIERT

// --- Position Management ---
input int MaxOpenPositions = 2;             // Max Open Positions

// --- Quality Scoring ---
input double MinQualityScore = 45.0;        // Min Quality Score (0-100) - OPTIMIERT

// --- Swing Detection ---
input double MinSwingDistance_ATR = 0.3;    // Min Swing Distance (× ATR) - GELOCKERT

// --- Multi-Timeframe ---
input bool Use1D_Filter = true;             // Use 1D Trend Filter

// --- Timing ---
input bool TradeOnlyInWindows = true;       // Trade only in 4 time windows - OPTIMIERT (besser für Qualität)

// --- News Filter ---
input bool UseSpreadFilter = true;          // Use Spread-Based News Filter (PROP FIRM SAFETY)
input double SpreadMultiplierThreshold = 1.5; // Spread Threshold (× normal spread)

// --- Logging ---
input bool EnableFileLogging = false;       // Enable CSV Journal
input bool ShowDashboard = true;            // Show Dashboard on Chart

//+------------------------------------------------------------------+
//| Trading State Enum                                                 |
//+------------------------------------------------------------------+
enum TradingState {
   STATE_NO_TRADE,      // 🔴 ROT: EMA zu nah, kein Trend, etc.
   STATE_TREND_FORMING, // 🟡 GELB: Swing erkannt, Trend vorhanden
   STATE_RETRACEMENT,   // 🟢 GRÜN: Preis retraced Richtung Fibo
   STATE_AT_FIB,        // 🔵 BLAU: Preis bei Fib 50-61.8%, warte auf Entry-Candle
   STATE_TRADE_TAKEN    // 🟣 VIOLETT: Trade aktiv (Position offen)
};

//+------------------------------------------------------------------+
//| Symbol State Struct                                                |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Symbol Array (25 Symbole)                                          |
//+------------------------------------------------------------------+
string symbols[] = {
   "EURJPY", "XAUUSD", "GBPJPY", "NZDJPY", "EURCAD",
   "EURCHF", "GBPCHF", "USDCAD", "AUDUSD", "USDCHF",
   "GBPNZD", "CADJPY", "AUDNZD", "NZDUSD", "GBPUSD",
   "EURNZD", "AUDCAD", "GBPCAD", "EURUSD", "USDJPY",
   "AUDJPY", "CHFJPY", "CADCHF", "GBPAUD", "EURAUD"
};

//+------------------------------------------------------------------+
//| Symbol States Array                                                |
//+------------------------------------------------------------------+
SymbolState symbolStates[25];

//+------------------------------------------------------------------+
//| Global Variables                                                   |
//+------------------------------------------------------------------+
double equityPeak = 0.0;
double currentDD = 0.0;
double currentRisk = 1.0;

// Account-specific global variable name for equity peak
string GetEquityPeakVarName()
{
   return "EA_EquityPeak_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
}

//+------------------------------------------------------------------+
//| Indicator Handles                                                  |
//+------------------------------------------------------------------+
int emaHandles[25];
int atrHandles[25];

//+------------------------------------------------------------------+
//| OnInit                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("SwingEA v1.0 initialized");

   // Initialize symbolStates
   for (int i = 0; i < ArraySize(symbols); i++) {
      symbolStates[i].symbol = symbols[i];
      symbolStates[i].state = STATE_NO_TRADE;
      symbolStates[i].lastSwingHigh = 0.0;
      symbolStates[i].lastSwingLow = 0.0;
      symbolStates[i].swingHighBar = 0;
      symbolStates[i].swingLowBar = 0;
      symbolStates[i].fib382 = 0.0;
      symbolStates[i].fib500 = 0.0;
      symbolStates[i].fib618 = 0.0;
      symbolStates[i].qualityScore = 0.0;
      symbolStates[i].lastUpdate = 0;
      symbolStates[i].isLongSetup = false;
   }

   // Create EMA200 handles for all symbols
   int emaSuccessCount = 0;
   for (int i = 0; i < ArraySize(symbols); i++) {
      // First ensure symbol is selected/available
      if (!SymbolSelect(symbols[i], true)) {
         Print("WARNING: Symbol not available: ", symbols[i], " - skipping");
         emaHandles[i] = INVALID_HANDLE;
         atrHandles[i] = INVALID_HANDLE;
         continue;
      }

      emaHandles[i] = iMA(symbols[i], PERIOD_H4, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);

      if (emaHandles[i] == INVALID_HANDLE) {
         Print("WARNING: EMA Handle failed for ", symbols[i], " - Error: ", GetLastError());
         continue;
      }
      emaSuccessCount++;
   }

   Print("EMA200 handles created: ", emaSuccessCount, "/", ArraySize(symbols), " symbols");

   // Create ATR(14) handles for all symbols
   int atrSuccessCount = 0;
   for (int i = 0; i < ArraySize(symbols); i++) {
      if (emaHandles[i] == INVALID_HANDLE) continue; // Skip if EMA failed

      atrHandles[i] = iATR(symbols[i], PERIOD_H4, ATR_Period);

      if (atrHandles[i] == INVALID_HANDLE) {
         Print("WARNING: ATR Handle failed for ", symbols[i], " - Error: ", GetLastError());
         continue;
      }
      atrSuccessCount++;
   }

   Print("ATR14 handles created: ", atrSuccessCount, "/", ArraySize(symbols), " symbols");

   // Check if we have at least some symbols working
   if (emaSuccessCount == 0 || atrSuccessCount == 0) {
      Print("WARNING: No symbols could be initialized on first try!");
      Print("This is often caused by missing history data or symbols not in Market Watch.");
      Print("The EA will continue to run and retry symbol initialization.");
      Print("Please ensure symbols are added to Market Watch and have H4 history data.");
      // Don't fail - allow EA to continue and retry later
   }

   if (emaSuccessCount < ArraySize(symbols)) {
      Print("WARNING: Not all symbols available. EA will trade on ", emaSuccessCount, " symbols.");
   }

   // Show initialization result on chart immediately
   if (emaSuccessCount == 0) {
      Comment("⚠️ SwingEA v1.0 - Initialization Warning\n\n" +
              "No symbols could be initialized!\n" +
              "Common causes:\n" +
              "1. Symbols not in Market Watch\n" +
              "2. Missing H4 history data\n" +
              "3. Broker doesn't support these symbols\n\n" +
              "Please add symbols to Market Watch and\n" +
              "ensure H4 data is available.\n\n" +
              "EA will retry on next timer event.");
   }

   // Validate all symbols
   ValidateAllSymbols();

   // Recover state from previous session (in case of restart/recompile)
   RecoverFromRestart();

   EventSetTimer(900); // 15 Min
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Log deinitialization reason
   string reasonText = "";
   switch(reason) {
      case REASON_PROGRAM:     reasonText = "Expert removed from chart"; break;
      case REASON_REMOVE:      reasonText = "Expert removed (ExpertRemove called)"; break;
      case REASON_RECOMPILE:   reasonText = "Expert recompiled"; break;
      case REASON_CHARTCHANGE: reasonText = "Chart symbol/period changed"; break;
      case REASON_CHARTCLOSE:  reasonText = "Chart closed"; break;
      case REASON_PARAMETERS:  reasonText = "Input parameters changed"; break;
      case REASON_ACCOUNT:     reasonText = "Account changed"; break;
      case REASON_TEMPLATE:    reasonText = "Template applied"; break;
      case REASON_INITFAILED:  reasonText = "OnInit() failed"; break;
      case REASON_CLOSE:       reasonText = "Terminal closing"; break;
      default:                 reasonText = "Unknown reason (" + IntegerToString(reason) + ")"; break;
   }

   Print("========================================");
   Print("SwingEA v1.0 deinitialized");
   Print("Reason: ", reasonText);
   Print("Reason Code: ", reason);
   Print("========================================");

   // Release all EMA handles
   for (int i = 0; i < ArraySize(emaHandles); i++) {
      IndicatorRelease(emaHandles[i]);
   }

   // Release all ATR handles
   for (int i = 0; i < ArraySize(atrHandles); i++) {
      IndicatorRelease(atrHandles[i]);
   }

   EventKillTimer();
}

//+------------------------------------------------------------------+
//| OnTimer                                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Step 0: Retry initialization for failed symbols (if any)
   RetryFailedSymbolInitialization();

   // Step 1: Check trading window
   if (!IsInTradingWindow()) {
      return;
   }

   Print("=== OnTimer: Trading Window Active ===");

   // Step 2: Update Trailing Drawdown
   UpdateTrailingDD();

   // Step 3: Scan all symbols and update states
   for (int i = 0; i < ArraySize(symbolStates); i++) {
      UpdateSymbolState(i);
   }

   // Step 4: Check for invalidations
   for (int i = 0; i < ArraySize(symbolStates); i++) {
      CheckForInvalidation(i);
   }

   // Step 5: Calculate quality scores for setups in AT_FIB state
   for (int i = 0; i < ArraySize(symbolStates); i++) {
      if (symbolStates[i].state == STATE_AT_FIB) {
         double score = CalculateQualityScore(i);
         symbolStates[i].qualityScore = score;
      }
   }

   // Step 6: Select top 2 setups by quality score
   int bestIndexes[];
   int selectedCount = SelectBestSetups(bestIndexes);

   // Step 7: Execute trades for selected setups
   for (int i = 0; i < selectedCount; i++) {
      if (!CanOpenNewPosition()) {
         Print("[OnTimer] Max positions reached, stopping trade execution");
         break;
      }

      int symbolIndex = bestIndexes[i];
      if (symbolStates[symbolIndex].state == STATE_AT_FIB) {
         // Check if entry candle is present
         if (HasEntryCandle(symbolStates[symbolIndex].symbol, symbolStates[symbolIndex].isLongSetup)) {
            OpenTrade(symbolIndex);
         }
      }
   }

   // Step 8: Update dashboard/comment
   UpdateDashboard();

   // DEBUG: State Distribution
   int countNO_TRADE = 0, countTREND = 0, countRETRACE = 0, countAT_FIB = 0, countTRADE = 0;
   for (int i = 0; i < ArraySize(symbolStates); i++) {
      switch (symbolStates[i].state) {
         case STATE_NO_TRADE: countNO_TRADE++; break;
         case STATE_TREND_FORMING: countTREND++; break;
         case STATE_RETRACEMENT: countRETRACE++; break;
         case STATE_AT_FIB: countAT_FIB++; break;
         case STATE_TRADE_TAKEN: countTRADE++; break;
      }
   }
   Print("[DEBUG] State Distribution - NO_TRADE:", countNO_TRADE, " TREND:", countTREND,
         " RETRACE:", countRETRACE, " AT_FIB:", countAT_FIB, " TRADE:", countTRADE);

   Print("=== OnTimer Complete ===");
}

//+------------------------------------------------------------------+
//| Helper Functions - Indicator Value Retrieval                      |
//+------------------------------------------------------------------+

/**
 * GetEMA - Retrieve EMA200 value for a symbol at a specific shift
 * @param symbol - Symbol name
 * @param shift - Candle shift (0 = current, 1 = previous, etc.)
 * @return EMA200 value or 0 if error
 */
double GetEMA(string symbol, int shift)
{
   int index = GetSymbolIndex(symbol);
   if (index < 0) return 0;

   // Check if handle is valid
   if (emaHandles[index] == INVALID_HANDLE) {
      return 0;
   }

   double buffer[1];
   if (CopyBuffer(emaHandles[index], 0, shift, 1, buffer) <= 0) {
      Print("ERROR: CopyBuffer failed for EMA, symbol: ", symbol, ", shift: ", shift, ", Error: ", GetLastError());
      return 0;
   }
   return buffer[0];
}

/**
 * GetATR - Retrieve ATR(14) value for a symbol at a specific shift
 * @param symbol - Symbol name
 * @param shift - Candle shift (0 = current, 1 = previous, etc.)
 * @return ATR value or 0 if error
 */
double GetATR(string symbol, int shift)
{
   int index = GetSymbolIndex(symbol);
   if (index < 0) return 0;

   // Check if handle is valid
   if (atrHandles[index] == INVALID_HANDLE) {
      return 0;
   }

   double buffer[1];
   if (CopyBuffer(atrHandles[index], 0, shift, 1, buffer) <= 0) {
      Print("ERROR: CopyBuffer failed for ATR, symbol: ", symbol, ", shift: ", shift, ", Error: ", GetLastError());
      return 0;
   }
   return buffer[0];
}

/**
 * GetSymbolIndex - Find array index of a symbol in the symbols array
 * @param symbol - Symbol name to search for
 * @return Array index (0-24) or -1 if not found
 */
int GetSymbolIndex(string symbol)
{
   for (int i = 0; i < ArraySize(symbols); i++) {
      if (symbols[i] == symbol) return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Swing Detection Functions – VERBESSERT                           |
//+------------------------------------------------------------------+

// einfacher, robuster Swing-Filter (keine ATR-Abstandslogik mehr)
bool IsSwingHigh(string symbol, int bar, int swingSize = 2)
{
   // brauchen links und rechts genug Kerzen
   if(bar < swingSize || bar + swingSize >= Bars(symbol, PERIOD_H4))
      return false;

   double h = iHigh(symbol, PERIOD_H4, bar);

   for(int i = 1; i <= swingSize; i++)
   {
      if(h <= iHigh(symbol, PERIOD_H4, bar - i)) return false;
      if(h <= iHigh(symbol, PERIOD_H4, bar + i)) return false;
   }
   return true;
}

bool IsSwingLow(string symbol, int bar, int swingSize = 2)
{
   if(bar < swingSize || bar + swingSize >= Bars(symbol, PERIOD_H4))
      return false;

   double l = iLow(symbol, PERIOD_H4, bar);

   for(int i = 1; i <= swingSize; i++)
   {
      if(l >= iLow(symbol, PERIOD_H4, bar - i)) return false;
      if(l >= iLow(symbol, PERIOD_H4, bar + i)) return false;
   }
   return true;
}

/**
 * UpdateSwings - VERBESSERT
 * - betrachtet nur die letzten 30 H4-Bars
 * - nimmt jeweils den jüngsten gültigen Swing High / Low
 * - KEINE Bedingung mehr "nur höheres Hoch / tieferes Tief"
 *   -> deutlich mehr Setups, näher an deiner Diskretion
 */
void UpdateSwings(string symbol)
{
   int symbolIndex = GetSymbolIndex(symbol);
   if(symbolIndex < 0) return;

   int barsTotal = Bars(symbol, PERIOD_H4);
   if(barsTotal < 10) return;

   int maxLookback = 30;
   int startBar = 2;
   int endBar = MathMin(maxLookback, barsTotal - 3);

   double lastHigh = 0.0;
   int lastHighBar = 0;
   double lastLow  = 0.0;
   int lastLowBar  = 0;

   // jüngste Swings finden (kleiner bar-index = näher an der Gegenwart)
   for(int i = startBar; i <= endBar; i++)
   {
      if(IsSwingHigh(symbol, i))
      {
         lastHigh = iHigh(symbol, PERIOD_H4, i);
         lastHighBar = i;
         break; // den jüngsten Swing nehmen
      }
   }

   for(int i = startBar; i <= endBar; i++)
   {
      if(IsSwingLow(symbol, i))
      {
         lastLow = iLow(symbol, PERIOD_H4, i);
         lastLowBar = i;
         break;
      }
   }

   bool changed = false;

   if(lastHigh > 0.0 && lastHighBar > 0)
   {
      if(lastHigh != symbolStates[symbolIndex].lastSwingHigh
         || lastHighBar != symbolStates[symbolIndex].swingHighBar)
      {
         symbolStates[symbolIndex].lastSwingHigh = lastHigh;
         symbolStates[symbolIndex].swingHighBar  = lastHighBar;
         Print("[", symbol, "] New Swing High: ", lastHigh, " (bar ", lastHighBar, ")");
         changed = true;
      }
   }

   if(lastLow > 0.0 && lastLowBar > 0)
   {
      if(lastLow != symbolStates[symbolIndex].lastSwingLow
         || lastLowBar != symbolStates[symbolIndex].swingLowBar)
      {
         symbolStates[symbolIndex].lastSwingLow = lastLow;
         symbolStates[symbolIndex].swingLowBar  = lastLowBar;
         Print("[", symbol, "] New Swing Low: ", lastLow, " (bar ", lastLowBar, ")");
         changed = true;
      }
   }

   if(changed)
      symbolStates[symbolIndex].lastUpdate = TimeCurrent();
}


//+------------------------------------------------------------------+
//| Fibonacci Functions                                              |
//+------------------------------------------------------------------+

/**
 * CalculateFibLevels - Calculate Fibonacci retracement levels (38.2%, 50%, 61.8%)
 * Based on specification Chapter 2.3
 *
 * For Long Setup (Retracement from High downward):
 * - fib382 = SwingHigh - 0.382 * range
 * - fib500 = SwingHigh - 0.500 * range
 * - fib618 = SwingHigh - 0.618 * range
 *
 * For Short Setup (Retracement from Low upward):
 * - fib382 = SwingLow + 0.382 * range
 * - fib500 = SwingLow + 0.500 * range
 * - fib618 = SwingLow + 0.618 * range
 *
 * @param symbolIndex - Index in symbolStates array
 */
void CalculateFibLevels(int symbolIndex)
{
   double swingHigh = symbolStates[symbolIndex].lastSwingHigh;
   double swingLow = symbolStates[symbolIndex].lastSwingLow;

   // Check if we have valid swing levels
   if (swingHigh <= 0 || swingLow <= 0) return;

   double range = swingHigh - swingLow;
   if (range <= 0) return;

   // For Long Setup: Price retraces from High down toward Low
   if (symbolStates[symbolIndex].isLongSetup) {
      symbolStates[symbolIndex].fib382 = swingHigh - 0.382 * range;
      symbolStates[symbolIndex].fib500 = swingHigh - 0.500 * range;
      symbolStates[symbolIndex].fib618 = swingHigh - 0.618 * range;

      Print("[", symbolStates[symbolIndex].symbol, "] Long Setup - Fib Levels calculated:");
      Print("  Fib 38.2%: ", symbolStates[symbolIndex].fib382);
      Print("  Fib 50.0%: ", symbolStates[symbolIndex].fib500);
      Print("  Fib 61.8%: ", symbolStates[symbolIndex].fib618);
   }
   // For Short Setup: Price retraces from Low up toward High
   else {
      symbolStates[symbolIndex].fib382 = swingLow + 0.382 * range;
      symbolStates[symbolIndex].fib500 = swingLow + 0.500 * range;
      symbolStates[symbolIndex].fib618 = swingLow + 0.618 * range;

      Print("[", symbolStates[symbolIndex].symbol, "] Short Setup - Fib Levels calculated:");
      Print("  Fib 38.2%: ", symbolStates[symbolIndex].fib382);
      Print("  Fib 50.0%: ", symbolStates[symbolIndex].fib500);
      Print("  Fib 61.8%: ", symbolStates[symbolIndex].fib618);
   }
}

/**
 * IsPriceAtFibZone - Check if current price is within Fibonacci retracement zone (38.2%-61.8%)
 * Based on specification Chapter 2.3 - Entry Zone
 *
 * For Long Setup:
 * - Entry zone: fib618 (lower) to fib382 (upper)
 * - Tolerance: ± Fib_Tolerance_ATR * ATR(14)
 *
 * For Short Setup:
 * - Entry zone: fib382 (lower) to fib618 (upper)
 * - Tolerance: ± Fib_Tolerance_ATR * ATR(14)
 *
 * @param symbolIndex - Index in symbolStates array
 * @return true if price is in Fib zone, false otherwise
 */
bool IsPriceAtFibZone(int symbolIndex)
{
   string symbol = symbolStates[symbolIndex].symbol;
   double currentPrice = iClose(symbol, PERIOD_H4, 0);
   double fib382 = symbolStates[symbolIndex].fib382;
   double fib618 = symbolStates[symbolIndex].fib618;
   double atr = GetATR(symbol, 0);

   // Check if we have valid Fib levels
   if (fib382 <= 0 || fib618 <= 0 || atr <= 0) return false;

   double tolerance = Fib_Tolerance_ATR * atr;

   // For Long Setup: Price between fib618 (bottom) and fib382 (top) with tolerance
   if (symbolStates[symbolIndex].isLongSetup) {
      bool inZone = (currentPrice >= fib618 - tolerance && currentPrice <= fib382 + tolerance);

      if (inZone) {
         Print("[", symbol, "] Price AT FIB ZONE (Long): ", currentPrice,
               " (between ", fib618 - tolerance, " and ", fib382 + tolerance, ")");
      }

      return inZone;
   }
   // For Short Setup: Price between fib382 (bottom) and fib618 (top) with tolerance
   else {
      bool inZone = (currentPrice <= fib618 + tolerance && currentPrice >= fib382 - tolerance);

      if (inZone) {
         Print("[", symbol, "] Price AT FIB ZONE (Short): ", currentPrice,
               " (between ", fib382 - tolerance, " and ", fib618 + tolerance, ")");
      }

      return inZone;
   }
}

//+------------------------------------------------------------------+
//| Trend Filter Functions                                           |
//+------------------------------------------------------------------+

/**
 * IsEMATrendValid - Check if price position relative to EMA200 is valid for trading
 * Based on specification Chapter 2.1 - Trend Filter
 *
 * Long Setup Requirements:
 * - Price > EMA200 (current)
 * - EMA200 rising (EMA200[0] > EMA200[5])
 * - Price distance from EMA200 >= MinEMADistance_ATR * ATR(14)
 *
 * Short Setup Requirements:
 * - Price < EMA200 (current)
 * - EMA200 falling (EMA200[0] < EMA200[5])
 * - Price distance from EMA200 >= MinEMADistance_ATR * ATR(14)
 *
 * @param symbol - Symbol to check
 * @param isLong - true for long setup, false for short
 * @return true if trend is valid for the setup type, false otherwise
 */
bool IsEMATrendValid(string symbol, bool isLong)
{
   double ema0 = GetEMA(symbol, 0);   // Current EMA
   double ema5 = GetEMA(symbol, 5);   // 5 bars ago
   double price = iClose(symbol, PERIOD_H4, 0);
   double atr = GetATR(symbol, 0);

   // Validate values
   if (ema0 <= 0 || ema5 <= 0 || price <= 0 || atr <= 0) return false;

   double distance = MathAbs(price - ema0);
   double minDistance = MinEMADistance_ATR * atr;

   // Check minimum distance requirement
   if (distance < minDistance) {
      Print("[", symbol, "] EMA distance too close: ", distance, " < ", minDistance);
      return false;
   }

   // Long Setup: Price above EMA and EMA rising
   if (isLong) {
      bool priceAboveEMA = (price > ema0);
      bool emaRising = (ema0 > ema5);

      if (priceAboveEMA && emaRising) {
         Print("[", symbol, "] LONG TREND VALID - Price: ", price, " above EMA: ", ema0, ", EMA rising");
         return true;
      }

      if (!priceAboveEMA) {
         Print("[", symbol, "] LONG INVALID - Price below EMA (", price, " < ", ema0, ")");
      }
      if (!emaRising) {
         Print("[", symbol, "] LONG INVALID - EMA falling/flat (", ema0, " <= ", ema5, ")");
      }

      return false;
   }
   // Short Setup: Price below EMA and EMA falling
   else {
      bool priceBelowEMA = (price < ema0);
      bool emaFalling = (ema0 < ema5);

      if (priceBelowEMA && emaFalling) {
         Print("[", symbol, "] SHORT TREND VALID - Price: ", price, " below EMA: ", ema0, ", EMA falling");
         return true;
      }

      if (!priceBelowEMA) {
         Print("[", symbol, "] SHORT INVALID - Price above EMA (", price, " > ", ema0, ")");
      }
      if (!emaFalling) {
         Print("[", symbol, "] SHORT INVALID - EMA rising/flat (", ema0, " >= ", ema5, ")");
      }

      return false;
   }
}

/**
 * Check1DTrend - Check 1D EMA200 trend for Multi-Timeframe validation
 * Based on specification Chapter 3.3 - Multi-Timeframe Alignment
 *
 * Scoring System:
 * - Return -1: Hard Reject (1D trend against 4H setup)
 * - Return 1: Neutral (1D trend doesn't confirm but doesn't contradict)
 * - Return 2: Perfect Alignment (1D trend aligned with 4H setup)
 *
 * For Long Setup (4H):
 * - If 1D Downtrend (Price < EMA200 falling): return -1 (Hard Reject)
 * - If 1D Uptrend (Price > EMA200 rising): return 2 (Perfect Alignment)
 * - Otherwise: return 1 (Neutral)
 *
 * For Short Setup (4H):
 * - If 1D Uptrend (Price > EMA200 rising): return -1 (Hard Reject)
 * - If 1D Downtrend (Price < EMA200 falling): return 2 (Perfect Alignment)
 * - Otherwise: return 1 (Neutral)
 *
 * @param symbol - Symbol to check
 * @param is4H_Long - true if 4H setup is Long, false if Short
 * @return -1 (reject), 1 (neutral), or 2 (perfect alignment)
 */
int Check1DTrend(string symbol, bool is4H_Long)
{
   // Create EMA200 handle for 1D timeframe
   int ema1D_Handle = iMA(symbol, PERIOD_D1, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   if (ema1D_Handle == INVALID_HANDLE) {
      Print("[", symbol, "] ERROR: Failed to create 1D EMA handle");
      return 0; // Neutral on error
   }

   // Copy EMA values from 1D chart (current and 1 bar ago)
   double ema1D_buffer[2];
   if (CopyBuffer(ema1D_Handle, 0, 0, 2, ema1D_buffer) <= 0) {
      Print("[", symbol, "] ERROR: Failed to copy 1D EMA buffer");
      IndicatorRelease(ema1D_Handle);
      return 0; // Neutral on error
   }

   double ema1D_0 = ema1D_buffer[0];   // Current 1D EMA
   double ema1D_1 = ema1D_buffer[1];   // Previous 1D EMA
   double price1D = iClose(symbol, PERIOD_D1, 0);

   // Release the temporary handle
   IndicatorRelease(ema1D_Handle);

   // Validate values
   if (ema1D_0 <= 0 || ema1D_1 <= 0 || price1D <= 0) {
      return 0; // Neutral on invalid data
   }

   // Determine 1D trend
   bool uptrend1D = (price1D > ema1D_0 && ema1D_0 > ema1D_1);
   bool downtrend1D = (price1D < ema1D_0 && ema1D_0 < ema1D_1);

   // For Long Setup (4H):
   if (is4H_Long) {
      if (downtrend1D) {
         Print("[", symbol, "] 1D Downtrend detected - HARD REJECT for Long setup");
         return -1; // Hard Reject
      }
      if (uptrend1D) {
         Print("[", symbol, "] 1D Uptrend detected - PERFECT ALIGNMENT for Long setup");
         return 2; // Perfect Alignment
      }
      Print("[", symbol, "] 1D Trend Neutral for Long setup");
      return 1; // Neutral
   }
   // For Short Setup (4H):
   else {
      if (uptrend1D) {
         Print("[", symbol, "] 1D Uptrend detected - HARD REJECT for Short setup");
         return -1; // Hard Reject
      }
      if (downtrend1D) {
         Print("[", symbol, "] 1D Downtrend detected - PERFECT ALIGNMENT for Short setup");
         return 2; // Perfect Alignment
      }
      Print("[", symbol, "] 1D Trend Neutral for Short setup");
      return 1; // Neutral
   }
}

//+------------------------------------------------------------------+
//| Candlestick Pattern Detection Functions                          |
//+------------------------------------------------------------------+

/**
 * IsBullishRejection - Detect Bullish Rejection Candle (Pin Bar)
 * Based on specification Chapter 2.4 - Rejection Candle
 *
 * Bullish Rejection Criteria (for Long entries):
 * - Lower Wick >= 1.8 × Body
 * - Upper Wick <= 0.3 × Candle Height
 * - Close > Open (bullish candle)
 * - Close >= Low + 0.67 × Candle Height (close in upper 1/3)
 *
 * Calculations:
 * - Body = abs(Close - Open)
 * - LowerWick = min(Open, Close) - Low
 * - UpperWick = High - max(Open, Close)
 * - CandleHeight = High - Low
 *
 * @param symbol - Symbol to check
 * @param bar - Bar index to check
 * @return true if bullish rejection detected, false otherwise
 */
bool IsBullishRejection(string symbol, int bar)
{
   double open = iOpen(symbol, PERIOD_H4, bar);
   double close = iClose(symbol, PERIOD_H4, bar);
   double high = iHigh(symbol, PERIOD_H4, bar);
   double low = iLow(symbol, PERIOD_H4, bar);

   double body = MathAbs(close - open);
   double lowerWick = MathMin(open, close) - low;
   double upperWick = high - MathMax(open, close);
   double candleHeight = high - low;

   // Validate candle (must have some height)
   if (candleHeight <= 0) return false;

   // Rejection Criteria - GELOCKERT von 1.8x auf 1.5x
   if (lowerWick < 1.5 * body) return false;        // Lower wick not long enough
   if (upperWick > 0.3 * candleHeight) return false; // Upper wick too long
   if (close <= open) return false;                  // Must be bullish
   if (close < low + 0.67 * candleHeight) return false; // Close not in upper 1/3

   Print("[", symbol, "] Bullish Rejection detected at bar ", bar,
         " | Open: ", open, " Close: ", close, " Body: ", body, " LowerWick: ", lowerWick);

   return true;
}

/**
 * IsBearishRejection - Detect Bearish Rejection Candle (Pin Bar)
 * Based on specification Chapter 2.4 - Rejection Candle
 *
 * Bearish Rejection Criteria (for Short entries):
 * - Upper Wick >= 1.8 × Body
 * - Lower Wick <= 0.3 × Candle Height
 * - Close < Open (bearish candle)
 * - Close <= High - 0.67 × Candle Height (close in lower 1/3)
 *
 * @param symbol - Symbol to check
 * @param bar - Bar index to check
 * @return true if bearish rejection detected, false otherwise
 */
bool IsBearishRejection(string symbol, int bar)
{
   double open = iOpen(symbol, PERIOD_H4, bar);
   double close = iClose(symbol, PERIOD_H4, bar);
   double high = iHigh(symbol, PERIOD_H4, bar);
   double low = iLow(symbol, PERIOD_H4, bar);

   double body = MathAbs(close - open);
   double lowerWick = MathMin(open, close) - low;
   double upperWick = high - MathMax(open, close);
   double candleHeight = high - low;

   // Validate candle (must have some height)
   if (candleHeight <= 0) return false;

   // Rejection Criteria (inverse of bullish) - GELOCKERT von 1.8x auf 1.5x
   if (upperWick < 1.5 * body) return false;        // Upper wick not long enough
   if (lowerWick > 0.3 * candleHeight) return false; // Lower wick too long
   if (close >= open) return false;                  // Must be bearish
   if (close > high - 0.67 * candleHeight) return false; // Close not in lower 1/3

   Print("[", symbol, "] Bearish Rejection detected at bar ", bar,
         " | Open: ", open, " Close: ", close, " Body: ", body, " UpperWick: ", upperWick);

   return true;
}

/**
 * IsBullishEngulfing - Detect Bullish Engulfing Candle
 * Based on specification Chapter 2.4 - Engulfing Candle
 *
 * Bullish Engulfing Criteria (for Long entries):
 * - Current candle (bar 0) is bullish: Close[0] > Open[0]
 * - Previous candle (bar 1) is bearish: Close[1] < Open[1]
 * - Body of current >= 1.2 × abs(Body of previous)
 * - Open[0] <= Close[1] (current opens at or below previous close)
 * - Close[0] >= Open[1] (current closes at or above previous open)
 *
 * @param symbol - Symbol to check
 * @return true if bullish engulfing detected, false otherwise
 */
bool IsBullishEngulfing(string symbol)
{
   double open0 = iOpen(symbol, PERIOD_H4, 0);
   double close0 = iClose(symbol, PERIOD_H4, 0);
   double open1 = iOpen(symbol, PERIOD_H4, 1);
   double close1 = iClose(symbol, PERIOD_H4, 1);

   double body0 = close0 - open0;
   double body1 = MathAbs(close1 - open1);

   // Criteria
   if (body0 <= 0) return false;                  // Candle 0 must be bullish
   if (close1 >= open1) return false;             // Candle 1 must be bearish
   if (body0 < 1.2 * body1) return false;         // Engulfing size requirement
   if (open0 > close1) return false;              // Open position check
   if (close0 < open1) return false;              // Close position check

   Print("[", symbol, "] Bullish Engulfing detected",
         " | Prev Body: ", body1, " Current Body: ", body0);

   return true;
}

/**
 * IsBearishEngulfing - Detect Bearish Engulfing Candle
 * Based on specification Chapter 2.4 - Engulfing Candle
 *
 * Bearish Engulfing Criteria (for Short entries):
 * - Current candle (bar 0) is bearish: Close[0] < Open[0]
 * - Previous candle (bar 1) is bullish: Close[1] > Open[1]
 * - Body of current >= 1.2 × abs(Body of previous)
 * - Open[0] >= Close[1] (current opens at or above previous close)
 * - Close[0] <= Open[1] (current closes at or below previous open)
 *
 * @param symbol - Symbol to check
 * @return true if bearish engulfing detected, false otherwise
 */
bool IsBearishEngulfing(string symbol)
{
   double open0 = iOpen(symbol, PERIOD_H4, 0);
   double close0 = iClose(symbol, PERIOD_H4, 0);
   double open1 = iOpen(symbol, PERIOD_H4, 1);
   double close1 = iClose(symbol, PERIOD_H4, 1);

   double body0 = open0 - close0;  // Bearish body (open - close)
   double body1 = MathAbs(close1 - open1);

   // Criteria (inverse of bullish)
   if (body0 <= 0) return false;                  // Candle 0 must be bearish
   if (close1 <= open1) return false;             // Candle 1 must be bullish
   if (body0 < 1.2 * body1) return false;         // Engulfing size requirement
   if (open0 < close1) return false;              // Open position check
   if (close0 > open1) return false;              // Close position check

   Print("[", symbol, "] Bearish Engulfing detected",
         " | Prev Body: ", body1, " Current Body: ", body0);

   return true;
}

//+------------------------------------------------------------------+
//| State Machine Functions                                          |
//+------------------------------------------------------------------+

/**
 * HasValidSwing - Check if symbol has valid swing levels
 * @param symbolIndex - Index in symbolStates array
 * @return true if both swing high and swing low are set
 */
bool HasValidSwing(int symbolIndex)
{
   return (symbolStates[symbolIndex].lastSwingHigh > 0 &&
           symbolStates[symbolIndex].lastSwingLow > 0);
}

/**
 * HasEntryCandle - Check if entry candle (Rejection or Engulfing) appears
 * @param symbol - Symbol to check
 * @param isLong - true for long setup, false for short
 * @return true if valid entry candle detected
 */
bool HasEntryCandle(string symbol, bool isLong)
{
   if (isLong) {
      // For long: look for Bullish Rejection or Bullish Engulfing
      return (IsBullishRejection(symbol, 0) || IsBullishEngulfing(symbol));
   } else {
      // For short: look for Bearish Rejection or Bearish Engulfing
      return (IsBearishRejection(symbol, 0) || IsBearishEngulfing(symbol));
   }
}

/**
 * IsPriceRetracing - Check if price is moving toward Fibonacci levels
 * For Long: Price should be moving down toward fib618
 * For Short: Price should be moving up toward fib618
 *
 * @param symbolIndex - Index in symbolStates array
 * @return true if price is retracing toward fib zone
 */
bool IsPriceRetracing(int symbolIndex)
{
   string symbol = symbolStates[symbolIndex].symbol;
   double currentPrice = iClose(symbol, PERIOD_H4, 0);
   double previousPrice = iClose(symbol, PERIOD_H4, 1);

   if (symbolStates[symbolIndex].isLongSetup) {
      // For long: price should be moving down (price < previous price)
      // AND price should be between swing high and fib618
      double swingHigh = symbolStates[symbolIndex].lastSwingHigh;
      double fib618 = symbolStates[symbolIndex].fib618;

      if (fib618 <= 0) return false;

      return (currentPrice < previousPrice &&
              currentPrice < swingHigh &&
              currentPrice > fib618);
   } else {
      // For short: price should be moving up (price > previous price)
      // AND price should be between swing low and fib618
      double swingLow = symbolStates[symbolIndex].lastSwingLow;
      double fib618 = symbolStates[symbolIndex].fib618;

      if (fib618 <= 0) return false;

      return (currentPrice > previousPrice &&
              currentPrice > swingLow &&
              currentPrice < fib618);
   }
}

/**
 * UpdateSymbolState - Update trading state based on conditions
 * Implements the state machine transitions from specification Chapter 3.2
 *
 * State Transitions:
 * NO_TRADE → TREND_FORMING: Valid swing + EMA filter OK
 * TREND_FORMING → RETRACEMENT: Price moving toward Fib levels
 * RETRACEMENT → AT_FIB: Price reaches 50-61.8% zone
 * AT_FIB → TRADE_TAKEN: Entry candle appears
 * TRADE_TAKEN → NO_TRADE: Position closed
 *
 * @param symbolIndex - Index in symbolStates array
 */
void UpdateSymbolState(int symbolIndex)
{
   string symbol = symbolStates[symbolIndex].symbol;
   TradingState currentState = symbolStates[symbolIndex].state;

   // State-Transition-Logik
   switch (currentState) {
      case STATE_NO_TRADE:
         {
            // NEU: Swings aktualisieren mit der neuen Logik
            UpdateSwings(symbol);

            if(!HasValidSwing(symbolIndex))
               break;

            // Try Long Setup
            if(IsEMATrendValid(symbol, true))
            {
               symbolStates[symbolIndex].isLongSetup = true;
               symbolStates[symbolIndex].state = STATE_TREND_FORMING;
               Print("[", symbol, "] → STATE_TREND_FORMING (Long)");
               break;
            }

            // Try Short Setup
            if(IsEMATrendValid(symbol, false))
            {
               symbolStates[symbolIndex].isLongSetup = false;
               symbolStates[symbolIndex].state = STATE_TREND_FORMING;
               Print("[", symbol, "] → STATE_TREND_FORMING (Short)");
               break;
            }

            break;
         }


      case STATE_TREND_FORMING: {
         // Calculate Fibonacci levels once we're in trend forming state
         CalculateFibLevels(symbolIndex);

         // Check if price is retracing toward Fib levels
         if (IsPriceRetracing(symbolIndex)) {
            symbolStates[symbolIndex].state = STATE_RETRACEMENT;
            Print("[", symbol, "] → STATE_RETRACEMENT");
         }

         break;
      }

      case STATE_RETRACEMENT: {
         // Check if price has reached the Fib zone (50%-61.8%)
         if (IsPriceAtFibZone(symbolIndex)) {
            symbolStates[symbolIndex].state = STATE_AT_FIB;
            Print("[", symbol, "] → STATE_AT_FIB");
         }

         break;
      }

      case STATE_AT_FIB: {
         // Check if entry candle (Rejection/Engulfing) appears
         if (HasEntryCandle(symbol, symbolStates[symbolIndex].isLongSetup)) {
            Print("[", symbol, "] Entry Candle detected - Ready for trade execution");
            // Note: Actual trade execution happens in ExecuteTrades() function
            // State transition to TRADE_TAKEN happens after trade is opened
         }

         break;
      }

      case STATE_TRADE_TAKEN: {
         // Check if position is still open
         // This will be handled in the main trading loop
         // For now, just monitor the open position

         break;
      }

      default: {
         break;
      }
   }

   // Update lastUpdate timestamp
   symbolStates[symbolIndex].lastUpdate = TimeCurrent();
}

//+------------------------------------------------------------------+
//| CheckForInvalidation – VERBESSERT                                |
//+------------------------------------------------------------------+

void CheckForInvalidation(int symbolIndex)
{
   string symbol = symbolStates[symbolIndex].symbol;
   TradingState currentState = symbolStates[symbolIndex].state;

   // Wenn Trade läuft, nichts invalidieren
   if(currentState == STATE_TRADE_TAKEN)
      return;

   // alte Swings merken
   double prevHigh = symbolStates[symbolIndex].lastSwingHigh;
   double prevLow  = symbolStates[symbolIndex].lastSwingLow;

   // Swings updaten (mit der neuen, lockereren Logik)
   UpdateSwings(symbol);

   double newHigh = symbolStates[symbolIndex].lastSwingHigh;
   double newLow  = symbolStates[symbolIndex].lastSwingLow;

   bool swingChanged = (prevHigh != newHigh || prevLow != newLow);

   // EMA-Trend checken
   bool isLong = symbolStates[symbolIndex].isLongSetup;

   // EMA-Trend ist der wichtigste Invalidation-Trigger
   if(currentState != STATE_NO_TRADE && currentState != STATE_TRADE_TAKEN)
   {
      if(!IsEMATrendValid(symbol, isLong))
      {
         Print("[", symbol, "] Setup invalidated - EMA trend no longer valid");
         symbolStates[symbolIndex].state = STATE_NO_TRADE;
         symbolStates[symbolIndex].fib382 = 0.0;
         symbolStates[symbolIndex].fib500 = 0.0;
         symbolStates[symbolIndex].fib618 = 0.0;
         symbolStates[symbolIndex].qualityScore = 0.0;
         symbolStates[symbolIndex].isLongSetup = false;
         return;
      }
   }

   // Swings ändern sich permanent – wir invalidieren NICHT mehr sofort bei jedem neuen Swing.
   // Optional: Nur invalidieren, wenn Swing klar GEGEN das Setup geht.
   if(swingChanged && currentState >= STATE_TREND_FORMING && currentState <= STATE_AT_FIB)
   {
      double price = iClose(symbol, PERIOD_H4, 0);

      if(isLong)
      {
         // Long-Setup: wenn neuer Low-Swing klar unter altem Low liegt und Preis darunter,
         // kann Setup als zerstört gelten
         if(prevLow > 0 && newLow < prevLow && price < prevLow)
         {
            Print("[", symbol, "] Setup invalidated - new lower low against long setup");
            symbolStates[symbolIndex].state = STATE_NO_TRADE;
            symbolStates[symbolIndex].fib382 = 0.0;
            symbolStates[symbolIndex].fib500 = 0.0;
            symbolStates[symbolIndex].fib618 = 0.0;
            symbolStates[symbolIndex].qualityScore = 0.0;
            symbolStates[symbolIndex].isLongSetup = false;
            return;
         }
      }
      else
      {
         // Short-Setup: wenn neuer High-Swing klar über altem High liegt und Preis darüber
         if(prevHigh > 0 && newHigh > prevHigh && price > prevHigh)
         {
            Print("[", symbol, "] Setup invalidated - new higher high against short setup");
            symbolStates[symbolIndex].state = STATE_NO_TRADE;
            symbolStates[symbolIndex].fib382 = 0.0;
            symbolStates[symbolIndex].fib500 = 0.0;
            symbolStates[symbolIndex].fib618 = 0.0;
            symbolStates[symbolIndex].qualityScore = 0.0;
            symbolStates[symbolIndex].isLongSetup = false;
            return;
         }
      }
   }

   // wenn nichts davon greift → Setup bleibt bestehen
   symbolStates[symbolIndex].lastUpdate = TimeCurrent();
}


//+------------------------------------------------------------------+
//| Quality Scoring Functions                                        |
//+------------------------------------------------------------------+

/**
 * CalculateQualityScore - Calculate overall quality score for a setup
 * Based on specification Chapter 3.3 - Quality-Scoring System
 *
 * Score Components (max 100 points):
 * 1. Multi-Timeframe Alignment (0-30): 1D trend check
 * 2. EMA200 Distance (0-20): Distance from price to EMA
 * 3. Fibonacci Precision (0-20): How close to ideal 61.8% level
 * 4. Candlestick Pattern (0-20): Quality of entry pattern
 * 5. Swing Structure (0-10): Clean HH/LL without noise
 *
 * @param symbolIndex - Index in symbolStates array
 * @return Quality score (0-100)
 */
double CalculateQualityScore(int symbolIndex)
{
   double score = 0.0;
   string symbol = symbolStates[symbolIndex].symbol;
   bool isLong = symbolStates[symbolIndex].isLongSetup;

   // 1. Multi-Timeframe Alignment (0-30)
   int mtfResult = Check1DTrend(symbol, isLong);
   if (mtfResult == -1) {
      Print("[", symbol, "] Quality Score = 0 (Hard Reject on 1D)");
      return 0; // Hard Reject - cannot trade this setup
   }
   if (mtfResult == 2) {
      score += 30; // Perfect alignment
   } else if (mtfResult == 1) {
      score += 15; // Neutral (still OK)
   }

   // 2. EMA200 Distance (0-20)
   double ema0 = GetEMA(symbol, 0);
   double price = iClose(symbol, PERIOD_H4, 0);
   double atr = GetATR(symbol, 0);

   if (ema0 > 0 && atr > 0) {
      double distance_in_ATR = MathAbs(price - ema0) / atr;

      if (distance_in_ATR >= 2.0) {
         score += 20;
      } else if (distance_in_ATR >= 1.5) {
         score += 15;
      } else if (distance_in_ATR >= 1.0) {
         score += 10;
      }
   }

   // 3. Fibonacci Precision (0-20)
   double fib618 = symbolStates[symbolIndex].fib618;
   double fib50 = symbolStates[symbolIndex].fib500;

   if (fib618 > 0 && fib50 > 0 && atr > 0) {
      double targetLevel = fib618;
      double distanceToIdeal = MathAbs(price - targetLevel) / atr;

      if (distanceToIdeal <= 0.05) {
         score += 20;
      } else if (distanceToIdeal <= 0.1) {
         score += 15;
      } else if (distanceToIdeal <= 0.15) {
         score += 10;
      } else {
         score += 5;
      }
   }

   // 4. Candlestick Pattern Quality (0-20)
   // Check for recent entry candle
   if (HasEntryCandle(symbol, isLong)) {
      if (isLong) {
         if (IsBullishRejection(symbol, 0)) {
            double open = iOpen(symbol, PERIOD_H4, 0);
            double close = iClose(symbol, PERIOD_H4, 0);
            double body = close - open;
            double low = iLow(symbol, PERIOD_H4, 0);
            double lowerWick = MathMin(open, close) - low;
            double wickRatio = (body > 0) ? lowerWick / body : 0;

            if (wickRatio >= 2.5) {
               score += 20;
            } else if (wickRatio >= 2.0) {
               score += 15;
            } else if (wickRatio >= 1.8) {
               score += 10;
            }
         } else if (IsBullishEngulfing(symbol)) {
            double open0 = iOpen(symbol, PERIOD_H4, 0);
            double close0 = iClose(symbol, PERIOD_H4, 0);
            double open1 = iOpen(symbol, PERIOD_H4, 1);
            double close1 = iClose(symbol, PERIOD_H4, 1);
            double engulfSize = (close1 != open1) ? (close0 - open0) / MathAbs(close1 - open1) : 1.2;

            if (engulfSize >= 1.5) {
               score += 20;
            } else if (engulfSize >= 1.2) {
               score += 15;
            } else {
               score += 10;
            }
         }
      } else {
         if (IsBearishRejection(symbol, 0)) {
            double open = iOpen(symbol, PERIOD_H4, 0);
            double close = iClose(symbol, PERIOD_H4, 0);
            double body = open - close;
            double high = iHigh(symbol, PERIOD_H4, 0);
            double upperWick = high - MathMax(open, close);
            double wickRatio = (body > 0) ? upperWick / body : 0;

            if (wickRatio >= 2.5) {
               score += 20;
            } else if (wickRatio >= 2.0) {
               score += 15;
            } else if (wickRatio >= 1.8) {
               score += 10;
            }
         } else if (IsBearishEngulfing(symbol)) {
            double open0 = iOpen(symbol, PERIOD_H4, 0);
            double close0 = iClose(symbol, PERIOD_H4, 0);
            double open1 = iOpen(symbol, PERIOD_H4, 1);
            double close1 = iClose(symbol, PERIOD_H4, 1);
            double engulfSize = (close1 != open1) ? (open0 - close0) / MathAbs(close1 - open1) : 1.2;

            if (engulfSize >= 1.5) {
               score += 20;
            } else if (engulfSize >= 1.2) {
               score += 15;
            } else {
               score += 10;
            }
         }
      }
   }

   // 5. Swing Structure Quality (0-10)
   // For now, assume clean structure if swings are set
   if (HasValidSwing(symbolIndex)) {
      score += 10; // Assume clean structure for MVP
   }

   // Ensure score is within bounds
   if (score > 100) score = 100;
   if (score < 0) score = 0;

   symbolStates[symbolIndex].qualityScore = score;

   Print("[", symbol, "] Quality Score: ", DoubleToString(score, 1), " (MTF: ", mtfResult, ")");

   return score;
}

/**
 * Helper Struct for sorting setups by score
 */
struct SetupScore {
   int symbolIndex;
   double score;
};

/**
 * SelectBestSetups - Select top 2 setups by quality score
 * Based on specification Chapter 3.4 - Setup Selection
 *
 * Process:
 * 1. Scan all symbols in STATE_AT_FIB
 * 2. Calculate quality score for each
 * 3. Filter by MinQualityScore threshold
 * 4. Sort by score (highest first)
 * 5. Return top 2 indices
 *
 * @param bestIndexes - Array to receive top 2 indices
 * @return Number of setups selected (0-2)
 */
int SelectBestSetups(int &bestIndexes[])
{
   // Clear output array
   ArrayResize(bestIndexes, 0);

   // Temporary array to hold scored setups
   SetupScore scoredSetups[];
   int setupCount = 0;

   // Collect all setups in AT_FIB state with scores
   for (int i = 0; i < ArraySize(symbolStates); i++) {
      if (symbolStates[i].state == STATE_AT_FIB) {
         double score = CalculateQualityScore(i);

         // Only include if above minimum threshold
         if (score >= MinQualityScore) {
            ArrayResize(scoredSetups, setupCount + 1);
            scoredSetups[setupCount].symbolIndex = i;
            scoredSetups[setupCount].score = score;
            setupCount++;
         }
      }
   }

   if (setupCount == 0) {
      Print("[SelectBestSetups] No setups with score >= ", MinQualityScore);
      return 0;
   }

   // Simple bubble sort (highest scores first)
   for (int i = 0; i < setupCount - 1; i++) {
      for (int j = 0; j < setupCount - i - 1; j++) {
         if (scoredSetups[j].score < scoredSetups[j + 1].score) {
            // Swap
            SetupScore temp = scoredSetups[j];
            scoredSetups[j] = scoredSetups[j + 1];
            scoredSetups[j + 1] = temp;
         }
      }
   }

   // Select top 2
   int selectedCount = (setupCount < 2) ? setupCount : 2;

   for (int i = 0; i < selectedCount; i++) {
      ArrayResize(bestIndexes, i + 1);
      bestIndexes[i] = scoredSetups[i].symbolIndex;

      Print("[SelectBestSetups] #", i + 1, ": ",
            symbolStates[scoredSetups[i].symbolIndex].symbol,
            " - Score: ", DoubleToString(scoredSetups[i].score, 1));
   }

   Print("[SelectBestSetups] Selected ", selectedCount, " setups");

   return selectedCount;
}

//+------------------------------------------------------------------+
//| Risk Management Functions                                        |
//+------------------------------------------------------------------+

/**
 * UpdateTrailingDD - Update trailing drawdown and adjust risk
 * Based on specification Chapter 4.1 - Trailing Drawdown Model
 *
 * Drawdown Calculation:
 * - Track equity peak (maximum reached)
 * - Calculate DD = (Peak - Current) / Peak * 100%
 * - Dynamically adjust risk based on DD level
 *
 * Risk Adjustment:
 * - DD < 3.0%: Risk = RiskPercent_Normal (1.0%)
 * - DD 3.0-4.0%: Risk = RiskPercent_Medium (0.5%)
 * - DD >= 4.0%: Risk = RiskPercent_High (0.25%)
 * - DD >= MaxDrawdownPercent: EMERGENCY STOP (4.0%)
 *
 * @return void (updates global: equityPeak, currentDD, currentRisk)
 */
void UpdateTrailingDD()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   // Initialize or update equity peak
   if (!GlobalVariableCheck(GetEquityPeakVarName())) {
      // First time initialization
      GlobalVariableSet(GetEquityPeakVarName(), equity);
      equityPeak = equity;
      currentDD = 0.0;
      currentRisk = RiskPercent_Normal;
      Print("[TrailingDD] EA Initialized | Peak: ", equity, " | Risk: ", currentRisk, "%");
      return;
   }

   // Get peak from global variable
   equityPeak = GlobalVariableGet(GetEquityPeakVarName());

   // Update peak if current equity is higher
   if (equity > equityPeak) {
      equityPeak = equity;
      GlobalVariableSet(GetEquityPeakVarName(), equityPeak);
      currentDD = 0.0;
      currentRisk = RiskPercent_Normal;
      Print("[TrailingDD] NEW PEAK | Peak: ", equity, " | Risk: ", currentRisk, "%");
      return;
   }

   // Calculate drawdown
   if (equityPeak > 0) {
      currentDD = ((equityPeak - equity) / equityPeak) * 100.0;
   } else {
      currentDD = 0.0;
   }

   // Adjust risk based on drawdown level
   if (currentDD >= MaxDrawdownPercent) {
      // Emergency stop
      Print("========================================");
      Print("[TrailingDD] ⚠️ EMERGENCY STOP TRIGGERED!");
      Print("[TrailingDD] Current Drawdown: ", DoubleToString(currentDD, 2), "%");
      Print("[TrailingDD] Max Allowed DD: ", DoubleToString(MaxDrawdownPercent, 2), "%");
      Print("[TrailingDD] Equity Peak: ", DoubleToString(equityPeak, 2));
      Print("[TrailingDD] Current Equity: ", DoubleToString(equity, 2));
      Print("[TrailingDD] Closing all positions and removing EA...");
      Print("========================================");

      Comment("EMERGENCY STOP | Max Drawdown Reached: ", DoubleToString(currentDD, 2), "%");

      // Close all positions
      CloseAllPositions();

      // Stop the EA
      ExpertRemove();
      return;
   } else if (currentDD >= 3.0) {
      currentRisk = RiskPercent_High;   // 0.25% bei DD 3-10%
   } else if (currentDD >= 2.0) {
      currentRisk = RiskPercent_Medium; // 0.5% bei DD 2-3%
   } else {
      currentRisk = RiskPercent_Normal; // 1.0% bei DD 0-2%
   }

   // Log DD update with more details
   Print("[TrailingDD] Equity Peak: ", DoubleToString(equityPeak, 2),
         " | Current: ", DoubleToString(equity, 2),
         " | DD: ", DoubleToString(currentDD, 2), "% | Risk: ", currentRisk, "%");
}

/**
 * CloseAllPositions - Close all open positions from this EA
 * Used in emergency stop situations
 */
void CloseAllPositions()
{
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;

      if (PositionGetString(POSITION_COMMENT) != "SwingEA_v1") continue;

      CTrade trade;
      trade.PositionClose(ticket);

      if (trade.ResultRetcode() == TRADE_RETCODE_DONE) {
         Print("[CloseAllPositions] Closed position ", ticket);
      } else {
         Print("[CloseAllPositions] Failed to close ", ticket, ": ", trade.ResultRetcodeDescription());
      }
   }
}

/**
 * CalculateLotSize - Calculate dynamic lot size based on risk management
 * Based on specification Chapter 4.2 - Position-Sizing
 *
 * Formula:
 * - riskAmount = balance × (currentRisk / 100)
 * - slDistanceInTicks = (slDistance / point) / tickSize
 * - lotSize = riskAmount / (slDistanceInTicks × tickValue)
 *
 * Normalization:
 * - Ensure minLot <= lotSize <= maxLot
 * - Round to lotStep increments
 *
 * @param symbol - Symbol to calculate for
 * @param slDistanceInPoints - SL distance in points (ATR-based)
 * @return Normalized lot size or 0 if invalid
 */
double CalculateLotSize(string symbol, double slDistanceInPoints)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (currentRisk / 100.0);

   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

   // Validate inputs
   if (balance <= 0 || tickValue <= 0 || tickSize <= 0 || point <= 0) {
      Print("[CalculateLotSize] Invalid symbol info for ", symbol);
      return 0;
   }

   // Convert SL distance from points to price, then to ticks
   double slDistanceInPrice = slDistanceInPoints * point;
   double slDistanceInTicks = slDistanceInPrice / tickSize;

   if (slDistanceInTicks <= 0) {
      Print("[CalculateLotSize] Invalid SL distance for ", symbol);
      return 0;
   }

   // Calculate raw lot size
   double lotSize = riskAmount / (slDistanceInTicks * tickValue);

   // Get symbol limits
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   if (minLot <= 0 || maxLot <= 0 || lotStep <= 0) {
      Print("[CalculateLotSize] Invalid lot limits for ", symbol);
      return 0;
   }

   // Normalize lot size
   lotSize = MathMax(minLot, lotSize);
   lotSize = MathMin(maxLot, lotSize);
   lotSize = NormalizeDouble(MathFloor(lotSize / lotStep) * lotStep, 2);

   // Final validation
   if (lotSize < minLot || lotSize > maxLot) {
      Print("[CalculateLotSize] Final lot size ", lotSize, " out of range [", minLot, ",", maxLot, "]");
      return 0;
   }

   Print("[CalculateLotSize] ", symbol, " | Risk: ", currentRisk, "% | SL: ", slDistanceInPoints,
         "pts | Lot: ", lotSize);

   return lotSize;
}

//+------------------------------------------------------------------+
//| Trade Execution Functions                                        |
//+------------------------------------------------------------------+

/**
 * CalculateATR_TP - Calculate take-profit level based on ATR
 * Simple ATR-based TP calculation
 *
 * Long Setup:
 * - TP = Entry + (ATR × ATR_TP_Multiplier)
 *
 * Short Setup:
 * - TP = Entry - (ATR × ATR_TP_Multiplier)
 *
 * @param symbol - Symbol name
 * @param entry - Entry price
 * @param isLong - true for long, false for short
 * @return TP level or 0 if invalid
 */
double CalculateATR_TP(string symbol, double entry, bool isLong)
{
   double atr = GetATR(symbol, 0);
   if (atr <= 0) return 0;

   double tpDistance = atr * ATR_TP_Multiplier;

   if (isLong) {
      return entry + tpDistance;
   } else {
      return entry - tpDistance;
   }
}

/**
 * CanOpenNewPosition - Check if we can open a new position
 * Respects MaxOpenPositions limit
 *
 * @return true if open count < MaxOpenPositions
 */
bool CanOpenNewPosition()
{
   int openCount = 0;

   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;

      if (PositionGetString(POSITION_COMMENT) == "SwingEA_v1") {
         openCount++;
      }
   }

   bool canOpen = (openCount < MaxOpenPositions);

   if (!canOpen) {
      Print("[CanOpenNewPosition] Max positions reached: ", openCount, "/", MaxOpenPositions);
   }

   return canOpen;
}

//+------------------------------------------------------------------+
//| News Filter via Spread Detection                                 |
//+------------------------------------------------------------------+

/**
 * IsSpreadNormal - Check if spread is within normal range
 *
 * Purpose: Detect high-impact news events by monitoring spread widening
 * Many prop firms ban trading during news, and spreads widen significantly
 * during high-impact events (NFP, CPI, FOMC, etc.)
 *
 * Logic:
 * - Get current spread (Ask - Bid)
 * - Get normal spread from symbol specification
 * - Compare ratio: if current spread > 1.5x normal → likely news event
 *
 * @param symbol - Symbol to check
 * @return true if spread is normal, false if abnormally wide (news suspected)
 */
bool IsSpreadNormal(string symbol)
{
   // If spread filter is disabled, always return true (allow trade)
   if (!UseSpreadFilter) {
      return true;
   }

   // Get current Ask and Bid
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

   // Validate prices
   if (ask <= 0 || bid <= 0 || point <= 0) {
      Print("[SpreadFilter] Invalid prices for ", symbol, " - skipping spread check");
      return true; // Don't block trade due to data error
   }

   // Get normal spread (average spread from symbol specification)
   int normalSpread = (int)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if (normalSpread <= 0) {
      Print("[SpreadFilter] Invalid normal spread for ", symbol, " - skipping spread check");
      return true; // Don't block trade due to data error
   }

   // Calculate current spread in points
   double currentSpread = (ask - bid) / point;

   // Calculate spread ratio
   double spreadRatio = currentSpread / (double)normalSpread;

   // Check against threshold (default 1.5x, adjustable via input)
   // Conservative threshold to avoid false positives
   // During major news (NFP, FOMC), spreads can widen 3-10x
   if (spreadRatio > SpreadMultiplierThreshold) {
      Print("⚠️ [SpreadFilter] ", symbol, " - ABNORMAL SPREAD DETECTED!");
      Print("   Current Spread: ", currentSpread, " points");
      Print("   Normal Spread: ", normalSpread, " points");
      Print("   Ratio: ", DoubleToString(spreadRatio, 2), "x normal");
      Print("   Threshold: ", SpreadMultiplierThreshold, "x");
      Print("   → Trade BLOCKED (likely news event)");
      return false;
   }

   // Spread is normal
   return true;
}

/**
 * OpenTrade - Open a new trade for a symbol setup
 * Based on specification Chapter 5.3 - Order Execution
 *
 * Process:
 * 1. Calculate SL distance (ATR_SL_Multiplier × ATR)
 * 2. Calculate entry price (Ask for Long, Bid for Short)
 * 3. Calculate SL and TP levels (ATR-based)
 * 4. Calculate lot size based on risk
 * 5. Execute Buy/Sell order
 *
 * @param symbolIndex - Index in symbolStates array
 * @return true if trade opened successfully
 */
bool OpenTrade(int symbolIndex)
{
   string symbol = symbolStates[symbolIndex].symbol;
   bool isLong = symbolStates[symbolIndex].isLongSetup;

   // Check if we can open
   if (!CanOpenNewPosition()) {
      return false;
   }

   // ⚠️ SPREAD FILTER: Block trade if spread is abnormally wide (likely news event)
   // Prop firms often ban trading during high-impact news
   if (!IsSpreadNormal(symbol)) {
      Print("[OpenTrade] Trade BLOCKED for ", symbol, " - Abnormal spread detected (likely news)");
      return false;
   }

   // Calculate SL distance
   double atr = GetATR(symbol, 0);
   if (atr <= 0) {
      Print("[OpenTrade] Invalid ATR for ", symbol);
      return false;
   }

   double slDistance = ATR_SL_Multiplier * atr;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double slDistanceInPoints = slDistance / point;

   // Get entry price
   double entry = 0;
   if (isLong) {
      entry = SymbolInfoDouble(symbol, SYMBOL_ASK);
   } else {
      entry = SymbolInfoDouble(symbol, SYMBOL_BID);
   }

   if (entry <= 0) {
      Print("[OpenTrade] Invalid entry price for ", symbol);
      return false;
   }

   // Calculate SL and TP
   double sl = 0;
   if (isLong) {
      sl = entry - slDistance;
   } else {
      sl = entry + slDistance;
   }

   double tp = CalculateATR_TP(symbol, entry, isLong);

   if (tp <= 0) {
      Print("[OpenTrade] Invalid TP for ", symbol);
      return false;
   }

   // Calculate lot size
   double lotSize = CalculateLotSize(symbol, slDistanceInPoints);
   if (lotSize <= 0) {
      Print("[OpenTrade] Invalid lot size for ", symbol);
      return false;
   }

   // Execute trade
   CTrade trade;
   bool success = false;

   if (isLong) {
      success = trade.Buy(lotSize, symbol, 0, sl, tp, "SwingEA_v1");
   } else {
      success = trade.Sell(lotSize, symbol, 0, sl, tp, "SwingEA_v1");
   }

   if (success) {
      symbolStates[symbolIndex].state = STATE_TRADE_TAKEN;
      Print("[OpenTrade] SUCCESS | ", symbol, " | Type: ", (isLong ? "LONG" : "SHORT"),
            " | Lot: ", lotSize, " | Entry: ", entry, " | SL: ", sl, " | TP: ", tp);

      // Log trade to file
      LogTradeToFile(symbol, isLong, entry, sl, tp, lotSize);

      return true;
   } else {
      Print("[OpenTrade] FAILED | ", symbol, " | Error: ", trade.ResultRetcodeDescription());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Timing & Workflow Functions                                      |
//+------------------------------------------------------------------+

/**
 * IsInTradingWindow - Check if current time is within trading windows
 * Based on specification Chapter 5.2 - Trading Time Windows
 *
 * EA scans only 4 times daily after 4H-Candle closes:
 * - 06:45 - 07:00 (after 04:00 candle)
 * - 10:45 - 11:00 (after 08:00 candle)
 * - 14:45 - 15:00 (after 12:00 candle)
 * - 18:45 - 19:00 (after 16:00 candle)
 *
 * @return true if current time is in one of the trading windows
 */
bool IsInTradingWindow()
{
   if(!TradeOnlyInWindows)
      return true; // alles erlaubt

   datetime serverTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);
   int hour   = dt.hour;
   int minute = dt.min;

   // Window 1: 06:45 - 07:00
   if(hour == 6 && minute >= 45) return true;
   if(hour == 7 && minute == 0)  return true;

   // Window 2: 10:45 - 11:00
   if(hour == 10 && minute >= 45) return true;
   if(hour == 11 && minute == 0)  return true;

   // Window 3: 14:45 - 15:00
   if(hour == 14 && minute >= 45) return true;
   if(hour == 15 && minute == 0)  return true;

   // Window 4: 18:45 - 19:00
   if(hour == 18 && minute >= 45) return true;
   if(hour == 19 && minute == 0)  return true;

   return false;
}


//+------------------------------------------------------------------+
//| Error Handling & Validation Functions                            |
//+------------------------------------------------------------------+

/**
 * ValidateAllSymbols - Check if all symbols in the array are available for trading
 * Based on specification Chapter 8.3 - Symbol Validation
 *
 * Checks:
 * - Symbol exists in broker's database
 * - Symbol is available for trading
 * - Symbol has valid bid/ask prices
 *
 * @return true if all symbols are valid, false otherwise
 */
bool ValidateAllSymbols()
{
   Print("[ValidateAllSymbols] Validating ", ArraySize(symbols), " symbols...");

   int validCount = 0;
   int invalidCount = 0;

   for (int i = 0; i < ArraySize(symbols); i++) {
      string symbol = symbols[i];

      // Check if symbol exists
      if (!SymbolSelect(symbol, true)) {
         Print("[ValidateAllSymbols] ⚠️ Symbol NOT available: ", symbol);
         invalidCount++;
         continue;
      }

      // Check if symbol is tradeable
      if ((SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED) ||
          (SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_CLOSEONLY)) {
         Print("[ValidateAllSymbols] ⚠️ Symbol NOT tradeable: ", symbol);
         invalidCount++;
         continue;
      }

      // Check if we can get bid/ask prices
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

      if (bid <= 0 || ask <= 0) {
         Print("[ValidateAllSymbols] ⚠️ Invalid prices for: ", symbol);
         invalidCount++;
         continue;
      }

      validCount++;
      Print("[ValidateAllSymbols] ✓ Symbol valid: ", symbol, " (Bid: ", bid, " Ask: ", ask, ")");
   }

   Print("[ValidateAllSymbols] Summary: ", validCount, " valid, ", invalidCount, " invalid");

   if (invalidCount > 0) {
      Print("[ValidateAllSymbols] ⚠️ WARNING: Not all symbols are available!");
      Print("[ValidateAllSymbols] The EA will continue but may have reduced trading opportunities.");
      return false; // Not all symbols available, but continue with warning
   }

   Print("[ValidateAllSymbols] ✓ All symbols validated successfully!");
   return true;
}

/**
 * ValidateSymbol - Check if a specific symbol is available
 * Based on specification Chapter 8.3 - Symbol Validation
 *
 * @param symbol - Symbol to validate
 * @return true if symbol is valid and tradeable
 */
bool ValidateSymbol(string symbol)
{
   // Check if symbol exists and is selected
   if (!SymbolSelect(symbol, true)) {
      return false;
   }

   // Check if symbol is tradeable
   if ((SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED) ||
       (SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_CLOSEONLY)) {
      return false;
   }

   // Check if we can get valid prices
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

   if (bid <= 0 || ask <= 0) {
      return false;
   }

   return true;
}

/**
 * RecoverFromRestart - Recover EA state after restart/recompile
 * Based on specification Chapter 8.2 - Restart Safety
 *
 * Handles:
 * - Recovery of open positions from GlobalVariables
 * - Recovery of equity peak for drawdown calculation
 * - Validation that recovered state is consistent with actual positions
 *
 * @return true if recovery successful
 */
bool RecoverFromRestart()
{
   Print("[RecoverFromRestart] Attempting to recover EA state from restart...");

   // Count open positions from the broker
   int openCount = 0;
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;

      if (PositionGetString(POSITION_COMMENT) == "SwingEA_v1") {
         openCount++;
      }
   }

   if (openCount > 0) {
      Print("[RecoverFromRestart] Found ", openCount, " open positions from this EA");

      // Find the symbols of open positions and set their state to TRADE_TAKEN
      for (int i = 0; i < ArraySize(symbolStates); i++) {
         // Check if this symbol has an open position
         bool hasPosition = false;

         for (int j = PositionsTotal() - 1; j >= 0; j--) {
            ulong ticket = PositionGetTicket(j);
            if (ticket == 0) continue;

            if (PositionGetString(POSITION_COMMENT) == "SwingEA_v1") {
               if (PositionGetString(POSITION_SYMBOL) == symbolStates[i].symbol) {
                  hasPosition = true;
                  break;
               }
            }
         }

         if (hasPosition) {
            symbolStates[i].state = STATE_TRADE_TAKEN;
            Print("[RecoverFromRestart] Set ", symbolStates[i].symbol, " state to TRADE_TAKEN");
         }
      }
   } else {
      Print("[RecoverFromRestart] No open positions found, EA state is clean");
   }

   // Recover equity peak
   if (GlobalVariableCheck(GetEquityPeakVarName())) {
      double recoveredPeak = GlobalVariableGet(GetEquityPeakVarName());
      double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

      Print("[RecoverFromRestart] --- Equity Peak Recovery ---");
      Print("[RecoverFromRestart] Account: ", AccountInfoInteger(ACCOUNT_LOGIN));
      Print("[RecoverFromRestart] Recovered Peak: ", DoubleToString(recoveredPeak, 2));
      Print("[RecoverFromRestart] Current Equity: ", DoubleToString(currentEquity, 2));

      if (recoveredPeak > 0) {
         equityPeak = recoveredPeak;

         // Recalculate drawdown
         if (currentEquity < equityPeak) {
            currentDD = ((equityPeak - currentEquity) / equityPeak) * 100.0;
            Print("[RecoverFromRestart] ⚠️ Drawdown detected: ", DoubleToString(currentDD, 2), "%");

            if (currentDD >= MaxDrawdownPercent) {
               Print("[RecoverFromRestart] ⚠️ WARNING: DD >= MaxDD (", MaxDrawdownPercent, "%)!");
               Print("[RecoverFromRestart] EA may trigger emergency stop!");
            }
         } else {
            Print("[RecoverFromRestart] ✓ No drawdown - equity at or above peak");
         }
      }
   } else {
      Print("[RecoverFromRestart] No previous equity peak found, initializing fresh");
      equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
      GlobalVariableSet(GetEquityPeakVarName(), equityPeak);
      Print("[RecoverFromRestart] Account: ", AccountInfoInteger(ACCOUNT_LOGIN));
      Print("[RecoverFromRestart] Initial equity peak set to: ", DoubleToString(equityPeak, 2));
   }

   Print("[RecoverFromRestart] ✓ Recovery complete");
   return true;
}

/**
 * RetryFailedSymbolInitialization - Retry initialization for symbols with invalid handles
 *
 * This function is called on every timer event to retry initialization of symbols
 * that failed during OnInit() or lost their handles during runtime.
 * Common causes for failed initialization:
 * - Symbols not in Market Watch
 * - Missing history data
 * - Broker connection issues during startup
 *
 * @return Number of symbols successfully (re)initialized
 */
int RetryFailedSymbolInitialization()
{
   static datetime lastRetryTime = 0;
   static int retryCount = 0;

   // Only retry every 5 minutes to avoid spam
   if (TimeCurrent() - lastRetryTime < 300) {
      return 0;
   }

   int successCount = 0;
   int totalInvalid = 0;

   // Check all symbols for invalid handles
   for (int i = 0; i < ArraySize(symbols); i++) {
      if (emaHandles[i] == INVALID_HANDLE || atrHandles[i] == INVALID_HANDLE) {
         totalInvalid++;

         // Try to select symbol
         if (!SymbolSelect(symbols[i], true)) {
            continue; // Symbol still not available
         }

         // Retry EMA handle creation
         if (emaHandles[i] == INVALID_HANDLE) {
            emaHandles[i] = iMA(symbols[i], PERIOD_H4, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
            if (emaHandles[i] != INVALID_HANDLE) {
               Print("[RetryInit] ✓ Successfully created EMA handle for ", symbols[i]);
            }
         }

         // Retry ATR handle creation
         if (atrHandles[i] == INVALID_HANDLE && emaHandles[i] != INVALID_HANDLE) {
            atrHandles[i] = iATR(symbols[i], PERIOD_H4, ATR_Period);
            if (atrHandles[i] != INVALID_HANDLE) {
               Print("[RetryInit] ✓ Successfully created ATR handle for ", symbols[i]);
            }
         }

         // Count as success if both handles are now valid
         if (emaHandles[i] != INVALID_HANDLE && atrHandles[i] != INVALID_HANDLE) {
            successCount++;
         }
      }
   }

   if (totalInvalid > 0) {
      lastRetryTime = TimeCurrent();
      retryCount++;
      Print("[RetryInit] Retry #", retryCount, ": ", successCount, "/", totalInvalid, " symbols initialized");
   }

   return successCount;
}

//+------------------------------------------------------------------+
//| Logging & Dashboard Functions                                    |
//+------------------------------------------------------------------+

/**
 * LogTradeToFile - Log trade details to CSV file
 * Based on specification Chapter 7.1 - File Logging
 *
 * CSV Format:
 * Timestamp,Symbol,Type,Entry,SL,TP,Lot,RiskPercent,Equity,DD
 *
 * File Location: MQL5/Files/SwingEA_v1_Trades.csv
 *
 * @param symbol - Symbol of the trade
 * @param isLong - true for long, false for short
 * @param entry - Entry price
 * @param sl - Stop loss price
 * @param tp - Take profit price
 * @param lotSize - Lot size traded
 * @return true if logging successful
 */
bool LogTradeToFile(string symbol, bool isLong, double entry, double sl, double tp, double lotSize)
{
   if (!EnableFileLogging) return true; // Logging disabled, skip

   // Create CSV file name
   string filename = "SwingEA_v1_Trades.csv";
   int handle = FileOpen(filename, FILE_READ | FILE_WRITE | FILE_CSV, ",");

   if (handle == INVALID_HANDLE) {
      Print("[LogTradeToFile] ERROR: Could not open file ", filename);
      return false;
   }

   // Check if file is empty (new file) and write header
   bool isNewFile = (FileSize(handle) == 0);
   if (isNewFile) {
      FileWrite(handle, "Timestamp,Symbol,Type,Entry,SL,TP,Lot,RiskPercent,Equity,DD");
   }

   // Get current account data
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
   string tradeType = isLong ? "BUY" : "SELL";

   // Write trade data
   FileWrite(handle, timestamp, symbol, tradeType,
             DoubleToString(entry, 5), DoubleToString(sl, 5), DoubleToString(tp, 5),
             DoubleToString(lotSize, 2), DoubleToString(currentRisk, 2),
             DoubleToString(equity, 2), DoubleToString(currentDD, 2));

   FileClose(handle);

   Print("[LogTradeToFile] Trade logged for ", symbol, " (", tradeType, ") at ", entry);
   return true;
}

/**
 * LogClosedTrade - Log closed trade with exit details
 * Based on specification Chapter 7.1 - File Logging
 *
 * CSV Format:
 * CloseTimestamp,Symbol,Type,Exit,Profit,ProfitPercent,Duration,Status
 *
 * File Location: MQL5/Files/SwingEA_v1_Closed.csv
 *
 * @param symbol - Symbol of the trade
 * @param isLong - true for long, false for short
 * @param exit - Exit price
 * @param profit - Profit in account currency
 * @param profitPercent - Profit as percentage
 * @param durationBars - Number of bars trade was open
 * @param status - "TP", "SL", "MANUAL"
 * @return true if logging successful
 */
bool LogClosedTrade(string symbol, bool isLong, double exit, double profit, double profitPercent, int durationBars, string status)
{
   if (!EnableFileLogging) return true; // Logging disabled, skip

   // Create CSV file name
   string filename = "SwingEA_v1_Closed.csv";
   int handle = FileOpen(filename, FILE_READ | FILE_WRITE | FILE_CSV, ",");

   if (handle == INVALID_HANDLE) {
      Print("[LogClosedTrade] ERROR: Could not open file ", filename);
      return false;
   }

   // Check if file is empty (new file) and write header
   bool isNewFile = (FileSize(handle) == 0);
   if (isNewFile) {
      FileWrite(handle, "CloseTimestamp,Symbol,Type,Exit,Profit,ProfitPercent,DurationBars,Status,Equity,DD");
   }

   // Get current account data
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
   string tradeType = isLong ? "BUY" : "SELL";

   // Write closed trade data
   FileWrite(handle, timestamp, symbol, tradeType,
             DoubleToString(exit, 5), DoubleToString(profit, 2),
             DoubleToString(profitPercent, 2), IntegerToString(durationBars),
             status, DoubleToString(equity, 2), DoubleToString(currentDD, 2));

   FileClose(handle);

   Print("[LogClosedTrade] Closed trade logged for ", symbol, " (", tradeType, ") | Status: ", status, " | P&L: ", profit);
   return true;
}

/**
 * UpdateDashboard - Display EA status and metrics on the chart
 * Based on specification Chapter 7.2 - Dashboard
 *
 * Display Information:
 * - EA Version
 * - Account Equity and Balance
 * - Trailing Drawdown (%)
 * - Current Risk Level (%)
 * - Number of open positions
 * - Top 3 symbols in AT_FIB state with quality scores
 * - Last update time
 *
 * @return void (updates Comment on chart)
 */
void UpdateDashboard()
{
   if (!ShowDashboard) return;

   string dashText = "";

   // ===== HEADER =====
   dashText += "╔════════════════════════════════════════════════════╗\n";
   dashText += "║         SwingEA v1.0 - Trading Dashboard         ║\n";
   dashText += "╚════════════════════════════════════════════════════╝\n";

   // ===== SYMBOL INITIALIZATION STATUS =====
   int validHandles = 0;
   int invalidHandles = 0;
   for (int i = 0; i < ArraySize(symbols); i++) {
      if (emaHandles[i] != INVALID_HANDLE && atrHandles[i] != INVALID_HANDLE) {
         validHandles++;
      } else {
         invalidHandles++;
      }
   }

   if (invalidHandles > 0) {
      dashText += "\n[SYMBOL STATUS]\n";
      dashText += "⚠️ Symbols ready: " + IntegerToString(validHandles) + "/" +
                  IntegerToString(ArraySize(symbols)) + "\n";
      dashText += "Initializing: " + IntegerToString(invalidHandles) + " symbols\n";
      dashText += "(Auto-retry every 5 minutes)\n";
   } else {
      dashText += "\n[SYMBOL STATUS]\n";
      dashText += "✓ All " + IntegerToString(validHandles) + " symbols ready\n";
   }

   // ===== ACCOUNT SECTION =====
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   dashText += "\n[ACCOUNT]\n";
   dashText += "Equity: $" + DoubleToString(equity, 2) + "\n";
   dashText += "Balance: $" + DoubleToString(balance, 2) + "\n";

   if (balance > 0) {
      double profit = equity - balance;
      double profitPercent = (profit / balance) * 100;
      dashText += "P&L: $" + DoubleToString(profit, 2) + " (";
      dashText += DoubleToString(profitPercent, 2) + "%)\n";
   }

   // ===== RISK SECTION =====
   dashText += "\n[RISK MANAGEMENT]\n";
   dashText += "DD: " + DoubleToString(currentDD, 2) + "%";

   // Display DD status
   if (currentDD >= MaxDrawdownPercent) {
      dashText += " ⚠️ EMERGENCY STOP";
   } else if (currentDD >= 3.0) {
      dashText += " 🔴 HIGH (0.25%)";
   } else if (currentDD >= 2.0) {
      dashText += " 🟠 MEDIUM (0.5%)";
   } else {
      dashText += " 🟢 NORMAL (1.0%)";
   }

   dashText += "\nRisk: " + DoubleToString(currentRisk, 2) + "%\n";
   dashText += "Max DD: " + DoubleToString(MaxDrawdownPercent, 2) + "%\n";

   // ===== POSITIONS SECTION =====
   int openCount = 0;
   double totalProfit = 0.0;

   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;

      if (PositionGetString(POSITION_COMMENT) == "SwingEA_v1") {
         openCount++;
         totalProfit += PositionGetDouble(POSITION_PROFIT);
      }
   }

   dashText += "\n[POSITIONS]\n";
   dashText += "Open: " + IntegerToString(openCount) + "/" + IntegerToString(MaxOpenPositions) + "\n";
   if (openCount > 0) {
      dashText += "P&L: $" + DoubleToString(totalProfit, 2) + "\n";
   }

   // ===== SETUP SECTION =====
   int countNO_TRADE = 0;
   int countTREND = 0;
   int countRETRACE = 0;
   int countAT_FIB = 0;
   int countTRADE = 0;

   for (int i = 0; i < ArraySize(symbolStates); i++) {
      switch (symbolStates[i].state) {
         case STATE_NO_TRADE:
            countNO_TRADE++;
            break;
         case STATE_TREND_FORMING:
            countTREND++;
            break;
         case STATE_RETRACEMENT:
            countRETRACE++;
            break;
         case STATE_AT_FIB:
            countAT_FIB++;
            break;
         case STATE_TRADE_TAKEN:
            countTRADE++;
            break;
      }
   }

   dashText += "\n[STATE DISTRIBUTION]\n";
   dashText += "🔴 NO_TRADE: " + IntegerToString(countNO_TRADE) + "\n";
   dashText += "🟡 TREND: " + IntegerToString(countTREND) + "\n";
   dashText += "🟢 RETRACE: " + IntegerToString(countRETRACE) + "\n";
   dashText += "🔵 AT_FIB: " + IntegerToString(countAT_FIB) + "\n";
   dashText += "🟣 TRADE: " + IntegerToString(countTRADE) + "\n";

   // ===== TOP SETUPS SECTION =====
   if (countAT_FIB > 0) {
      // Collect all AT_FIB setups with scores
      struct TopSetup {
         string symbol;
         double score;
      };

      TopSetup topSetups[];
      ArrayResize(topSetups, 0);

      for (int i = 0; i < ArraySize(symbolStates); i++) {
         if (symbolStates[i].state == STATE_AT_FIB && symbolStates[i].qualityScore > 0) {
            int size = ArraySize(topSetups);
            ArrayResize(topSetups, size + 1);
            topSetups[size].symbol = symbolStates[i].symbol;
            topSetups[size].score = symbolStates[i].qualityScore;
         }
      }

      // Sort by score (bubble sort, highest first)
      for (int i = 0; i < ArraySize(topSetups) - 1; i++) {
         for (int j = 0; j < ArraySize(topSetups) - i - 1; j++) {
            if (topSetups[j].score < topSetups[j + 1].score) {
               TopSetup temp = topSetups[j];
               topSetups[j] = topSetups[j + 1];
               topSetups[j + 1] = temp;
            }
         }
      }

      // Display top 3
      dashText += "\n[TOP SETUPS @ FIB]\n";
      int showCount = MathMin(3, ArraySize(topSetups));
      for (int i = 0; i < showCount; i++) {
         dashText += "#" + IntegerToString(i + 1) + ": " + topSetups[i].symbol +
                    " (" + DoubleToString(topSetups[i].score, 1) + ")\n";
      }
   }

   // ===== TIMING SECTION =====
   datetime serverTime = TimeCurrent();
   dashText += "\n[TIMING]\n";
   dashText += "Server: " + TimeToString(serverTime, TIME_DATE | TIME_SECONDS) + "\n";

   if (TradeOnlyInWindows) {
      dashText += "Window: ";
      if (IsInTradingWindow()) {
         dashText += "🟢 ACTIVE\n";
      } else {
         dashText += "🔴 CLOSED\n";
      }
   }

   // ===== FOOTER =====
   string separator = "";
   for (int i = 0; i < 50; i++) separator += "=";
   dashText += "\n" + separator + "\n";
   dashText += "Last Update: " + TimeToString(TimeCurrent(), TIME_SECONDS) + "\n";

   // Display on chart
   Comment(dashText);
}

/**
 * IsNewBar - Check if a new 4H bar has just closed
 * Used to trigger scans only on bar close, not every tick
 *
 * @return true if a new bar has opened
 */
bool IsNewBar()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_H4, 0);

   if (currentBarTime != lastBarTime) {
      lastBarTime = currentBarTime;
      return true;
   }

   return false;
}
