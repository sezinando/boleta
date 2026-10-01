#property strict
#property version   "0.30"
#property description "BOLETA OPERACIONAL - visual order planner and manual execution"

input bool   InpTestMode    = false;
input double InpLots        = 0.01;
input double InpLotStep     = 0.01;
input int    InpMagic       = 1001;
input int    InpSlippage    = 30;
input int    InpMaxSpread   = 100;
input string InpComment     = "BOLETA";

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

#define LINE_ENTRY      PFX+"LINE_ENTRY"
#define LINE_SL         PFX+"LINE_SL"
#define LINE_TP         PFX+"LINE_TP"

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

int PanelX = 10;
int PanelY = 20;
int PanelW = 310;
int PanelH = 500;

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

void ShowExecutionMessage(string text,color clr)
{
   SetLabelText(OBJ_STATUS,text);
   if(ObjectFind(0,OBJ_STATUS)>=0)
      ObjectSetInteger(0,OBJ_STATUS,OBJPROP_COLOR,clr);
}

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
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
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
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,name,OBJPROP_ALIGN,ALIGN_CENTER);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
}

void CreateHLine(string name,double price,color clr,string tooltip)
{
   DeleteObject(name);

   ObjectCreate(0,name,OBJ_HLINE,0,0,price);
   ObjectSetDouble(0,name,OBJPROP_PRICE,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DASH);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
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

   double value = StrToDouble(ObjectGetString(0,OBJ_LOT_EDIT,OBJPROP_TEXT));

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

double AccountImpact(double money)
{
   double equity = AccountEquity();

   if(equity <= 0.0)
      return(0.0);

   return((money/equity)*100.0);
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
      SetLabelText(OBJ_RISK,"Risco (SL):  $ 0.00   0.000%");
      SetLabelText(OBJ_GAIN,"Ganho (TP):  $ 0.00   0.000%");
      SetLabelText(OBJ_RR,"Relação R:R:  1 : 0.00");
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

   SetLabelText(OBJ_RISK,
      StringFormat("Risco (SL):  -$ %.2f   -%.3f%%",riskMoney,riskPct));

   SetLabelText(OBJ_GAIN,
      StringFormat("Ganho (TP):  +$ %.2f   +%.3f%%",gainMoney,gainPct));

   SetLabelText(OBJ_RR,
      StringFormat("Relação R:R:  1 : %.2f",rr));

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

   if(direction == DIR_BUY)
   {
      SetLabelText(OBJ_STATUS,"DIREÇÃO: BUY | "+(g_plannerActive ? "PLANEJAMENTO" : "MERCADO"));
   }
   else
   {
      SetLabelText(OBJ_STATUS,"DIREÇÃO: SELL | "+(g_plannerActive ? "PLANEJAMENTO" : "MERCADO"));
   }

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
   // Não usamos Ask/Bid como entrada porque isso transforma a ordem em
   // uma condição inválida para OP_BUYSTOP/OP_SELLSTOP em muitas corretoras.
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

   SetLabelText(OBJ_STATUS,
      StringFormat("PLANEJAMENTO %s | ajuste as linhas e confirme",
                   g_direction == DIR_BUY ? "BUY" : "SELL"));

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

   SetLabelText(OBJ_STATUS,
      StringFormat("DIREÇÃO: %s | PRONTO",
                   g_direction == DIR_BUY ? "BUY" : "SELL"));

   UpdatePlanner();
   ChartRedraw();
}

bool TradeEnvironmentOK()
{
   if(InpTestMode)
      return(true);

   if(!IsTradeAllowed())
   {
      Print("[BOLETA][BLOCKED] Trading not allowed.");
      return(false);
   }

   RefreshRates();

   double spread = (Ask-Bid)/Point;

   if(spread > InpMaxSpread)
   {
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

   if(InpTestMode)
   {
      ShowExecutionMessage("TEST MODE — ordem NAO enviada",clrOrange);
      PrintFormat("[BOLETA][TEST] MARKET %s %.2f lots",
                  type == OP_BUY ? "BUY" : "SELL",g_lots);
      return(true);
   }

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

   if(InpTestMode)
   {
      ShowExecutionMessage("TEST MODE — ordem NAO enviada",clrOrange);
      PrintFormat("[BOLETA][TEST] PENDING %s %s lot=%.2f entry=%.*f sl=%.*f tp=%.*f",
                  g_direction == DIR_BUY ? "BUY" : "SELL",
                  PendingType(),g_lots,
                  Digits,g_entry,Digits,g_sl,Digits,g_tp);
      return(true);
   }

   if(!TradeEnvironmentOK())
      return(false);

   ResetLastError();

   int ticket = OrderSend(Symbol(),type,g_lots,g_entry,InpSlippage,
                          g_sl,g_tp,InpComment,InpMagic,0,clrDodgerBlue);

   if(ticket < 0)
   {
      int error=GetLastError();
      ShowExecutionMessage(StringFormat("PENDENTE RECUSADA | %d | %s",error,ErrorText(error)),clrRed);
      PrintFormat("[BOLETA][ERROR] Pending order failed. Error=%d (%s)",error,ErrorText(error));
      return(false);
   }

   ShowExecutionMessage(StringFormat("PENDENTE ENVIADA | Ticket %d | %s",
                                     ticket,PendingType()),clrLime);
   PrintFormat("[BOLETA][OK] PENDING ticket=%d type=%s lot=%.2f",
               ticket,PendingType(),g_lots);
   return(true);
}

void CloseAll()
{
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

      if(InpTestMode)
      {
         PrintFormat("[BOLETA][TEST] CLOSE ticket=%d lot=%.2f",
                     OrderTicket(),OrderLots());
         continue;
      }

      RefreshRates();

      double price = (OrderType() == OP_BUY ? Bid : Ask);

      ResetLastError();

      if(!OrderClose(OrderTicket(),OrderLots(),price,InpSlippage,clrWhite))
         PrintFormat("[BOLETA][ERROR] Close ticket=%d error=%d",
                     OrderTicket(),GetLastError());
   }
}

void BuildPanel()
{
   CreateBackground();

   CreateLabel(OBJ_TITLE,"BOLETA OPERACIONAL  v0.30",
               PanelX+15,PanelY+12,12,clrWhite,true);

   CreateLabel(OBJ_STATUS,"DIREÇÃO: BUY | PRONTO",
               PanelX+15,PanelY+34,8,clrSilver,false);

   CreateButton(OBJ_LOT_MINUS,"-",PanelX+70,PanelY+55,32,28,C'30,40,55',clrWhite);
   CreateEdit(OBJ_LOT_EDIT,DoubleToString(g_lots,2),
              PanelX+105,PanelY+55,90,28);
   CreateButton(OBJ_LOT_PLUS,"+",PanelX+200,PanelY+55,32,28,C'30,40,55',clrWhite);

   CreateButton(OBJ_PRE_001,"0.01",PanelX+15,PanelY+92,60,22,C'20,28,40',clrSilver);
   CreateButton(OBJ_PRE_002,"0.02",PanelX+80,PanelY+92,60,22,C'20,28,40',clrSilver);
   CreateButton(OBJ_PRE_005,"0.05",PanelX+145,PanelY+92,60,22,C'20,28,40',clrSilver);
   CreateButton(OBJ_PRE_010,"0.10",PanelX+210,PanelY+92,60,22,C'20,28,40',clrSilver);

   CreateButton(OBJ_BUY,"BUY\n@ MERCADO",
                PanelX+15,PanelY+125,130,44,clrGreen,clrWhite);
   CreateButton(OBJ_SELL,"SELL\n@ MERCADO",
                PanelX+150,PanelY+125,130,44,clrFireBrick,clrWhite);

   CreateButton(OBJ_DRAW,"DESENHAR ORDEM\nEntrada + Stop + Gain",
                PanelX+15,PanelY+180,265,42,clrDodgerBlue,clrWhite);

   CreateButton(OBJ_CONFIRM,"CONFIRMAR",
                PanelX+15,PanelY+230,130,30,C'25,90,45',clrWhite);
   CreateButton(OBJ_CANCEL,"CANCELAR",
                PanelX+150,PanelY+230,130,30,C'120,35,35',clrWhite);

   CreateLabel(OBJ_RISK,"Risco (SL):  $ 0.00   0.000%",
               PanelX+20,PanelY+280,9,clrRed);
   CreateLabel(OBJ_GAIN,"Ganho (TP):  $ 0.00   0.000%",
               PanelX+20,PanelY+302,9,clrLime);
   CreateLabel(OBJ_RR,"Relação R:R:  1 : 0.00",
               PanelX+20,PanelY+324,9,clrWhite,true);

   CreateLabel(OBJ_ENTRY_INFO,"Entrada: —",
               PanelX+20,PanelY+350,8,clrSilver);
   CreateLabel(OBJ_SL_INFO,"Stop:    —",
               PanelX+20,PanelY+370,8,clrSilver);
   CreateLabel(OBJ_TP_INFO,"Gain:    —",
               PanelX+20,PanelY+390,8,clrSilver);

   CreateButton(OBJ_CLOSE_ALL,"X  FECHAR TUDO",
                PanelX+15,PanelY+445,265,35,C'150,30,30',clrWhite);

   ChartRedraw();
}

void UpdateStatus()
{
   string mode = (InpTestMode ? "TEST" : "LIVE");

   string text = StringFormat("%s | %s | Magic %d | Spread %.1f",
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

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
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
      OBJ_CLOSE_ALL
   };

   for(int i=0;i<ArraySize(names);i++)
      DeleteObject(names[i]);

   ChartRedraw();
}

void OnTick()
{
   UpdateStatus();

   if(g_plannerActive)
      UpdatePlanner();
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

   ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
   ChartRedraw();
}
