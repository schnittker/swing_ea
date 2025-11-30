//+------------------------------------------------------------------+
//|                  EMA10/EMA20 Scalping EA                         |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

input int EMA10_Period = 5;   // Kürzere EMA für M15
input int EMA20_Period = 10;  // Kürzere EMA für M15
input ENUM_TIMEFRAMES Timeframe = PERIOD_M15; // 15-Minuten Chart

CTrade trade;

//--- globale Handles für EMA
int ema10Handle;
int ema20Handle;

//+------------------------------------------------------------------+
//| Initialisierung                                                  |
//+------------------------------------------------------------------+
int OnInit()
{
    ema10Handle = iMA(_Symbol, Timeframe, EMA10_Period, 0, MODE_EMA, PRICE_CLOSE);
    ema20Handle = iMA(_Symbol, Timeframe, EMA20_Period, 0, MODE_EMA, PRICE_CLOSE);

    if(ema10Handle == INVALID_HANDLE || ema20Handle == INVALID_HANDLE)
    {
        Print("Fehler beim Erstellen der EMA Handles!");
        return(INIT_FAILED);
    }

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Drawdown in Prozent                                              |
//+------------------------------------------------------------------+
double AccountDDPercent()
{
    double dd = 0;
    if(AccountInfoDouble(ACCOUNT_BALANCE) > 0)
        dd = (AccountInfoDouble(ACCOUNT_BALANCE) - AccountInfoDouble(ACCOUNT_EQUITY)) / AccountInfoDouble(ACCOUNT_BALANCE) * 100;
    return dd;
}

//+------------------------------------------------------------------+
//| Risiko je nach Drawdown                                          |
//+------------------------------------------------------------------+
double RiskPercent()
{
    double dd = AccountDDPercent();
    if(dd <= 2) return 1.0;
    if(dd <= 3) return 0.5;
    if(dd <= 10) return 0.25;
    return 0.1;
}

//+------------------------------------------------------------------+
//| Lot-Berechnung                                                   |
//+------------------------------------------------------------------+
double LotsForRisk(double stopLossPips)
{
    double risk = RiskPercent() / 100.0;
    double lot = (AccountInfoDouble(ACCOUNT_BALANCE) * risk) / (stopLossPips * _Point * 10); // grobe Kalkulation
    lot = MathMax(lot, 0.01); // minimal 0.01 Lot
    return lot;
}

//+------------------------------------------------------------------+
//| EMA-Wert aus Handle abrufen                                       |
//+------------------------------------------------------------------+
double EMAValue(int handle, int shift=0)
{
    double buffer[];
    if(CopyBuffer(handle,0,shift,1,buffer) > 0)
        return buffer[0];
    return 0;
}

//+------------------------------------------------------------------+
//| Letzte Kerze High/Low                                             |
//+------------------------------------------------------------------+
double LastCandleLow()
{
    return iLow(_Symbol, Timeframe, 1);
}

double LastCandleHigh()
{
    return iHigh(_Symbol, Timeframe, 1);
}

//+------------------------------------------------------------------+
//| OnTick-Funktion                                                 |
//+------------------------------------------------------------------+
void OnTick()
{
    static datetime lastTradeTime = 0;

    // nur 1 Trade pro Kerze
    if(lastTradeTime == iTime(_Symbol, Timeframe, 0))
        return;

    // EMA Werte
    double ema10 = EMAValue(ema10Handle);
    double ema20 = EMAValue(ema20Handle);
    double ema10_prev = EMAValue(ema10Handle,1);
    double ema20_prev = EMAValue(ema20Handle,1);

    // Trade-Variablen deklarieren
    double sl = 0, tp = 0, stopPips = 0, lot = 0;

    // Aktuelle Preise abrufen
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    //--- Long Signal
    if(ema10_prev < ema20_prev && ema10 > ema20)
    {
        sl = LastCandleLow() - 5*_Point;
        stopPips = (ask - sl)/_Point;
        tp = ask + (stopPips * 2.0 * _Point); // 1:2 Risk/Reward
        lot = LotsForRisk(stopPips);

        if(trade.Buy(lot,_Symbol,ask,sl,tp,"EMA Cross Long"))
            lastTradeTime = iTime(_Symbol, Timeframe, 0);
        else
            Print("Buy Fehler: ", GetLastError());
    }

    //--- Short Signal
    else if(ema10_prev > ema20_prev && ema10 < ema20)
    {
        sl = LastCandleHigh() + 5*_Point;
        stopPips = (sl - bid)/_Point;
        tp = bid - (stopPips * 2.0 * _Point); // 1:2 Risk/Reward
        lot = LotsForRisk(stopPips);

        if(trade.Sell(lot,_Symbol,bid,sl,tp,"EMA Cross Short"))
            lastTradeTime = iTime(_Symbol, Timeframe, 0);
        else
            Print("Sell Fehler: ", GetLastError());
    }
}
