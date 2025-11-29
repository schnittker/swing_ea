# SwingEA Parameter-Lockerung - 2025-11-27

## Grund für Änderungen

**Problem:** Nur 4 Trades in 2 Monaten (1.10-26.11.2025) bei 25 Symbolen
**Ursache:** Setup-Kriterien zu restriktiv → 0,08 Trades pro Symbol pro Monat
**Ziel:** Mehr Trade-Opportunities generieren für statistische Validierung

---

## Durchgeführte Änderungen

### 1. EMA-Distance-Filter (Line 27)

**VORHER:**
```mql5
input double MinEMADistance_ATR = 1.0;  // Min EMA Distance (× ATR)
```

**NACHHER:**
```mql5
input double MinEMADistance_ATR = 0.5;  // Min EMA Distance (× ATR) - GELOCKERT
```

**Impact:**
- 1.0 × ATR war sehr weit (z.B. EURUSD: ~100 pips)
- 0.5 × ATR = 50% weniger Distanz erforderlich
- **Erwarteter Effekt:** +200% mehr TREND_FORMING States

---

### 2. Fibonacci-Toleranz (Line 33)

**VORHER:**
```mql5
input double Fib_Tolerance_ATR = 0.1;  // Fib Tolerance (× ATR)
```

**NACHHER:**
```mql5
input double Fib_Tolerance_ATR = 0.2;  // Fib Tolerance (× ATR) - GELOCKERT
```

**Impact:**
- Fib-Entry-Zone wird 2× breiter
- Mehr Setups erreichen STATE_AT_FIB
- **Erwarteter Effekt:** +150% mehr AT_FIB States

---

### 3. Quality-Score Minimum (Line 40)

**VORHER:**
```mql5
input double MinQualityScore = 50.0;  // Min Quality Score (0-100)
```

**NACHHER:**
```mql5
input double MinQualityScore = 35.0;  // Min Quality Score (0-100) - GELOCKERT
```

**Impact:**
- Setups mit Score 35-50 werden jetzt akzeptiert
- Weniger Rejections bei Setup-Selection
- **Erwarteter Effekt:** +100% mehr executed Trades

---

### 4. Swing-Distance Minimum (Line 43)

**VORHER:**
```mql5
input double MinSwingDistance_ATR = 0.5;  // Min Swing Distance (× ATR)
```

**NACHHER:**
```mql5
input double MinSwingDistance_ATR = 0.3;  // Min Swing Distance (× ATR) - GELOCKERT
```

**Impact:**
- Swings müssen weniger weit voneinander entfernt sein
- Mehr Swings werden erkannt
- **Erwarteter Effekt:** +50% mehr erkannte Swings

---

### 5. Trading-Windows (Line 49)

**VORHER:**
```mql5
input bool TradeOnlyInWindows = true;  // Trade only in 4 time windows
```

**NACHHER:**
```mql5
input bool TradeOnlyInWindows = false;  // DEAKTIVIERT für mehr Opportunities
```

**Impact:**
- EA scannt jetzt **24/7** statt nur 4× 15 Minuten pro Tag
- Von 1 Stunde/Tag auf 24 Stunden/Tag Scanning
- **Erwarteter Effekt:** +2400% mehr Scan-Opportunities (24× mehr)

**Hinweis:** Kann für Live-Trading wieder auf `true` gesetzt werden wenn gewünscht.

---

### 6. Rejection-Candle Kriterien (Line 809 & 850)

**VORHER:**
```mql5
// Bullish Rejection
if (lowerWick < 1.8 * body) return false;

// Bearish Rejection
if (upperWick < 1.8 * body) return false;
```

**NACHHER:**
```mql5
// Bullish Rejection - GELOCKERT von 1.8x auf 1.5x
if (lowerWick < 1.5 * body) return false;

// Bearish Rejection - GELOCKERT von 1.8x auf 1.5x
if (upperWick < 1.5 * body) return false;
```

**Impact:**
- 1.8× Wick/Body Ratio war sehr selektiv
- 1.5× = Standard Pin-Bar Definition (mehr marktüblich)
- **Erwarteter Effekt:** +80% mehr Entry-Candles erkannt

---

## Erwartetes Gesamtresultat

**Vorher:**
- 4 Trades / 2 Monate
- 2 Trades / Monat
- 0,08 Trades / Symbol / Monat

**Nachher (Prognose):**
- 30-60 Trades / 2 Monate
- 15-30 Trades / Monat
- 0,6-1,2 Trades / Symbol / Monat

**Steigerung:** 750-1500% mehr Trades

---

## Test-Plan

### Phase 1: Backtest mit gelockerten Parametern

**Setup:**
- Zeitraum: 1.10.2025 - 26.11.2025 (gleicher Zeitraum wie vorher)
- Symbole: Alle 25 verfügbar
- Model: OHLC oder Every Tick
- Balance: 10.000 USD

**Ziel:**
- Minimum 30 Trades (7,5× mehr als vorher)
- Validieren welche Parameter-Änderung größten Impact hat

### Phase 2: Analyse & Justierung

**Basierend auf Results:**

**Wenn 30-60 Trades:**
→ Parameter sind gut, längeren Backtest machen (1.1-26.11.2025)

**Wenn < 30 Trades:**
→ Weitere Lockerung nötig (z.B. MinQualityScore auf 30)

**Wenn > 100 Trades:**
→ Evtl. zu permissiv, Parameter leicht straffen

### Phase 3: Performance-Evaluation

**Metriken checken:**
- Profitfaktor (Ziel: > 1.3)
- Win-Rate (Ziel: 35-50%)
- Max Drawdown (Ziel: < 15%)
- Average Winner / Loser Ratio (Ziel: > 2.0)

### Phase 4: Optimization (falls nötig)

**Strategy Tester Optimization Mode:**
- Optimiere MinEMADistance_ATR (0.3-0.8)
- Optimiere MinQualityScore (25-45)
- Optimiere Fib_Tolerance_ATR (0.15-0.25)
- Finde optimale Parameter-Kombination

---

## Debug-Features aktiviert

**Line 272-284:** State-Distribution Logging

Bei jedem Timer-Call (alle 15 Min) wird geloggt:
```
[DEBUG] State Distribution - NO_TRADE:23 TREND:2 RETRACE:0 AT_FIB:0 TRADE:0
```

**Nutzen:**
- Siehst du wo Setups "stecken bleiben"
- Identifizierst Bottlenecks im Setup-Flow
- Validierst ob Parameter-Änderungen wirken

---

## Rollback-Plan (falls zu permissiv)

**Wenn Results zeigen:**
- > 100 Trades mit Win-Rate < 25%
- Profitfaktor < 0.8
- Zu viele "schlechte" Setups

**Dann schrittweise straffen:**

1. **TradeOnlyInWindows zurück auf `true`**
   → Reduziert Trades sofort um ~80%

2. **MinQualityScore auf 40 erhöhen**
   → Filtert schwächere Setups

3. **MinEMADistance_ATR auf 0.6 erhöhen**
   → Mehr Distanz zu EMA erforderlich

4. **Rejection-Candle zurück auf 1.6× statt 1.5×**
   → Mittlerer Weg zwischen 1.8× und 1.5×

---

## Wichtige Hinweise

### ⚠️ Für Live-Trading

**NICHT direkt mit diesen gelockerten Parametern live gehen!**

**Erst:**
1. ✅ Backtest validieren (mehrere Monate)
2. ✅ Forward-Test in Demo (1-3 Monate)
3. ✅ Performance-Metriken checken
4. ✅ Evtl. Parameter wieder etwas straffen für Live

**Dann:**
- Start mit Minimum-Lot (0.01)
- Intensives Monitoring erste 2-4 Wochen
- Schrittweise skalieren wenn stabil

### 📊 Erwartungs-Management

**Diese Änderungen:**
- ✅ Generieren MEHR Trades (Ziel erreicht)
- ❓ Performance könnte schlechter sein (mehr "mittelmäßige" Setups)
- ❓ Win-Rate könnte sinken (weniger selektiv)

**Trade-off:**
- Mehr Daten für statistische Validierung
- Besser: 50 Trades mit PF 1.3 als 4 Trades (zu wenig Daten)
- Später können wir straffen basierend auf Performance

---

## Nächste Schritte

1. **Re-compile EA** (F7 in MetaEditor)
2. **Run Backtest** (1.10-26.11.2025)
3. **Analysiere Results:**
   - Anzahl Trades?
   - State-Distribution Logs
   - Performance-Metriken
4. **Basierend auf Results:**
   - Längeren Backtest (1.1-26.11)
   - Parameter-Optimization
   - Oder weitere Adjustierung

---

**Erstellt:** 2025-11-27
**Erstellt von:** Dimitri Volkov (MQL5 Developer)
**Für:** Markus Schnittker - SwingEA_v1 Performance-Optimization
