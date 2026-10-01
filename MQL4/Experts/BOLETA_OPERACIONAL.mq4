#property strict
#property version   "0.41"
#property description "BOLETA OPERACIONAL - visual order planner, manual execution and results"

input double InpLots             = 0.01;
input double InpLotStep          = 0.01;
input int    InpMagic            = 1001;
input int    InpSlippage         = 30;
input int    InpMaxSpread        = 100;
input string InpComment          = "BOLETA";
input bool   InpResultAllSymbols = false;   // resultado: false = so este simbolo | true = todos (mesmo magic)

#define PFX             "BOLETA_"

#define OBJ_BG          PFX+"BG"
#define OBJ_TITLE       PFX+"TITLE"
#define OBJ_STATUS      PFX+"STATUS"
#define OBJ_LOT_MINUS   PFX+"LOT_MINUS"
#define OBJ_LOT_EDIT    PFX+"LOT_EDIT"
#define OBJ_LOT_PLUS    PFX+"LOT_PLUS"
#define OBJ_PRE_001     PFX+"PRE_001"
#define OBJ_PRE_002     PFX+"PRE_002"
#define OBJ_PRE_005     PFX+"PRE_005"
#define OBJ_PRE_010     PFX+"PRE_010"
#define OBJ_BUY         PFX+"BUY"
#define OBJ_SELL        PFX+"SELL"
#define OBJ_DRAW        PFX+"DRAW"
#define OBJ_CONFIRM     PFX+"CONFIRM"
#define OBJ_CANCEL      PFX+"CANCEL"
#define OBJ_RISK        PFX+"RISK"
#define OBJ_GAIN        PFX+"GAIN"
#define OBJ_RR          PFX+"RR"
#define OBJ_ENTRY_INFO  PFX+"ENTRY_INFO"
#define OBJ_SL_INFO     PFX+"SL_INFO"
#define OBJ_TP_INFO     PFX+"TP_INFO"
#define OBJ_CLOSE_ALL   PFX+"CLOSE_ALL"

// --- novos: bloco de resultados ---
#define OBJ_RES_TITLE   PFX+"RES_TITLE"
#define OBJ_RES_OPEN    PFX+"RES_OPEN"
#define OBJ_RES_CLOSED  PFX+"RES_CLOSED"
#define OBJ_RES_TOTAL   PFX+"RES_TOTAL"
#define OBJ_MSG         PFX+"MSG"

#define LINE_ENTRY      PFX+"LINE_ENTRY"
#define LINE_SL         PFX+"LINE_SL"
#define LINE_TP         PFX+"LINE_TP"

// cores de resultado
#define CLR_POS         clrLime
#define CLR_NEG         clrTomato
#define CLR_ZERO        clrSilver

enum PlannerDirection
{
   DIR_BUY = OP_BUY,
   DIR_SELL = OP_SELL
};

bool   g_plannerActive = false;
int    g_direction = DIR_BUY;
double g_lots = 0.01;
double g_entry = 0.0;
double g_sl = 0.0;
double g_tp = 0.0;

// resultados
double g_openPL     = 0.0;
int    g_openCount  = 0;
int    g_pendCount  = 0;
double g_closedPL   = 0.0;
int    g_closedCount= 0;
uint   g_lastHist   = 0;

int PanelX = 10;
int PanelY = 15;
int PanelW = 250;
int PanelH = 380;

// forward declarations
void UpdatePlanner();
void RebuildPlannerForDirection();
void UpdateResults(bool force);

//+------------------------------------------------------------------+
void DeleteObject(string name)
{
   if(ObjectFind(0,name) >= 0)
      ObjectDelete(0,name);
}

void CreateBackground()
{
   DeleteObject(OBJ_BG);

   ObjectCreate(0,OBJ_BG,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,OBJ_BG,OBJPROP_XDISTANCE,PanelX);
   ObjectSetInteger(0,OBJ_BG,OBJPROP_YDISTANCE,PanelY);
   ObjectSetInteger(0,OBJ_BG,OBJPROP_XSIZE,PanelW);
   ObjectSetInteger(0,OBJ_BG,OBJPROP_YSIZE,PanelH);
   ObjectSetInteger(0,OBJ_BG,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,OBJ_BG,OBJPROP_BGCOLOR,C'13,17,26');
   ObjectSetInteger(0,OBJ_BG,OBJPROP_BORDER_COLOR,C'55,65,81');
   ObjectSetInteger(0,OBJ_BG,OBJPROP_BACK,false);
   ObjectSetInteger(0,OBJ_BG,OBJPROP_SELECTABLE,false);
}

void CreateLabel(string name,string text,int x,int y,int size,color clr,bool bold=false)
{
   DeleteObject(name);

   ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetString(0,name,OBJPROP_TEXT,text);

   if(bold)
      ObjectSetString(0,name,OBJPROP_FONT,"Arial Bold");
}

void SetLabelText(string name,string text)
{
   if(ObjectFind(0,name) >= 0)
      ObjectSetString(0,name,OBJPROP_TEXT,text);
}

void SetLabel(string name,string text,color clr)
{
   if(ObjectFind(0,name) < 0)
      return;
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
}

// Mensagens vao para a linha propria OBJ_MSG (o OBJ_STATUS e reescrito a cada tick)
void ShowExecutionMessage(string text,color clr)
{
   SetLabel(OBJ_MSG,text,clr);
}

//+------------------------------------------------------------------+
//| Formatacao / cores de resultado                                  |
//+------------------------------------------------------------------+
color PnLColor(double v)
{
   if(v > 0.005)  return(CLR_POS);
   if(v < -0.005) return(CLR_NEG);
   return(CLR_ZERO);
}

string FmtMoney(double v)
{
   if(MathAbs(v) < 0.005)
      return("$ 0.00");
   return(StringFormat("%s$ %.2f",(v > 0.0 ? "+" : "-"),MathAbs(v)));
}

// percentual do valor em relacao ao SALDO da conta
string FmtPct(double money)
{
   double bal = AccountBalance();
   double p   = (bal > 0.0 ? money/bal*100.0 : 0.0);

   if(MathAbs(p) < 0.0005)
      return("0.000%");
   return(StringFormat("%s%.3f%%",(p > 0.0 ? "+" : "-"),MathAbs(p)));
}

bool IsMine()
{
   if(OrderMagicNumber() != InpMagic)
      return(false);
   if(!InpResultAllSymbols && OrderSymbol() != Symbol())
      return(false);
   return(true);
}

void CalcOpen()
{
   g_openPL = 0.0;
   g_openCount = 0;
   g_pendCount = 0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(!IsMine())
         continue;

      int t = OrderType();
      if(t == OP_BUY || t == OP_SELL)
      {
         g_openPL += OrderProfit() + OrderSwap() + OrderCommission();
         g_openCount++;
      }
      else
         g_pendCount++;
   }
}

void CalcClosed()
{
   g_closedPL = 0.0;
   g_closedCount = 0;

   datetime dayStart = StringToTime(TimeToString(TimeCurrent(),TIME_DATE));

   for(int i=OrdersHistoryTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))
         continue;
      if(!IsMine())
         continue;

      int t = OrderType();
      if(t != OP_BUY && t != OP_SELL)
         continue;

      if(OrderCloseTime() < dayStart)
         continue;

      g_closedPL += OrderProfit() + OrderSwap() + OrderCommission();
      g_closedCount++;
   }
}

// force=true recalcula tambem o historico (senao no maximo 1x por segundo)
void UpdateResults(bool force)
{
   CalcOpen();

   uint now = GetTickCount();
   if(force || now - g_lastHist >= 1000)
   {
      CalcClosed();
      g_lastHist = now;
   }

   double total = g_openPL + g_closedPL;

   SetLabel(OBJ_RES_TITLE,
            StringFormat("RESULTADO   |   Saldo: $ %.2f",AccountBalance()),
            clrSilver);

   string pend = (g_pendCount > 0 ? StringFormat(" +%d pend.",g_pendCount) : "");

   SetLabel(OBJ_RES_OPEN,
            StringFormat("Abertas (%d)%s:   %s   %s",
                         g_openCount,pend,FmtMoney(g_openPL),FmtPct(g_openPL)),
            PnLColor(g_openPL));

   SetLabel(OBJ_RES_CLOSED,
            StringFormat("Fechadas hoje (%d):   %s   %s",
                         g_closedCount,FmtMoney(g_closedPL),FmtPct(g_closedPL)),
            PnLColor(g_closedPL));

   SetLabel(OBJ_RES_TOTAL,
            StringFormat("TOTAL DO DIA:   %s   %s",FmtMoney(total),FmtPct(total)),
            PnLColor(total));
}

//+------------------------------------------------------------------+
bool ValidateLots()
{
   double minLot=MarketInfo(Symbol(),MODE_MINLOT);
   double maxLot=MarketInfo(Symbol(),MODE_MAXLOT);
   double step=MarketInfo(Symbol(),MODE_LOTSTEP);

   if(g_lots < minLot || g_lots > maxLot)
   {
      ShowExecutionMessage(StringFormat("ERRO LOTE: %.2f | permitido %.2f - %.2f",g_lots,minLot,maxLot),clrRed);
      return(false);
   }

   if(step>0.0)
   {
      double units=g_lots/step;
      if(MathAbs(units-MathRound(units))>0.000001)
      {
         ShowExecutionMessage(StringFormat("ERRO LOTE: %.2f | step %.2f",g_lots,step),clrRed);
         return(false);
      }
   }
   return(true);
}

bool ValidatePendingDistances(int type)
{
   RefreshRates();

   double point=MarketInfo(Symbol(),MODE_POINT);
   int stopLevel=(int)MarketInfo(Symbol(),MODE_STOPLEVEL);
   int freezeLevel=(int)MarketInfo(Symbol(),MODE_FREEZELEVEL);
   double minDistance=MathMax(stopLevel,freezeLevel)*point;

   if(type==OP_BUYLIMIT && g_entry >= Ask-minDistance)
      return(false);
   if(type==OP_BUYSTOP && g_entry <= Ask+minDistance)
      return(false);
   if(type==OP_SELLLIMIT && g_entry <= Bid+minDistance)
      return(false);
   if(type==OP_SELLSTOP && g_entry >= Bid-minDistance)
      return(false);

   if(g_direction==DIR_BUY &&
      (g_entry-g_sl < minDistance || g_tp-g_entry < minDistance))
      return(false);

   if(g_direction==DIR_SELL &&
      (g_sl-g_entry < minDistance || g_entry-g_tp < minDistance))
      return(false);

   return(true);
}

string ErrorText(int error)
{
   switch(error)
   {
      case 0: return("OK");
      case 1: return("No result");
      case 2: return("Common error");
      case 3: return("Invalid trade parameters");
      case 4: return("Trade server busy");
      case 5: return("Old terminal");
      case 6: return("No connection");
      case 8: return("Too frequent requests");
      case 64: return("Account disabled");
      case 65: return("Invalid account");
      case 128: return("Trade timeout");
      case 129: return("Invalid price");
      case 130: return("Invalid stops");
      case 131: return("Invalid volume");
      case 132: return("Market closed");
      case 133: return("Trade disabled");
      case 134: return("Not enough money");
      case 135: return("Price changed");
      case 136: return("Off quotes");
      case 137: return("Broker busy");
      case 138: return("Requote");
      case 139: return("Order locked");
      case 146: return("Trade context busy");
      case 147: return("Expiration denied");
      case 148: return("Too many orders");
      default: return("MT4 error "+IntegerToString(error));
   }
}

void CreateButton(string name,string text,int x,int y,int w,int h,color bg,color fg)
{
   DeleteObject(name);

   ObjectCreate(0,name,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_COLOR,fg);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
}

void CreateEdit(string name,string text,int x,int y,int w,int h)
{
   DeleteObject(name);

   ObjectCreate(0,name,OBJ_EDIT,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,clrBlack);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,name,OBJPROP_ALIGN,ALIGN_CENTER);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
}

void CreateHLine(string name,double price,color clr,string tooltip)
{
   DeleteObject(name);

   // Segmento horizontal curto, somente no lado direito do chart.
   // OBJ_HLINE atravessa todo o gráfico; OBJ_TREND com RAY=false
   // permite limitar visualmente o comprimento da linha.
   int bars = WindowBarsPerChart();
   if(bars < 8)
      bars = 8;

   int rightShift = MathMax(1,bars / 4);
   int leftShift  = MathMax(0,bars / 16);

   datetime t1 = iTime(Symbol(),Period(),rightShift);
   datetime t2 = iTime(Symbol(),Period(),leftShift);

   if(t1 <= 0 || t2 <= 0)
   {
      int sec = PeriodSeconds();
      if(sec <= 0) sec = 60;
      t1 = TimeCurrent() - sec*rightShift;
      t2 = TimeCurrent() - sec*leftShift;
   }

   ObjectCreate(0,name,OBJ_TREND,0,t1,price,t2,price);
   ObjectSetDouble(0,name,OBJPROP_PRICE1,price);
   ObjectSetDouble(0,name,OBJPROP_PRICE2,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DASH);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,name,OBJPROP_RAY,false);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,true);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,tooltip);
}

double NormalizeLots(double lots)
{
   double minLot = MarketInfo(Symbol(),MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(),MODE_MAXLOT);
   double step   = MarketInfo(Symbol(),MODE_LOTSTEP);

   if(InpLotStep > 0.0)
      step = InpLotStep;

   if(step <= 0.0)
      step = 0.01;

   lots = MathMax(minLot,MathMin(maxLot,lots));
   lots = MathRound(lots/step)*step;

   int digits = 2;
   if(step >= 1.0) digits = 0;
   else if(step >= 0.1) digits = 1;

   return(NormalizeDouble(lots,digits));
}

void ReadLot()
{
   if(ObjectFind(0,OBJ_LOT_EDIT) < 0)
      return;

   string txt = ObjectGetString(0,OBJ_LOT_EDIT,OBJPROP_TEXT);
   StringReplace(txt,",",".");           // aceita "0,05"
   double value = StrToDouble(txt);

   if(value <= 0.0)
      value = MarketInfo(Symbol(),MODE_MINLOT);

   g_lots = NormalizeLots(value);
   ObjectSetString(0,OBJ_LOT_EDIT,OBJPROP_TEXT,DoubleToString(g_lots,2));
}

void SetLot(double lots)
{
   g_lots = NormalizeLots(lots);
   ObjectSetString(0,OBJ_LOT_EDIT,OBJPROP_TEXT,DoubleToString(g_lots,2));
   UpdatePlanner();
}

void ChangeLot(double delta)
{
   ReadLot();
   SetLot(g_lots + delta);
}

double MoneyPerPriceUnitPerLot()
{
   double tickValue = MarketInfo(Symbol(),MODE_TICKVALUE);
   double tickSize  = MarketInfo(Symbol(),MODE_TICKSIZE);

   if(tickSize <= 0.0)
      return(0.0);

   return(tickValue/tickSize);
}

double PriceDistanceMoney(double p1,double p2,double lots)
{
   return(MathAbs(p1-p2)*MoneyPerPriceUnitPerLot()*lots);
}

// impacto em % em relacao ao SALDO da conta
double AccountImpact(double money)
{
   double balance = AccountBalance();

   if(balance <= 0.0)
      return(0.0);

   return((money/balance)*100.0);
}

bool GeometryValid()
{
   if(g_entry <= 0.0 || g_sl <= 0.0 || g_tp <= 0.0)
      return(false);

   if(g_direction == DIR_BUY)
      return(g_sl < g_entry && g_tp > g_entry);

   return(g_sl > g_entry && g_tp < g_entry);
}

string PendingType()
{
   RefreshRates();

   if(g_direction == DIR_BUY)
      return(g_entry < Ask ? "BUY LIMIT" : "BUY STOP");

   return(g_entry > Bid ? "SELL LIMIT" : "SELL STOP");
}

void UpdatePlanner()
{
   if(!g_plannerActive)
   {
      SetLabel(OBJ_RISK,"Risco (SL):  $ 0.00   0.000%",CLR_ZERO);
      SetLabel(OBJ_GAIN,"Ganho (TP):  $ 0.00   0.000%",CLR_ZERO);
      SetLabel(OBJ_RR,"Relação R:R:  1 : 0.00",clrWhite);
      SetLabelText(OBJ_ENTRY_INFO,"Entrada: —");
      SetLabelText(OBJ_SL_INFO,"Stop:    —");
      SetLabelText(OBJ_TP_INFO,"Gain:    —");
      return;
   }

   double riskMoney = PriceDistanceMoney(g_entry,g_sl,g_lots);
   double gainMoney = PriceDistanceMoney(g_entry,g_tp,g_lots);

   double riskPct = AccountImpact(riskMoney);
   double gainPct = AccountImpact(gainMoney);

   double riskPts = MathAbs(g_entry-g_sl)/Point;
   double gainPts = MathAbs(g_tp-g_entry)/Point;

   double rr = (riskMoney > 0.0 ? gainMoney/riskMoney : 0.0);

   SetLabel(OBJ_RISK,
      StringFormat("Risco (SL):  -$ %.2f   -%.3f%%",riskMoney,riskPct),CLR_NEG);

   SetLabel(OBJ_GAIN,
      StringFormat("Ganho (TP):  +$ %.2f   +%.3f%%",gainMoney,gainPct),CLR_POS);

   SetLabel(OBJ_RR,
      StringFormat("Relação R:R:  1 : %.2f",rr),
      (rr >= 1.0 ? CLR_POS : clrOrange));

   SetLabelText(OBJ_ENTRY_INFO,
      StringFormat("Entrada: %.5f   (%s)",g_entry,PendingType()));

   SetLabelText(OBJ_SL_INFO,
      StringFormat("Stop:    %.5f   %.0f pts",g_sl,riskPts));

   SetLabelText(OBJ_TP_INFO,
      StringFormat("Gain:    %.5f   %.0f pts",g_tp,gainPts));
}

void SetDirection(int direction)
{
   g_direction = direction;

   ShowExecutionMessage("DIREÇÃO: "+(direction == DIR_BUY ? "BUY" : "SELL")+
                        " | "+(g_plannerActive ? "PLANEJAMENTO" : "MERCADO"),clrSilver);

   if(g_plannerActive)
      RebuildPlannerForDirection();

   ChartRedraw();
}

void RebuildPlannerForDirection()
{
   if(!g_plannerActive)
      return;

   RefreshRates();

   double reference = (g_direction == DIR_BUY ? Ask : Bid);
   double offset = 200.0*Point;

   // A entrada inicial precisa nascer como uma pendente REALMENTE válida.
   if(g_direction == DIR_BUY)
   {
      g_entry = NormalizeDouble(reference + offset,Digits);
      g_sl    = NormalizeDouble(g_entry - offset,Digits);
      g_tp    = NormalizeDouble(g_entry + offset*2.0,Digits);
   }
   else
   {
      g_entry = NormalizeDouble(reference - offset,Digits);
      g_sl    = NormalizeDouble(g_entry + offset,Digits);
      g_tp    = NormalizeDouble(g_entry - offset*2.0,Digits);
   }

   CreateHLine(LINE_ENTRY,g_entry,clrDodgerBlue,"ENTRADA");
   CreateHLine(LINE_SL,g_sl,clrRed,"STOP LOSS");
   CreateHLine(LINE_TP,g_tp,clrLime,"TAKE PROFIT");

   UpdatePlanner();
}

void StartPlanner()
{
   ReadLot();
   g_plannerActive = true;

   RebuildPlannerForDirection();

   ShowExecutionMessage(
      StringFormat("PLANEJAMENTO %s | ajuste as linhas e confirme",
                   g_direction == DIR_BUY ? "BUY" : "SELL"),clrSilver);

   ObjectSetString(0,OBJ_DRAW,OBJPROP_TEXT,"ORDEM EM PLANEJAMENTO");
   ChartRedraw();
}

void CancelPlanner()
{
   DeleteObject(LINE_ENTRY);
   DeleteObject(LINE_SL);
   DeleteObject(LINE_TP);

   g_plannerActive = false;
   g_entry = 0.0;
   g_sl = 0.0;
   g_tp = 0.0;

   ObjectSetString(0,OBJ_DRAW,OBJPROP_TEXT,"DESENHAR ORDEM");

   UpdatePlanner();
   ChartRedraw();
}

bool TradeEnvironmentOK()
{
   if(!IsTradeAllowed())
   {
      int err=GetLastError();
      ShowExecutionMessage(StringFormat("TRADING BLOQUEADO | %d | %s",err,ErrorText(err)),clrRed);
      PrintFormat("[BOLETA][BLOCKED] Trading not allowed. Error=%d (%s)",err,ErrorText(err));
      return(false);
   }

   RefreshRates();

   double spread = (Ask-Bid)/Point;

   if(spread > InpMaxSpread)
   {
      ShowExecutionMessage(StringFormat("SPREAD ALTO: %.0f > %d pts",spread,InpMaxSpread),clrOrange);
      PrintFormat("[BOLETA][BLOCKED] Spread %.1f > %d",spread,InpMaxSpread);
      return(false);
   }

   return(true);
}

bool ExecuteMarket(int type)
{
   ReadLot();

   if(!ValidateLots())
      return(false);

   if(!TradeEnvironmentOK())
      return(false);

   RefreshRates();

   double price = (type == OP_BUY ? Ask : Bid);

   ResetLastError();

   int ticket = OrderSend(Symbol(),type,g_lots,price,InpSlippage,
                          0,0,InpComment,InpMagic,0,
                          type == OP_BUY ? clrGreen : clrRed);

   if(ticket < 0)
   {
      int error=GetLastError();
      ShowExecutionMessage(StringFormat("ORDEM RECUSADA | %d | %s",error,ErrorText(error)),clrRed);
      PrintFormat("[BOLETA][ERROR] Market order failed. Error=%d (%s)",error,ErrorText(error));
      return(false);
   }

   ShowExecutionMessage(StringFormat("EXECUTADO | Ticket %d | %s %.2f",
                                     ticket,type == OP_BUY ? "BUY" : "SELL",g_lots),clrLime);
   PrintFormat("[BOLETA][OK] MARKET ticket=%d type=%s lot=%.2f",
               ticket,type == OP_BUY ? "BUY" : "SELL",g_lots);
   return(true);
}

bool ExecutePending()
{
   ReadLot();

   if(!ValidateLots())
      return(false);

   if(!GeometryValid())
   {
      ShowExecutionMessage("ORDEM RECUSADA | geometria Entrada/Stop/Gain invalida",clrRed);
      Print("[BOLETA][BLOCKED] Invalid Entry/Stop/Gain geometry.");
      return(false);
   }

   int type;

   RefreshRates();

   if(g_direction == DIR_BUY)
      type = (g_entry < Ask ? OP_BUYLIMIT : OP_BUYSTOP);
   else
      type = (g_entry > Bid ? OP_SELLLIMIT : OP_SELLSTOP);

   if(!ValidatePendingDistances(type))
   {
      ShowExecutionMessage("ORDEM RECUSADA | distancia minima da corretora",clrRed);
      Print("[BOLETA][BLOCKED] Pending distance violates broker limits.");
      return(false);
   }

   if(!TradeEnvironmentOK())
      return(false);

   ResetLastError();

   g_entry = NormalizeDouble(g_entry,Digits);
   g_sl    = NormalizeDouble(g_sl,Digits);
   g_tp    = NormalizeDouble(g_tp,Digits);

   string typeName = PendingType();

   PrintFormat("[BOLETA][SEND] type=%d %s lot=%.2f entry=%s sl=%s tp=%s Ask=%s Bid=%s stop=%d freeze=%d",
               type,typeName,g_lots,
               DoubleToString(g_entry,Digits),DoubleToString(g_sl,Digits),DoubleToString(g_tp,Digits),
               DoubleToString(Ask,Digits),DoubleToString(Bid,Digits),
               (int)MarketInfo(Symbol(),MODE_STOPLEVEL),
               (int)MarketInfo(Symbol(),MODE_FREEZELEVEL));

   int ticket = OrderSend(Symbol(),type,g_lots,g_entry,InpSlippage,
                          g_sl,g_tp,InpComment,InpMagic,0,clrDodgerBlue);

   if(ticket < 0)
   {
      int error=GetLastError();
      ShowExecutionMessage(StringFormat("PENDENTE RECUSADA | %d | %s",error,ErrorText(error)),clrRed);
      PrintFormat("[BOLETA][ERROR] Pending order failed. Error=%d (%s)",error,ErrorText(error));
      return(false);
   }

   ShowExecutionMessage(StringFormat("PENDENTE ENVIADA | Ticket %d | %s",ticket,typeName),clrLime);
   PrintFormat("[BOLETA][OK] PENDING ticket=%d type=%s lot=%.2f",ticket,typeName,g_lots);
   return(true);
}

void CloseAll()
{
   int closed = 0;
   double pl = 0.0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != InpMagic)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      RefreshRates();

      double price = (OrderType() == OP_BUY ? Bid : Ask);
      double tradePL = OrderProfit() + OrderSwap() + OrderCommission();

      ResetLastError();

      if(OrderClose(OrderTicket(),OrderLots(),price,InpSlippage,clrWhite))
      {
         closed++;
         pl += tradePL;
      }
      else
         PrintFormat("[BOLETA][ERROR] Close ticket=%d error=%d",
                     OrderTicket(),GetLastError());
   }

   ShowExecutionMessage(StringFormat("FECHADAS %d | %s  %s",closed,FmtMoney(pl),FmtPct(pl)),
                        PnLColor(pl));
}

void BuildPanel()
{
   CreateBackground();

   int x = PanelX + 10;     // margem esquerda
   int w = PanelW - 20;     // largura util
   int hw = (w - 6) / 2;    // metade (botoes lado a lado)

   CreateLabel(OBJ_TITLE,"BOLETA  v0.41",
               x,PanelY+5,10,clrWhite,true);

   CreateLabel(OBJ_STATUS,"",
               x,PanelY+23,7,clrSilver,false);

   // lote
   CreateButton(OBJ_LOT_MINUS,"-",x,PanelY+38,24,20,C'30,40,55',clrWhite);
   CreateEdit(OBJ_LOT_EDIT,DoubleToString(g_lots,2),
              x+28,PanelY+38,w-56,20);
   CreateButton(OBJ_LOT_PLUS,"+",x+w-24,PanelY+38,24,20,C'30,40,55',clrWhite);

   // presets
   int pw = (w - 12) / 4;
   CreateButton(OBJ_PRE_001,"0.01",x,           PanelY+62,pw,17,C'20,28,40',clrSilver);
   CreateButton(OBJ_PRE_002,"0.02",x+(pw+4),    PanelY+62,pw,17,C'20,28,40',clrSilver);
   CreateButton(OBJ_PRE_005,"0.05",x+2*(pw+4),  PanelY+62,pw,17,C'20,28,40',clrSilver);
   CreateButton(OBJ_PRE_010,"0.10",x+3*(pw+4),  PanelY+62,pw,17,C'20,28,40',clrSilver);

   // mercado
   CreateButton(OBJ_BUY,"BUY MERCADO",
                x,PanelY+84,hw,26,clrGreen,clrWhite);
   CreateButton(OBJ_SELL,"SELL MERCADO",
                x+hw+6,PanelY+84,hw,26,clrFireBrick,clrWhite);

   // planejamento
   CreateButton(OBJ_DRAW,"DESENHAR ORDEM",
                x,PanelY+114,w,24,clrDodgerBlue,clrWhite);

   CreateButton(OBJ_CONFIRM,"CONFIRMAR",
                x,PanelY+142,hw,22,C'25,90,45',clrWhite);
   CreateButton(OBJ_CANCEL,"CANCELAR",
                x+hw+6,PanelY+142,hw,22,C'120,35,35',clrWhite);

   // risco / ganho
   CreateLabel(OBJ_RISK,"Risco (SL):  $ 0.00   0.000%",
               x+4,PanelY+172,8,CLR_ZERO);
   CreateLabel(OBJ_GAIN,"Ganho (TP):  $ 0.00   0.000%",
               x+4,PanelY+187,8,CLR_ZERO);
   CreateLabel(OBJ_RR,"Relação R:R:  1 : 0.00",
               x+4,PanelY+202,8,clrWhite,true);

   CreateLabel(OBJ_ENTRY_INFO,"Entrada: —",
               x+4,PanelY+222,7,clrSilver);
   CreateLabel(OBJ_SL_INFO,"Stop:    —",
               x+4,PanelY+235,7,clrSilver);
   CreateLabel(OBJ_TP_INFO,"Gain:    —",
               x+4,PanelY+248,7,clrSilver);

   // resultados
   CreateLabel(OBJ_RES_TITLE,"RESULTADO",
               x+4,PanelY+268,7,clrSilver,true);
   CreateLabel(OBJ_RES_OPEN,"Abertas (0):   $ 0.00   0.000%",
               x+4,PanelY+282,8,CLR_ZERO);
   CreateLabel(OBJ_RES_CLOSED,"Fechadas hoje (0):   $ 0.00   0.000%",
               x+4,PanelY+297,8,CLR_ZERO);
   CreateLabel(OBJ_RES_TOTAL,"TOTAL DO DIA:   $ 0.00   0.000%",
               x+4,PanelY+314,8,CLR_ZERO,true);

   CreateLabel(OBJ_MSG,"Pronto.",
               x+4,PanelY+332,7,clrSilver);

   CreateButton(OBJ_CLOSE_ALL,"X  FECHAR TUDO",
                x,PanelY+348,w,22,C'150,30,30',clrWhite);

   ChartRedraw();
}

void UpdateStatus()
{
   string mode = "LIVE";

   string text = StringFormat("%s | %s | Magic %d | Spr %.0f",
                              Symbol(),mode,InpMagic,
                              (Ask-Bid)/Point);

   SetLabelText(OBJ_STATUS,text);
}

int OnInit()
{
   g_lots = NormalizeLots(InpLots);

   BuildPanel();
   UpdateStatus();
   UpdatePlanner();
   UpdateResults(true);

   EventSetTimer(1);   // atualiza resultados mesmo sem ticks (fim de semana, mercado parado)

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();

   DeleteObject(LINE_ENTRY);
   DeleteObject(LINE_SL);
   DeleteObject(LINE_TP);

   string names[] =
   {
      OBJ_BG,OBJ_TITLE,OBJ_STATUS,
      OBJ_LOT_MINUS,OBJ_LOT_EDIT,OBJ_LOT_PLUS,
      OBJ_PRE_001,OBJ_PRE_002,OBJ_PRE_005,OBJ_PRE_010,
      OBJ_BUY,OBJ_SELL,OBJ_DRAW,OBJ_CONFIRM,OBJ_CANCEL,
      OBJ_RISK,OBJ_GAIN,OBJ_RR,
      OBJ_ENTRY_INFO,OBJ_SL_INFO,OBJ_TP_INFO,
      OBJ_RES_TITLE,OBJ_RES_OPEN,OBJ_RES_CLOSED,OBJ_RES_TOTAL,OBJ_MSG,
      OBJ_CLOSE_ALL
   };

   for(int i=0;i<ArraySize(names);i++)
      DeleteObject(names[i]);

   ChartRedraw();
}

void OnTick()
{
   UpdateStatus();
   UpdateResults(false);

   if(g_plannerActive)
      UpdatePlanner();
}

void OnTimer()
{
   UpdateResults(false);
   ChartRedraw();
}

void OnChartEvent(const int id,const long &lparam,
                  const double &dparam,const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_DRAG)
   {
      if(sparam == LINE_ENTRY)
         g_entry = NormalizeDouble(ObjectGetDouble(0,LINE_ENTRY,OBJPROP_PRICE),Digits);
      else if(sparam == LINE_SL)
         g_sl = NormalizeDouble(ObjectGetDouble(0,LINE_SL,OBJPROP_PRICE),Digits);
      else if(sparam == LINE_TP)
         g_tp = NormalizeDouble(ObjectGetDouble(0,LINE_TP,OBJPROP_PRICE),Digits);
      else
         return;

      UpdatePlanner();
      return;
   }

   if(id == CHARTEVENT_OBJECT_ENDEDIT && sparam == OBJ_LOT_EDIT)
   {
      ReadLot();
      UpdatePlanner();
      return;
   }

   if(id != CHARTEVENT_OBJECT_CLICK)
      return;

   if(sparam == OBJ_LOT_MINUS)
      ChangeLot(-InpLotStep);
   else if(sparam == OBJ_LOT_PLUS)
      ChangeLot(InpLotStep);
   else if(sparam == OBJ_PRE_001)
      SetLot(0.01);
   else if(sparam == OBJ_PRE_002)
      SetLot(0.02);
   else if(sparam == OBJ_PRE_005)
      SetLot(0.05);
   else if(sparam == OBJ_PRE_010)
      SetLot(0.10);
   else if(sparam == OBJ_BUY)
   {
      g_direction = DIR_BUY;

      if(g_plannerActive)
         SetDirection(DIR_BUY);
      else
         ExecuteMarket(OP_BUY);
   }
   else if(sparam == OBJ_SELL)
   {
      g_direction = DIR_SELL;

      if(g_plannerActive)
         SetDirection(DIR_SELL);
      else
         ExecuteMarket(OP_SELL);
   }
   else if(sparam == OBJ_DRAW)
   {
      if(!g_plannerActive)
         StartPlanner();
   }
   else if(sparam == OBJ_CONFIRM)
   {
      if(g_plannerActive)
      {
         if(ExecutePending())
            CancelPlanner();
      }
   }
   else if(sparam == OBJ_CANCEL)
      CancelPlanner();
   else if(sparam == OBJ_CLOSE_ALL)
      CloseAll();

   if(ObjectFind(0,sparam) >= 0)
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);

   UpdateResults(true);
   ChartRedraw();
}