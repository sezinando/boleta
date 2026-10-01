#property strict
#property version   "0.10"
#property description "BOLETA - Operational manual trading panel for MT4"

input bool   InpTestMode       = true;
input double InpLots           = 0.01;
input int    InpMagic          = 1001;
input int    InpSlippage       = 30;
input int    InpMaxSpread      = 100;
input string InpComment        = "BOLETA";

#define BTN_BUY        "BOLETA_BTN_BUY"
#define BTN_SELL       "BOLETA_BTN_SELL"
#define BTN_CLOSE_BUY  "BOLETA_BTN_CLOSE_BUY"
#define BTN_CLOSE_SELL "BOLETA_BTN_CLOSE_SELL"
#define BTN_CLOSE_ALL  "BOLETA_BTN_CLOSE_ALL"
#define LBL_STATUS     "BOLETA_LBL_STATUS"
#define LBL_STATE      "BOLETA_LBL_STATE"

bool CreateButton(string name,string text,int x,int y,int w,int h)
{
   if(ObjectFind(0,name) >= 0)
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

void SetLabel(string name,string text,int x,int y,int size=10)
{
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
}

double NormalizeLots(double lots)
{
   double minLot=MarketInfo(Symbol(),MODE_MINLOT);
   double maxLot=MarketInfo(Symbol(),MODE_MAXLOT);
   double step  =MarketInfo(Symbol(),MODE_LOTSTEP);

   lots=MathMax(minLot,MathMin(maxLot,lots));

   if(step > 0)
      lots=MathFloor(lots/step+0.0000001)*step;

   int digits=2;
   if(step >= 1.0) digits=0;
   else if(step >= 0.1) digits=1;

   return(NormalizeDouble(lots,digits));
}

bool SpreadOK()
{
   RefreshRates();
   double spreadPoints=(Ask-Bid)/Point;
   return(spreadPoints <= InpMaxSpread);
}

int CountOrders(int typeFilter)
{
   int count=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol())
         continue;
      if(OrderMagicNumber()!=InpMagic)
         continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL)
         continue;
      if(typeFilter>=0 && OrderType()!=typeFilter)
         continue;
      count++;
   }
   return(count);
}

double LotsByType(int typeFilter)
{
   double lots=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol())
         continue;
      if(OrderMagicNumber()!=InpMagic)
         continue;
      if(OrderType()!=typeFilter)
         continue;
      lots+=OrderLots();
   }
   return(lots);
}

double ProfitByType(int typeFilter)
{
   double profit=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol())
         continue;
      if(OrderMagicNumber()!=InpMagic)
         continue;
      if(OrderType()!=typeFilter)
         continue;
      profit+=OrderProfit()+OrderSwap()+OrderCommission();
   }
   return(profit);
}

string ModeText()
{
   return(InpTestMode ? "TEST MODE" : "LIVE MODE");
}

void UpdatePanel()
{
   RefreshRates();

   double buyLots=LotsByType(OP_BUY);
   double sellLots=LotsByType(OP_SELL);
   double netLots=buyLots-sellLots;
   double buyProfit=ProfitByType(OP_BUY);
   double sellProfit=ProfitByType(OP_SELL);
   double spreadPoints=(Ask-Bid)/Point;

   string status=StringFormat(
      "%s | %s | Magic=%d | Spread=%.1f",
      Symbol(),ModeText(),InpMagic,spreadPoints);

   string state=StringFormat(
      "BUY  %.2f lots / %d / P&L %.2f\n"
      "SELL %.2f lots / %d / P&L %.2f\n"
      "NET  %.2f lots",
      buyLots,CountOrders(OP_BUY),buyProfit,
      sellLots,CountOrders(OP_SELL),sellProfit,
      netLots);

   SetLabel(LBL_STATUS,status,10,10,10);
   SetLabel(LBL_STATE,state,10,38,10);
   ChartRedraw();
}

bool CanExecute(string action)
{
   if(InpTestMode)
   {
      PrintFormat("[BOLETA][TEST] ACTION=%s SYMBOL=%s LOT=%.2f MAGIC=%d",
                  action,Symbol(),InpLots,InpMagic);
      return(false);
   }

   if(!IsTradeAllowed())
   {
      Print("[BOLETA][ERROR] Trading is not allowed.");
      return(false);
   }

   if(!SpreadOK())
   {
      PrintFormat("[BOLETA][BLOCKED] Spread above limit. Current=%.1f Max=%d",
                  (Ask-Bid)/Point,InpMaxSpread);
      return(false);
   }

   return(true);
}

bool OpenMarket(int type)
{
   string action=(type==OP_BUY ? "BUY" : "SELL");
   double lots=NormalizeLots(InpLots);

   if(!CanExecute(action))
      return(InpTestMode);

   RefreshRates();

   double price=(type==OP_BUY ? Ask : Bid);
   ResetLastError();

   int ticket=OrderSend(
      Symbol(),
      type,
      lots,
      price,
      InpSlippage,
      0,
      0,
      InpComment,
      InpMagic,
      0,
      clrNONE
   );

   if(ticket<0)
   {
      int err=GetLastError();
      PrintFormat("[BOLETA][ERROR] OrderSend %s failed. Error=%d",action,err);
      return(false);
   }

   PrintFormat("[BOLETA][OK] %s ticket=%d lots=%.2f price=%.*f",
               action,ticket,lots,Digits,price);
   return(true);
}

int CloseOrders(int typeFilter)
{
   int closed=0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol())
         continue;
      if(OrderMagicNumber()!=InpMagic)
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
      {
         closed++;
         PrintFormat("[BOLETA][OK] CLOSE ticket=%d lots=%.2f",ticket,lots);
      }
      else
      {
         int err=GetLastError();
         PrintFormat("[BOLETA][ERROR] CLOSE ticket=%d error=%d",ticket,err);
      }
   }

   return(closed);
}

int OnInit()
{
   CreateButton(BTN_BUY,"BUY",10,125,90,30);
   CreateButton(BTN_SELL,"SELL",105,125,90,30);
   CreateButton(BTN_CLOSE_BUY,"CLOSE BUY",200,125,90,30);
   CreateButton(BTN_CLOSE_SELL,"CLOSE SELL",295,125,90,30);
   CreateButton(BTN_CLOSE_ALL,"CLOSE ALL",390,125,90,30);

   SetLabel(LBL_STATUS,"BOLETA inicializando...",10,10,10);
   SetLabel(LBL_STATE,"",10,38,10);

   UpdatePanel();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   ObjectDelete(0,BTN_BUY);
   ObjectDelete(0,BTN_SELL);
   ObjectDelete(0,BTN_CLOSE_BUY);
   ObjectDelete(0,BTN_CLOSE_SELL);
   ObjectDelete(0,BTN_CLOSE_ALL);
   ObjectDelete(0,LBL_STATUS);
   ObjectDelete(0,LBL_STATE);
}

void OnTick()
{
   UpdatePanel();
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id!=CHARTEVENT_OBJECT_CLICK)
      return;

   if(sparam==BTN_BUY)
      OpenMarket(OP_BUY);
   else if(sparam==BTN_SELL)
      OpenMarket(OP_SELL);
   else if(sparam==BTN_CLOSE_BUY)
      CloseOrders(OP_BUY);
   else if(sparam==BTN_CLOSE_SELL)
      CloseOrders(OP_SELL);
   else if(sparam==BTN_CLOSE_ALL)
      CloseOrders(-1);

   ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
   UpdatePanel();
}
