# SwingEA v1.0 - 4H Swing Trading Expert Advisor

## Übersicht

Automatisierter Multi-Symbol Swing Trading EA für MetaTrader 5, optimiert für 25 Forex-Paare + Gold (XAUUSD) auf dem H4-Timeframe.

## Aktuelle Version: 1.0 (Simplified ATR-Based SL/TP)

### Kernfeatures

- **Multi-Symbol-Scanning:** 25 Forex-Paare gleichzeitig analysieren
- **State-Machine:** Tracking von Trade-Lifecycle pro Symbol
- **Quality-Scoring:** Intelligente Setup-Bewertung und Auswahl
- **ATR-basiertes Risk-Management:** Dynamische SL/TP-Berechnung
- **Trailing-Drawdown:** Automatische Risk-Anpassung bei Verlusten
- **Max. 2 Positionen:** Konzentration auf beste Setups

---

## Trading-Strategie

### Entry-Logik

1. **EMA200 Trend-Filter:**
   - Long: Preis über EMA200, EMA steigend
   - Short: Preis unter EMA200, EMA fallend
   - Mindestabstand: 0.7 × ATR (optimiert)

2. **Swing-Detection:**
   - Higher Highs / Lower Lows Erkennung
   - Retrospektive Bestätigung (1 Candle Delay)
   - Minimum Swing-Distanz: 0.3 × ATR

3. **Fibonacci-Retracement:**
   - Entry-Zone: 50% - 61.8% Retracement
   - Toleranz: ± 0.25 × ATR (optimiert)

4. **Entry-Trigger:**
   - Rejection Candle (Pinbar)
   - Engulfing Candle

### Risk-Management (AKTUELL)

#### Stop-Loss
```
SL = ATR(14) × 1.0
```

- **Long:** SL = Entry - ATR
- **Short:** SL = Entry + ATR

#### Take-Profit
```
TP = ATR(14) × 2.0
```

- **Long:** TP = Entry + (2 × ATR)
- **Short:** TP = Entry - (2 × ATR)

#### Risk:Reward-Ratio
**Fix 1:2** - Für jeden Pip Risiko werden 2 Pips anvisiert.

### Position-Management

- **Keine Partial Closes** - Position läuft bis SL oder TP
- **Kein Break-Even Shift** - SL bleibt konstant
- **Keine Trailing-Stops** - Festes TP-Ziel

---

## Parameter

### Risk-Management
```mql5
input double RiskPercent_Normal = 1.0;      // Risk % bei DD 0-2%
input double RiskPercent_Medium = 0.5;      // Risk % bei DD 2-3%
input double RiskPercent_High = 0.25;       // Risk % bei DD 3-10%
input double MaxDrawdownPercent = 10.0;     // Max DD (EA stoppt)
```

### Strategy-Parameter
```mql5
input int EMA_Period = 200;                 // EMA Periode
input int ATR_Period = 14;                  // ATR Periode
input double ATR_SL_Multiplier = 1.0;       // SL = ATR × 1.0
input double ATR_TP_Multiplier = 2.0;       // TP = ATR × 2.0
input double MinEMADistance_ATR = 0.7;      // Min EMA-Abstand
```

### Fibonacci-Levels
```mql5
input double Fib_Level1 = 38.2;             // Fib Level 1 (%)
input double Fib_Level2 = 50.0;             // Fib Level 2 (%)
input double Fib_Level3 = 61.8;             // Fib Level 3 (%)
input double Fib_Tolerance_ATR = 0.25;      // Fib-Toleranz
```

### Position-Management
```mql5
input int MaxOpenPositions = 2;             // Max gleichzeitige Positionen
input double MinQualityScore = 45.0;        // Min Quality-Score (0-100)
input double MinSwingDistance_ATR = 0.3;    // Min Swing-Distanz
```

### Timing
```mql5
input bool TradeOnlyInWindows = true;       // Nur 4× täglich scannen
```

EA scannt **4× täglich** nach H4-Candle-Close:
- 06:45 - 07:00 (nach 04:00 Candle)
- 10:45 - 11:00 (nach 08:00 Candle)
- 14:45 - 15:00 (nach 12:00 Candle)
- 18:45 - 19:00 (nach 16:00 Candle)

### Logging
```mql5
input bool EnableFileLogging = false;       // CSV Journal
input bool ShowDashboard = true;            // Chart-Dashboard
```

---

## Installation

1. Kopiere `SwingEA_v1.mq5` nach `MQL5/Experts/`
2. Kompiliere in MetaEditor (F7)
3. Starte EA auf beliebigem Chart (4H empfohlen)
4. EA scannt automatisch alle 25 konfigurierten Symbole

---

## Symbole

Der EA überwacht folgende 25 Symbole:

```
EURJPY, XAUUSD, GBPJPY, NZDJPY, EURCAD,
EURCHF, GBPCHF, USDCAD, AUDUSD, USDCHF,
GBPNZD, CADJPY, AUDNZD, NZDUSD, GBPUSD,
EURNZD, AUDCAD, GBPCAD, EURUSD, USDJPY,
AUDJPY, CHFJPY, CADCHF, GBPAUD, EURAUD
```

**Wichtig:** Alle Symbole müssen im Market Watch verfügbar sein!

---

## State-Machine

Jedes Symbol durchläuft folgende Zustände:

| State | Beschreibung |
|-------|--------------|
| `STATE_NO_TRADE` | 🔴 Kein Setup (EMA zu nah, kein Trend, etc.) |
| `STATE_TREND_FORMING` | 🟡 Swing erkannt, Trend vorhanden |
| `STATE_RETRACEMENT` | 🟢 Preis retraced Richtung Fib-Zone |
| `STATE_AT_FIB` | 🔵 Preis in Entry-Zone, warte auf Trigger |
| `STATE_TRADE_TAKEN` | 🟣 Trade aktiv (Position offen) |

---

## Quality-Scoring

Jedes Setup erhält einen Score (0-100 Punkte):

- **Multi-Timeframe-Alignment (0-30):** 1D-Trend mit 4H aligned?
- **EMA200-Distanz (0-20):** Preis weit genug vom EMA?
- **Fibonacci-Präzision (0-20):** Wie nah am idealen Level?
- **Candlestick-Qualität (0-20):** Rejection/Engulfing stark?
- **Swing-Struktur (0-10):** Clean HH/LL ohne Noise?

**Minimum Score:** 45.0 (optimiert)

Top-2 Setups werden getradet (wenn Score >= MinQualityScore).

---

## Trailing-Drawdown

Der EA passt das Risiko automatisch an den Drawdown an:

| Drawdown | Risk % |
|----------|--------|
| 0 - 2%   | 1.0%   |
| 2 - 3%   | 0.5%   |
| 3 - 10%  | 0.25%  |
| > 10%    | **EA STOPPT** |

**Equity-Peak** wird laufend aktualisiert und in GlobalVariables gespeichert.

---

## Logging

### CSV-Dateien (optional)

Wenn `EnableFileLogging = true`:

1. **SwingEA_v1_Trades.csv** - Alle Trade-Entries
   ```
   Timestamp, Symbol, Type, Entry, SL, TP, Lot, RiskPercent, Equity, DD
   ```

2. **SwingEA_v1_Closed.csv** - Alle Trade-Exits
   ```
   CloseTimestamp, Symbol, Type, Exit, Profit, ProfitPercent, Duration, Status
   ```

### Chart-Dashboard

Bei `ShowDashboard = true` wird ein Live-Dashboard angezeigt:

```
=== SWING EA v1.0 ===
Account: Pepperstone-Demo
Equity: 10,250.00
Peak: 10,500.00
Drawdown: 2.38%
Risk: 0.50%
Open Positions: 1 / 2

--- Top Setups ---
EURJPY: 78 | AT_FIB
GBPJPY: 65 | RETRACEMENT
XAUUSD: 52 | TREND_FORMING
```

---

## Wichtige Hinweise

### ⚠️ Broker-Kompatibilität

- **Netting-Mode erforderlich** (Standard bei Pepperstone)
- Hedging-Mode wird nicht unterstützt
- Minimaler Spread: Keine Filterung (bei News vorsichtig!)

### ⚠️ VPS-Empfehlung

Für stabilen 24/7-Betrieb:
- VPS mit niedriger Latenz zum Broker
- Timer läuft alle 15 Minuten
- EA muss während Trading-Windows aktiv sein

### ⚠️ FXBlue-Copier

Wenn du FXBlue verwendest:
- Symbol-Mapping korrekt einstellen
- Lot-Scaling für Sub-Accounts anpassen
- EA hat keine Kontrolle über Copier-Settings!

---

## Änderungshistorie

### v1.0 (2025-01-29)
- ✅ Simplified ATR-based SL/TP
  - SL = ATR × 1.0 (vorher: 1.5)
  - TP = ATR × 2.0 (vorher: Fibonacci-Extensions)
- ❌ Removed: Partial Close bei TP1
- ❌ Removed: Break-Even Shift
- ❌ Removed: TP2/TP3 Levels
- ✅ Fixed Risk:Reward = 1:2

### v0.9 (Initial)
- Multi-Symbol-Scanner
- State-Machine
- Quality-Scoring
- Fibonacci-TP (TP1/TP2/TP3)
- Partial-Close + Break-Even

---

## Testing

### Backtest-Empfehlung

**Strategy Tester Settings:**
- Zeitraum: 2020-01-01 bis aktuell (min. 3 Jahre)
- Modell: Every Tick (basiert auf echten Ticks)
- Initial Deposit: 10.000 EUR
- Leverage: 1:100

**Multi-Symbol-Backtest:**
- Alle 25 Symbole müssen verfügbar sein
- Spread: Realistisch (z.B. 1-2 Pips Forex, 20-30 Pips Gold)

### Forward-Test (Demo)

**Dauer:** Mindestens 3 Monate vor Live-Einsatz!

**Acceptance-Criteria:**
- ✅ Win-Rate >= 40%
- ✅ Profit Factor >= 1.3
- ✅ Max Drawdown <= 10%
- ✅ Trade-Frequency: ~10-20 Trades/Monat
- ✅ Keine kritischen Bugs

---

## Support

Bei Fragen zur Implementierung oder Strategie:
- **Code:** SwingEA_v1.mq5
- **Dokumentation:** EA_Specification.md

**Wichtige Dateien:**
- `EA_Specification.md` - Vollständige technische Spezifikation
- `OPTIMIZED_PARAMETERS.md` - Parameter-Optimierungsverlauf
- `PARAMETER_CHANGES.md` - Änderungen dokumentiert

---

## Disclaimer

⚠️ **Dieser EA ist ein Werkzeug, keine Garantie!**

- Vergangene Performance garantiert keine zukünftigen Ergebnisse
- Teste IMMER erst auf Demo (min. 3 Monate)
- Risikiere nie mehr als du verlieren kannst
- Nutze Stop-Loss und Drawdown-Limits

**Prop Firm Trading:**
- Beachte Prop Firm Rules (Max Daily Loss, Max Total DD, etc.)
- EA stoppt bei 10% DD - prüfe ob das mit deinen Firm-Limits kompatibel ist
- FXBlue-Copier muss korrekt konfiguriert sein

---

## Lizenz

© 2025 Markus Schnittker
Für persönlichen Gebrauch. Keine Weitergabe ohne Erlaubnis.

---

**Version:** 1.0
**Letztes Update:** 2025-01-29
**Status:** ✅ Production Ready (nach Demo-Test)
