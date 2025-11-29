# SwingEA Demo-Testing - Monitoring Template

**Start-Datum:** ________________
**VPS:** Contabo VPS 10 (Windows)
**Broker:** ________________
**Account:** Demo, 10.000 USD
**Symbole:** 25 Pairs

---

## 📊 TÄGLICHE CHECKS (5 Minuten)

**Täglich um: ________ Uhr**

### Checklist:
- [ ] VPS läuft? (RDP-Verbindung okay?)
- [ ] MT5 läuft? (nicht abgestürzt?)
- [ ] EA aktiv? (Smiley lächelt?)
- [ ] Internet-Verbindung stabil?

### Metriken erfassen:

| Datum | Balance | Equity | DD (%) | Offene Trades | Neue Trades heute | Notizen |
|-------|---------|--------|--------|---------------|-------------------|---------|
| _____ | 10.000  | 10.000 | 0.00   | 0             | 0                 | Start   |
|       |         |        |        |               |                   |         |
|       |         |        |        |               |                   |         |

**DD berechnen:**
```
DD% = (Peak Balance - Current Equity) / Peak Balance × 100
```

**Alarm-Kriterien:**
- ⚠️ DD > 8%: Intensiver beobachten
- 🚨 DD > 10%: Emergency Stop sollte triggern

---

## 📈 WÖCHENTLICHE ANALYSE (15 Minuten)

**Jeden Sonntag:**

### Week: _____ (Datum: ____________)

**Performance:**
```
Start Balance: ________
End Balance:   ________
Gewinn/Verlust: ________ (____%)
Max DD diese Woche: _______%
```

**Trade-Statistiken:**
```
Trades gesamt: ____
Gewinner: ____ (____%)
Verlierer: ____ (____%)
Break-Even: ____

Profitfaktor: _______ (Gross Profit / Gross Loss)
Avg Winner: ________
Avg Loser: ________
Ratio: _______ (Avg Win / Avg Loss)
```

**Symbol-Verteilung:**
```
Welche Symbole wurden getradet?
Welche waren profitabel?
Welche haben verloren?

Top 3 Gewinner:
1. ________ (+_____)
2. ________ (+_____)
3. ________ (+_____)

Top 3 Verlierer:
1. ________ (-_____)
2. ________ (-_____)
3. ________ (-_____)
```

**Observations:**
```
- Gab es besondere Market-Events?
- Hat EA wie erwartet funktioniert?
- Irgendwelche Errors/Warnings in Logs?
- State-Distribution (aus Expert-Log):
  NO_TRADE: ___
  TREND: ___
  RETRACE: ___
  AT_FIB: ___
  TRADE: ___
```

---

## 🎯 MONATLICHE REVIEW (30 Minuten)

**Ende Monat: ____________**

### Gesamt-Performance:

**Kapital:**
```
Start: 10.000 USD
Ende: ________
Gewinn/Verlust: ________ (____%)
Max DD: _______%
```

**Trade-Statistiken (Monat):**
```
Trades gesamt: ____
Trades/Tag: ____ (Trades / 30)
Trades/Symbol/Monat: ____ (Trades / 25)

Win-Rate: _____%
Profitfaktor: _______

Longest Winning Streak: ____
Longest Losing Streak: ____
```

**Erwartungen vs Realität:**

| Metrik | Erwartet | Tatsächlich | Status |
|--------|----------|-------------|--------|
| Trades/Monat | 40-80 | _____ | ✅/⚠️/❌ |
| Profitfaktor | > 1.2 | _____ | ✅/⚠️/❌ |
| Win-Rate | 30-40% | _____ | ✅/⚠️/❌ |
| Max DD | < 10% | _____ | ✅/⚠️/❌ |
| Monthly Return | 0.5-2% | _____ | ✅/⚠️/❌ |

**Legende:**
- ✅ = Im Target-Bereich
- ⚠️ = Knapp außerhalb, beobachten
- ❌ = Weit außerhalb, Action nötig

---

## 🔧 TROUBLESHOOTING

### Häufige Probleme:

**EA macht keine Trades:**
- [ ] Check: Sind Symbole im Market Watch sichtbar?
- [ ] Check: Ist "Allow automated trading" aktiviert?
- [ ] Check: Expert-Log für Errors checken
- [ ] Check: State-Distribution - wo bleiben Setups hängen?

**VPS-Disconnect:**
- [ ] Internet-Verbindung prüfen
- [ ] MT5 neu starten
- [ ] EA neu aktivieren
- [ ] Check ob Trades verloren gingen

**EA-Crash:**
- [ ] Expert-Log analysieren (letzter Error vor Crash)
- [ ] MT5 neu starten
- [ ] EA neu deployen
- [ ] Falls wiederholt: Dimitri kontaktieren

**Unerwartete Performance:**
- [ ] Stimmen Parameter? (Common → Inputs Tab checken)
- [ ] Broker-Spreads normal?
- [ ] Execution-Quality okay? (Slippage log)
- [ ] Market-Conditions außergewöhnlich?

---

## 🚦 ENTSCHEIDUNGS-KRITERIEN

### Nach 1 Monat:

**✅ WEITER TESTEN (2. Monat) wenn:**
```
✅ Trades: > 40
✅ PF: > 1.1
✅ DD: < 10%
✅ Keine kritischen Bugs
```

**⚠️ PARAMETER ANPASSEN wenn:**
```
- Trades: < 30 (zu wenig)
- Trades: > 120 (zu viel, evtl. Quality problem)
- PF: 0.9-1.1 (Break-Even, Parameter tunen)
- DD: 8-12% (knapp, Risk reduzieren)
```

**❌ STOPPEN wenn:**
```
❌ PF: < 0.8 (klar unprofitabel)
❌ DD: > 15% (System kaputt)
❌ Kritische Code-Bugs (wiederkehrende Crashes)
❌ Broker-Probleme (extreme Slippage/Spreads)
```

---

### Nach 2 Monaten:

**✅ READY FÜR LIVE wenn:**
```
✅ Trades: > 80 (2 Monate)
✅ PF: > 1.2
✅ DD: < 8%
✅ Konsistente Performance (beide Monate positiv oder near-breakeven)
✅ Mindestens 5 profitable Symbole
✅ Keine kritischen Bugs
```

**Dann:**
→ Live-Start mit 500-1.000 USD (Micro-Capital)
→ Risk auf 0.5% reduzieren
→ Nur Top 5-10 Symbole (beste aus Demo)

---

## 📝 NOTIZEN & LEARNINGS

**Woche 1:**
```
___________________________________________
___________________________________________
```

**Woche 2:**
```
___________________________________________
___________________________________________
```

**Woche 3:**
```
___________________________________________
___________________________________________
```

**Woche 4:**
```
___________________________________________
___________________________________________
```

**Monat 1 - Fazit:**
```
Was lief gut?
___________________________________________

Was lief schlecht?
___________________________________________

Was würde ich ändern?
___________________________________________

Weiter zu Monat 2? Ja/Nein, weil:
___________________________________________
```

---

**Template erstellt:** 2025-11-27
**Von:** Dimitri Volkov (MQL5 Developer)
**Für:** Markus Schnittker - SwingEA Demo-Testing
