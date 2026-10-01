#property strict
#property version   "0.20"
#property description "BOLETA - Operational visual order planner for MT4"

input bool   InpTestMode       = true;
input double InpLots           = 0.01;
input double InpLotStep        = 0.01;
input int    InpMagic          = 1001;
input int    InpSlippage       = 30;
input int    InpMaxSpread      = 100;
input string InpComment        = "BOLETA";

#define BTN_BUY         "BOLETA_BTN_BUY"
#define BTN_SELL        "BOLETA_BTN_SELL"
#define BTN_PENDING     "BOLETA_BTN_PENDING"
#define BTN_CONFIRM     "BOLETA_BTN_CONFIRM"
#define BTN_CANCEL      "BOLETA_BTN_CANCEL"
#define BTN_LOT_MINUS   "BOLETA_BTN_LOT_MINUS"
#define BTN_LOT_PLUS    "BOLETA_BTN_LOT_PLUS"
#define EDIT_LOT        "BOLETA_EDIT_LOT"
#define BTN_CLOSE_BUY   "BOLETA_BTN_CLOSE_BUY"
#define BTN_CLOSE_SELL  "BOLETA_BTN_CLOSE_SELL"
#define BTN_CLOSE_ALL   "BOLETA_BTN_CLOSE_ALL"
#define LBL_STATUS      "BOLETA_LBL_STATUS"
#define LBL_STATE       "BOLETA_LBL_STATE"
#define LBL_PENDING     "BOLETA_LBL_PENDING"
#define LBL_IMPACT      "BOLETA_LBL_IMPACT"
#define LINE_ENTRY      "BOLETA_LINE_ENTRY"
#define LINE_STOP       "BOLETA_LINE_STOP"
#define LINE_TP         "BOLETA_LINE_TP"

enum PendingDirection
{
   PENDING_NONE = -1,
   PENDING_BUY  = OP_BUY,
   PENDING_SELL = OP_SELL
};

bool   g_pendingMode=false;
int    g_pendingDirection=PENDING_BUY;
double g_lots=0.01;
double g_entry=0.0;
double g_stop=0.0;
double g_take=0.0;

bool CreateButton(string name,string text,int x,int y,int w,int h)
{
   if(ObjectFind(0,name)>=0)
      ObjectDelete(0,name);
   if(!ObjectCreate(0,name,OBJ_BUTTON,0,0,0))
      return(false);

   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   return(true);
}

bool CreateEdit(string name,string text,int x,int y,int w,int h)
{
   if(ObjectFind(0,name)>=0)
      ObjectDelete(0,name);
   if(!ObjectCreate(0,name,OBJ_EDIT,0,0,0))
      return(false);

   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,11);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_ALIGN,ALIGN_CENTER);
   return(true);
}

void SetLabel(string name,string text,int x,int y,int size=10)
{
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
}

void DeletePendingLines()
{
   ObjectDelete(0,LINE_ENTRY);
   ObjectDelete(0,LINE_STOP);
   ObjectDelete(0,LINE_TP);
   g_pendingMode=false;
   g_entry=0.0;
   g_stop=0.0;
   g_take=0.0;

   if(ObjectFind(0,BTN_CONFIRM)>=0)
      ObjectSetString(0,BTN_CONFIRM,OBJPROP_TEXT,"CONFIRMAR ORDEM");
   if(ObjectFind(0,BTN_PENDING)>=0)
      ObjectSetString(0,BTN_PENDING,OBJPROP_TEXT,"DESENHAR ORDEM");
}

void CreateHLine(string name,double price,color clr,string description)
{
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_HLINE,0,0,price);

   ObjectSetDouble(0,name,OBJPROP_PRICE,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DASH);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,description);
}

double NormalizeLots(double lots)
{
   double minLot=MarketInfo(Symbol(),MODE_MINLOT);
   double maxLot=MarketInfo(Symbol(),MODE_MAXLOT);
   double step=MarketInfo(Symbol(),MODE_LOTSTEP);
   if(InpLotStep>0.0)
      step=InpLotStep;

   lots=MathMax(minLot,MathMin(maxLot,lots));
   if(step>0.0)
      lots=MathRound(lots/step)*step;

   int digits=2;
   if(step>=1.0) digits=0;
   else if(step>=0.1) digits=1;
   return(NormalizeDouble(lots,digits));
}

void SyncLotEdit()
{
   if(ObjectFind(0,EDIT_LOT)>=0)
      ObjectSetString(0,EDIT_LOT,OBJPROP_TEXT,DoubleToString(g_lots,2));
}

void ReadLotEdit()
{
   if(ObjectFind(0,EDIT_LOT)<0)
      return;

   double lots=StrToDouble(ObjectGetString(0,EDIT_LOT,OBJPROP_TEXT));
   if(lots<=0.0)
      lots=MarketInfo(Symbol(),MODE_MINLOT);

   g_lots=NormalizeLots(lots);
   SyncLotEdit();
}

void ChangeLots(double delta)
{
   ReadLotEdit();
   g_lots=NormalizeLots(g_lots+delta);
   SyncLotEdit();
   UpdatePanel();
}

bool SpreadOK()
{
   RefreshRates();
   return(((Ask-Bid)/Point)<=InpMaxSpread);
}

double LotsByType(int typeFilter)
{
   double lots=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagic)
         continue;
      if(OrderType()!=typeFilter)
         continue;
      lots+=OrderLots();
   }
   return(lots);
}

int CountOrders(int typeFilter)
{
   int count=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagic)
         continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL)
         continue;
      if(typeFilter>=0 && OrderType()!=typeFilter)
         continue;
      count++;
   }
   return(count);
}

double ProfitByType(int typeFilter)
{
   double profit=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagic)
         continue;
      if(OrderType()!=typeFilter)
         continue;
      profit+=OrderProfit()+OrderSwap()+OrderCommission();
   }
   return(profit);
}

double MoneyPerPriceUnitPerLot()
{
   double tickValue=MarketInfo(Symbol(),MODE_TICKVALUE);
   double tickSize=MarketInfo(Symbol(),MODE_TICKSIZE);
   if(tickSize<=0.0)
      return(0.0);
   return(tickValue/tickSize);
}

double PriceDistanceMoney(double fromPrice,double toPrice,double lots)
{
   return(MathAbs(fromPrice-toPrice)*MoneyPerPriceUnitPerLot()*lots);
}

double AccountImpactPercent(double money)
{
   double base=AccountBalance();
   if(base<=0.0)
      return(0.0);
   return((money/base)*100.0);
}

bool PendingGeometryValid()
{
   if(g_entry<=0.0 || g_stop<=0.0 || g_take<=0.0)
      return(false);

   if(g_pendingDirection==PENDING_BUY)
      return(g_stop<g_entry && g_take>g_entry);
   if(g_pendingDirection==PENDING_SELL)
      return(g_stop>g_entry && g_take<g_entry);
   return(false);
}

string PendingTypeText()
{
   RefreshRates();
   if(g_pendingDirection==PENDING_BUY)
      return(g_entry<Ask ? "BUY LIMIT" : "BUY STOP");
   if(g_pendingDirection==PENDING_SELL)
      return(g_entry>Bid ? "SELL LIMIT" : "SELL STOP");
   return("—");
}

void UpdatePendingCalculations()
{
   if(!g_pendingMode)
   {
      SetLabel(LBL_PENDING,"ORDEM PENDENTE VISUAL: inativa",10,245,10);
      SetLabel(LBL_IMPACT,"DD: —    Gain: —    R:R: —",335,245,10);
      return;
   }

   double risk=PriceDistanceMoney(g_entry,g_stop,g_lots);
   double gain=PriceDistanceMoney(g_entry,g_take,g_lots);
   double riskPct=AccountImpactPercent(risk);
   double gainPct=AccountImpactPercent(gain);
   double riskPoints=MathAbs(g_entry-g_stop)/Point;
   double gainPoints=MathAbs(g_take-g_entry)/Point;
   double rr=(risk>0.0 ? gain/risk : 0.0);

   string dir=(g_pendingDirection==PENDING_BUY ? "BUY" : "SELL");

   SetLabel(LBL_PENDING,
      StringFormat("PENDENTE %s | %s | Entrada %.*f",
                   dir,PendingTypeText(),Digits,g_entry),
      10,245,10);

   SetLabel(LBL_IMPACT,
      StringFormat("DD -$%.2f (-%.3f%%) | Gain +$%.2f (+%.3f%%) | R:R 1:%.2f",
                   risk,riskPct,gain,gainPct,rr),
      335,245,10);

   SetLabel(LBL_STATE,
      StringFormat("Lote %.2f | Stop %.1f pts | Gain %.1f pts | Conta $%.2f",
                   g_lots,riskPoints,gainPoints,AccountBalance()),
      10,205,10);
}

void UpdatePanel()
{
   RefreshRates();

   double buyLots=LotsByType(OP_BUY);
   double sellLots=LotsByType(OP_SELL);
   double netLots=buyLots-sellLots;
   double spreadPoints=(Ask-Bid)/Point;

   SetLabel(LBL_STATUS,
      StringFormat("%s | %s | Magic=%d | Spread=%.1f",
                   Symbol(),InpTestMode?"TEST MODE":"LIVE MODE",
                   InpMagic,spreadPoints),
      10,10,10);

   if(!g_pendingMode)
      SetLabel(LBL_STATE,
         StringFormat("BUY %.2f / %d   SELL %.2f / %d   NET %.2f",
                      buyLots,CountOrders(OP_BUY),
                      sellLots,CountOrders(OP_SELL),netLots),
         10,205,10);

   UpdatePendingCalculations();
   ChartRedraw();
}

bool CanExecute(string action)
{
   if(InpTestMode)
   {
      PrintFormat("[BOLETA][TEST] ACTION=%s SYMBOL=%s LOT=%.2f MAGIC=%d",
                  action,Symbol(),g_lots,InpMagic);
      return(false);
   }

   if(!IsTradeAllowed())
   {
      Print("[BOLETA][ERROR] Trading is not allowed.");
      return(false);
   }

   if(!SpreadOK())
   {
      PrintFormat("[BOLETA][BLOCKED] Spread %.1f > Max %d",
                  (Ask-Bid)/Point,InpMaxSpread);
      return(false);
   }

   return(true);
}

bool OpenMarket(int type)
{
   string action=(type==OP_BUY ? "BUY" : "SELL");
   double lots=NormalizeLots(g_lots);

   if(!CanExecute(action))
      return(InpTestMode);

   RefreshRates();
   double price=(type==OP_BUY ? Ask : Bid);

   ResetLastError();
   int ticket=OrderSend(Symbol(),type,lots,price,InpSlippage,0,0,
                        InpComment,InpMagic,0,clrNONE);

   if(ticket<0)
   {
      PrintFormat("[BOLETA][ERROR] OrderSend %s failed. Error=%d",
                  action,GetLastError());
      return(false);
   }

   PrintFormat("[BOLETA][OK] %s ticket=%d lots=%.2f price=%.*f",
               action,ticket,lots,Digits,price);
   return(true);
}

bool CreatePendingOrder()
{
   if(!PendingGeometryValid())
   {
      Print("[BOLETA][BLOCKED] Geometry invalid.");
      return(false);
   }

   double lots=NormalizeLots(g_lots);
   int orderType=-1;

   RefreshRates();

   if(g_pendingDirection==PENDING_BUY)
      orderType=(g_entry<Ask ? OP_BUYLIMIT : OP_BUYSTOP);
   else
      orderType=(g_entry>Bid ? OP_SELLLIMIT : OP_SELLSTOP);

   string action=StringFormat(
      "PENDING_%s %s LOT=%.2f ENTRY=%.*f SL=%.*f TP=%.*f",
      g_pendingDirection==PENDING_BUY?"BUY":"SELL",
      orderType==OP_BUYLIMIT||orderType==OP_SELLLIMIT?"LIMIT":"STOP",
      lots,Digits,g_entry,Digits,g_stop,Digits,g_take);

   if(InpTestMode)
   {
      PrintFormat("[BOLETA][TEST] %s",action);
      return(true);
   }

   if(!CanExecute(action))
      return(false);

   ResetLastError();
   int ticket=OrderSend(Symbol(),orderType,lots,g_entry,InpSlippage,
                        g_stop,g_take,InpComment,InpMagic,0,clrNONE);

   if(ticket<0)
   {
      PrintFormat("[BOLETA][ERROR] Pending OrderSend failed. Error=%d",
                  GetLastError());
      return(false);
   }

   PrintFormat("[BOLETA][OK] PENDING ticket=%d type=%d lots=%.2f",
               ticket,orderType,lots);
   return(true);
}

void StartPendingVisual()
{
   ReadLotEdit();
   RefreshRates();

   g_pendingMode=true;

   if(g_pendingDirection==PENDING_BUY)
   {
      g_entry=NormalizeDouble(Ask,Digits);
      g_stop=NormalizeDouble(g_entry-100*Point,Digits);
      g_take=NormalizeDouble(g_entry+200*Point,Digits);
   }
   else
   {
      g_entry=NormalizeDouble(Bid,Digits);
      g_stop=NormalizeDouble(g_entry+100*Point,Digits);
      g_take=NormalizeDouble(g_entry-200*Point,Digits);
   }

   CreateHLine(LINE_ENTRY,g_entry,clrDodgerBlue,
               "ENTRADA — arraste para ajustar");
   CreateHLine(LINE_STOP,g_stop,clrRed,
               "STOP LOSS — arraste para ajustar");
   CreateHLine(LINE_TP,g_take,clrLime,
               "TAKE PROFIT — arraste para ajustar");

   ObjectSetString(0,BTN_PENDING,OBJPROP_TEXT,"LINHAS ATIVAS");

   PrintFormat("[BOLETA][VISUAL] Started %s lot=%.2f",
               g_pendingDirection==PENDING_BUY?"BUY":"SELL",g_lots);

   UpdatePanel();
}

void CancelPendingVisual()
{
   if(g_pendingMode)
      Print("[BOLETA][VISUAL] Pending visual cancelled.");

   DeletePendingLines();
   UpdatePanel();
}

int CloseOrders(int typeFilter)
{
   int closed=0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagic)
         continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL)
         continue;
      if(typeFilter>=0 && OrderType()!=typeFilter)
         continue;

      int ticket=OrderTicket();
      double lots=OrderLots();

      if(InpTestMode)
      {
         PrintFormat("[BOLETA][TEST] ACTION=CLOSE ticket=%d type=%s lots=%.2f",
                     ticket,OrderType()==OP_BUY?"BUY":"SELL",lots);
         continue;
      }

      RefreshRates();
      double price=(OrderType()==OP_BUY ? Bid : Ask);

      ResetLastError();
      if(OrderClose(ticket,lots,price,InpSlippage,clrNONE))
         closed++;
      else
         PrintFormat("[BOLETA][ERROR] CLOSE ticket=%d error=%d",
                     ticket,GetLastError());
   }

   return(closed);
}

void BuildUI()
{
   CreateButton(BTN_LOT_MINUS,"−",10,45,35,25);
   CreateEdit(EDIT_LOT,DoubleToString(g_lots,2),48,45,120,25);
   CreateButton(BTN_LOT_PLUS,"+",173,45,35,25);

   CreateButton(BTN_BUY,"BUY",10,75,145,34);
   CreateButton(BTN_SELL,"SELL",160,75,145,34);

   CreateButton(BTN_PENDING,"DESENHAR ORDEM",10,120,295,38);
   CreateButton(BTN_CONFIRM,"CONFIRMAR ORDEM",10,165,145,32);
   CreateButton(BTN_CANCEL,"CANCELAR",160,165,145,32);

   CreateButton(BTN_CLOSE_BUY,"FECHAR BUY",10,285,95,28);
   CreateButton(BTN_CLOSE_SELL,"FECHAR SELL",110,285,95,28);
   CreateButton(BTN_CLOSE_ALL,"FECHAR TUDO",210,285,95,28);

   SetLabel(LBL_STATUS,"BOLETA inicializando...",10,10,10);
   SetLabel(LBL_STATE,"",10,205,10);
   SetLabel(LBL_PENDING,"ORDEM PENDENTE VISUAL: inativa",10,245,10);
   SetLabel(LBL_IMPACT,"DD: —    Gain: —    R:R: —",335,245,10);

   SyncLotEdit();
}

int OnInit()
{
   g_lots=NormalizeLots(InpLots);
   BuildUI();
   UpdatePanel();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   DeletePendingLines();

   ObjectDelete(0,BTN_BUY);
   ObjectDelete(0,BTN_SELL);
   ObjectDelete(0,BTN_PENDING);
   ObjectDelete(0,BTN_CONFIRM);
   ObjectDelete(0,BTN_CANCEL);
   ObjectDelete(0,BTN_LOT_MINUS);
   ObjectDelete(0,BTN_LOT_PLUS);
   ObjectDelete(0,EDIT_LOT);
   ObjectDelete(0,BTN_CLOSE_BUY);
   ObjectDelete(0,BTN_CLOSE_SELL);
   ObjectDelete(0,BTN_CLOSE_ALL);
   ObjectDelete(0,LBL_STATUS);
   ObjectDelete(0,LBL_STATE);
   ObjectDelete(0,LBL_PENDING);
   ObjectDelete(0,LBL_IMPACT);
}

void OnTick()
{
   UpdatePanel();
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_OBJECT_DRAG)
   {
      if(sparam==LINE_ENTRY)
         g_entry=NormalizeDouble(ObjectGetDouble(0,LINE_ENTRY,OBJPROP_PRICE),Digits);
      else if(sparam==LINE_STOP)
         g_stop=NormalizeDouble(ObjectGetDouble(0,LINE_STOP,OBJPROP_PRICE),Digits);
      else if(sparam==LINE_TP)
         g_take=NormalizeDouble(ObjectGetDouble(0,LINE_TP,OBJPROP_PRICE),Digits);
      else
         return;

      UpdatePendingCalculations();
      return;
   }

   if(id==CHARTEVENT_OBJECT_ENDEDIT && sparam==EDIT_LOT)
   {
      ReadLotEdit();
      UpdatePanel();
      return;
   }

   if(id!=CHARTEVENT_OBJECT_CLICK)
      return;

   if(sparam==BTN_LOT_MINUS)
      ChangeLots(-InpLotStep);
   else if(sparam==BTN_LOT_PLUS)
      ChangeLots(InpLotStep);
   else if(sparam==BTN_BUY)
   {
      g_pendingDirection=PENDING_BUY;
      if(!g_pendingMode)
         OpenMarket(OP_BUY);
   }
   else if(sparam==BTN_SELL)
   {
      g_pendingDirection=PENDING_SELL;
      if(!g_pendingMode)
         OpenMarket(OP_SELL);
   }
   else if(sparam==BTN_PENDING)
   {
      if(!g_pendingMode)
         StartPendingVisual();
   }
   else if(sparam==BTN_CONFIRM)
   {
      if(g_pendingMode && CreatePendingOrder())
         DeletePendingLines();
   }
   else if(sparam==BTN_CANCEL)
      CancelPendingVisual();
   else if(sparam==BTN_CLOSE_BUY)
      CloseOrders(OP_BUY);
   else if(sparam==BTN_CLOSE_SELL)
      CloseOrders(OP_SELL);
   else if(sparam==BTN_CLOSE_ALL)
      CloseOrders(-1);

   ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
   UpdatePanel();
}
