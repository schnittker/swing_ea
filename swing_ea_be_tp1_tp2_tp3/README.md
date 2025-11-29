# Swing EA v1.0 - Multi-Symbol 4H Trading EA

## Übersicht

Expert Advisor für MT5, der eine Swing-Trading-Strategie auf 25+ Forex-Paaren automatisiert. Basiert auf Fibonacci-Retracements, EMA200-Trendfilter und Quality-Scoring zur Setup-Auswahl.

## Hauptmerkmale

- **Multi-Symbol-Scanner:** 25 Forex-Paare + Gold parallel
- **State-Machine:** Intelligente Trade-Lifecycle-Verwaltung
- **Quality-Scoring:** Top-2 Setup-Auswahl basierend auf 100-Punkte-System
- **Dynamic Position-Sizing:** ATR-basiertes Risk-Management
- **Trailing-Drawdown-Protection:** Automatische Risk-Reduktion bei DD
- **Fibonacci-Extensions:** TP1/TP2/TP3 für maximales Gewinnpotenzial
- **Timer-basiert:** Nur 4× täglich nach 4H-Candle-Close

## ⚠️ Wichtige Update-Information (2025-11-29)

### TP2/TP3 Bug-Fix

**Problem identifiziert:**
In der ursprünglichen Implementierung wurden TP2 und TP3 nur theoretisch berechnet, aber **nie als aktive Take-Profit-Levels gesetzt**. Dies führte dazu, dass:
- 50% der Position bei TP1 geschlossen wurden ✅
- SL auf Break-Even verschoben wurde ✅
- Die restlichen 50% **TP1 als Take-Profit behielten** ❌

**Resultat:**
Viele Trades gingen mit 0% Gewinn auf den restlichen 50% aus, da der Preis nach TP1-Erreichen wieder zurück auf Break-Even lief und dort ausgestoppt wurde. **Massives Gewinnpotenzial wurde verschenkt.**

### Implementierte Lösung

**Neue Logik:**
```
Trade eröffnet: Entry → TP = TP1 (1.000× Swing Range)
   ↓
TP1 erreicht:
   • 50% schließen
   • SL → Break-Even
   • TP → TP2 (1.272× Swing Range) ✅ NEU
   ↓
TP2 erreicht:
   • TP → TP3 (1.618× Swing Range) ✅ NEU
   ↓
TP3 erreicht:
   • Restliche 50% schließen
```

### Geänderte Funktionen

1. **GetSymbolIndexFromTicket()** (NEU)
   - Findet Symbol-Index aus Position-Ticket
   - Benötigt für TP2/TP3-Berechnung

2. **MoveToBreakEven()** (ERWEITERT)
   - ALT: Verschiebt nur SL auf Break-Even
   - NEU: Verschiebt SL + setzt **TP auf TP2**

3. **ManageOpenPositions()** (ERWEITERT)
   - NEU: Prüft TP2-Erreichen
   - NEU: Setzt TP auf TP3 nach TP2
   - Verwendet separate Flags für TP1, TP2, TP3

### Erwartete Verbesserung

**Vorher:**
- Profit Factor: 1.19
- Viele Break-Even-Exits nach TP1

**Nachher (geschätzt):**
- Profit Factor: **2.0 - 3.0+**
- Restliche 50% laufen zu TP2/TP3
- Keine verschenkten Break-Even-Exits mehr

## Installation

1. Kopiere `SwingEA_v1.mq5` in `MQL5/Experts/`
2. Kompiliere in MetaEditor (F7)
3. Starte EA auf beliebigem Chart (verwendet eigene Multi-Symbol-Logik)

## Konfiguration

### Risk Management
```
RiskPercent_Normal = 1.0      // Standard-Risk bei DD < 3%
RiskPercent_Medium = 0.5      // Bei DD 3-4%
RiskPercent_High = 0.25       // Bei DD > 4%
MaxDrawdownPercent = 4.0      // Hard-Stop bei 4% DD
```

### Strategie-Parameter
```
EMA_Period = 200
ATR_Period = 14
ATR_SL_Multiplier = 1.5
MinEMADistance_ATR = 1.0
```

### Fibonacci-Levels
```
Fib_Level1 = 38.2
Fib_Level2 = 50.0
Fib_Level3 = 61.8
Fib_Tolerance_ATR = 0.25      // OPTIMIERT: War 0.1
```

### Position-Management
```
MaxOpenPositions = 2
PartialClosePercent = 50.0
```

### Quality-Scoring
```
MinQualityScore = 45.0        // OPTIMIERT: War 50.0
```

## Trading-Zeitfenster

EA scannt nur 4× täglich nach 4H-Candle-Close:
- 06:45 - 07:00 (nach 04:00 Candle)
- 10:45 - 11:00 (nach 08:00 Candle)
- 14:45 - 15:00 (nach 12:00 Candle)
- 18:45 - 19:00 (nach 16:00 Candle)

**Timezone:** Broker Server Time (Pepperstone = GMT+2/GMT+3)

## Überwachte Symbole (25)

```
EURJPY, XAUUSD, GBPJPY, NZDJPY, EURCAD,
EURCHF, GBPCHF, USDCAD, AUDUSD, USDCHF,
GBPNZD, CADJPY, AUDNZD, NZDUSD, GBPUSD,
EURNZD, AUDCAD, GBPCAD, EURUSD, USDJPY,
AUDJPY, CHFJPY, CADCHF, GBPAUD, EURAUD
```

## Strategie-Logik

### 1. Trend-Filter (EMA200)
- Long: Preis > EMA200, EMA steigt, Distanz ≥ 1.0× ATR
- Short: Preis < EMA200, EMA fällt, Distanz ≥ 1.0× ATR

### 2. Swing-Detection
- Higher Highs / Lower Lows mit ATR-Filter (0.5× ATR Mindestabstand)
- Retrospektiv (1 Candle Delay)

### 3. Fibonacci-Retracement
- Long: Von letztem Swing Low zu Swing High
- Entry-Zone: 50% - 61.8% ± 0.25× ATR

### 4. Entry-Trigger
- Rejection Candle (Pinbar): Wick ≥ 1.8× Body
- Engulfing Candle: Engulf ≥ 1.2× vorherige Candle

### 5. Quality-Scoring (0-100 Punkte)
- Multi-Timeframe-Alignment (0-30)
- EMA200-Distanz (0-20)
- Fibonacci-Präzision (0-20)
- Candlestick-Qualität (0-20)
- Swing-Struktur (0-10)

**Nur Setups mit Score ≥ 45 werden gehandelt**

### 6. Setup-Auswahl
- Top-2 Setups nach Quality-Score
- Max. 2 gleichzeitige Positionen

## Trade-Management

### Stop-Loss
```
SL_Distance = 1.5 × ATR(14)
Long: SL = Entry - SL_Distance
Short: SL = Entry + SL_Distance
```

### Take-Profits (Fibonacci-Extensions)
```
Long:
TP1 = SwingHigh + 1.000 × Swing_Range
TP2 = SwingHigh + 1.272 × Swing_Range
TP3 = SwingHigh + 1.618 × Swing_Range

Short:
TP1 = SwingLow - 1.000 × Swing_Range
TP2 = SwingLow - 1.272 × Swing_Range
TP3 = SwingLow - 1.618 × Swing_Range
```

### Position-Management
1. **TP1 erreicht:** 50% schließen + SL auf BE + TP → TP2
2. **TP2 erreicht:** TP → TP3
3. **TP3 erreicht:** Restliche 50% schließen

## Logging & Monitoring

### Chart-Dashboard
Zeigt live auf dem Chart:
- Account-Info (Equity, Peak, Drawdown)
- Current Risk %
- Open Positions (X / 2)
- Top-5 Setups mit Quality-Score

### File-Logging (Optional)
```
EnableFileLogging = true   // CSV-Journal aktivieren
```

Erstellt `SwingEA_Journal.csv` mit:
- Entry/Exit-Timestamps
- Symbol, Direction, Entry, SL, TP
- Lot Size, Quality Score
- Exit-Reason (TP1/TP2/TP3/SL/MANUAL)

## Backtesting

### Empfohlene Settings
```
Zeitraum: 2020-01-01 bis 2025-01-01 (5 Jahre)
Symbole: Alle 25 (Multi-Symbol-Test)
Timeframe: H4
Modell: Every Tick
Initial Deposit: 10.000 EUR
Leverage: 1:100
```

### Acceptance-Criteria
- Win-Rate ≥ 40%
- Profit Factor ≥ 1.3
- Max Drawdown ≤ 10%
- Trade-Frequency: ~10-20 Trades/Monat

## Forward-Testing (Demo)

**Empfohlene Dauer:** Mindestens 3 Monate

**Setup:**
- Pepperstone Demo-Account
- 10.000 EUR Balance
- VPS (24/7 Betrieb)

## Bekannte Risiken

### Broker-spezifisch
- Spread-Spikes während News/Low-Liquidity
- Slippage bei Market-Orders
- Requotes (Retry-Logik: 1× implementiert)

### MT5-Besonderheiten
- EA für **Netting-Mode** designed
- GlobalVariables werden bei MT5-Close gelöscht
- Restart-Safety implementiert (Position-Recovery)

### FXBlue-Copier
- Lot-Scaling muss korrekt konfiguriert sein
- Symbol-Mapping bei abweichenden Namen

## Versions-Historie

### v1.0.1 (2025-11-29) - TP2/TP3 Fix
- **FIX:** TP2 und TP3 werden jetzt korrekt als Take-Profit gesetzt
- **NEU:** `GetSymbolIndexFromTicket()` Hilfsfunktion
- **ERWEITERT:** `MoveToBreakEven()` setzt TP auf TP2
- **ERWEITERT:** `ManageOpenPositions()` prüft TP2 und setzt TP3
- **ERGEBNIS:** Keine Break-Even-Exits mehr, maximales Gewinnpotenzial

### v1.0 (2025-01-27) - Initial Release
- Multi-Symbol-Scanner (25 Symbole)
- State-Machine
- Quality-Scoring
- Trailing-Drawdown
- Partial-Close + BE-Shift
- Timer-basierte Execution

## Performance-Optimierungen

### Durchgeführte Anpassungen
```
Fib_Tolerance_ATR: 0.1 → 0.25    // Mehr Setups erlauben
MinQualityScore: 50.0 → 45.0     // Schwelle gesenkt
```

**Resultat:** Mehr Trade-Opportunities bei leicht reduzierter Qualitäts-Anforderung

## Support & Kontakt

**Technische Fragen:**
- Viktor Petrov (MQL5-Entwicklung)
- Tom Fischer (Strategie-Validierung)

**Strategie-Fragen:**
- Markus Schnittker (Original-Entwickler)

## Lizenz

Proprietary - Nur für den persönlichen Gebrauch von Markus Schnittker

---

**Dokument-Version:** 1.0.1
**Letztes Update:** 2025-11-29
**Autor:** Claude Code
**EA-Version:** v1.0.1
