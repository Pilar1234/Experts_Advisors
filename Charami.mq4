//+------------------------------------------------------------------+
//|                                                   ExpertAdvisor.mq4 |
//|                                                  Piotr Pilarczyk |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Piotr Pilarczyk"
#property link      "https://www.mql5.com"
#property version   "1.10"
#property strict
//---- input parameters
extern bool UseHours=true;
extern int HighHour = 17;
extern int DownHour = 9;
extern double PipsValue=34.73;

extern bool UseTraillingStop=true;

extern double RewardRatio=1;
extern double RiskPercent=2;

extern double spread=0.00015;
extern int MagicNumber=1335;

double pips;
double pipsToBsl,pipsToSsl;
double bsl,ssl;
double buyPrice,sellPrice;

bool sellAllowed=false;
bool buyAllowed=false;

bool buyAvaibleToClose=false;
bool sellAvaibleToClose=false;
//+------------------------------------------------------------------+
int OnInit()
  {
   double tickSize=MarketInfo(Symbol(),MODE_TICKSIZE);
   if(tickSize==0.00001 || tickSize==0.001)
      pips=tickSize*10;
   else pips=tickSize;

//spread=MarketInfo(Symbol(),MODE_SPREAD)*tickSize;
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {  }
//+------------------------------------------------------------------+
void OnTick()
  {
   Comment("Wartość spread-u: "+DoubleToString(spread,Digits)+
           "\nWielkość pips-a: "+DoubleToString(pips,Digits)+
           "\nZezwoelenie na otwarce BUYSTOP: "+buyAllowed+
           "\nZezwolenie na otwarcie SELLSTOP: "+sellAllowed+
           "\nZezwolenie na zamknięcie/otwarcie buy: "+buyAvaibleToClose+
           "\nZezwolenie na zamknięcie/otwarcie sell: "+sellAvaibleToClose);

   if(Bid<(bsl+spread) && buyAvaibleToClose)
     {
      deleteBuyPendingOrder();
      buyAvaibleToClose=false;
      buyAllowed=true;
     }

   if(Bid>(ssl-2*spread) && sellAvaibleToClose)
     {
      deleteSellPendingOrder();
      sellAvaibleToClose=false;
      sellAllowed=true;
     }

   if(Ask>buyPrice && buyAvaibleToClose)
     {
      deleteSellPendingOrder();
      closeSellOrder();
      buyAvaibleToClose=false;
      sellAllowed=true;
     }

   if(Bid<sellPrice && sellAvaibleToClose)
     {
      deleteBuyPendingOrder();
      closeBuyOrder();
      sellAvaibleToClose=false;
      buyAllowed=true;
     }

   if(OpenOrdersThisPair(Symbol())==0)
     {
      buyAllowed=true;
      sellAllowed=true;
     }

   if(isNewCandle())
      checkForTrade();
   if(UseTraillingStop)
      traillingStop();
  }
//+------------------------------------------------------------------+
void checkForTrade()
  {
   if(High[3]>=High[2] && High[3]>=High[1] && Low[3]<=Low[2] && Low[3]<=Low[1])
     {
      if(UseHours && Hour()<HighHour && Hour()>DownHour)
        {
         orderEntry(0);
         orderEntry(1);
        }
      if(!UseHours)
        {
         orderEntry(0);
         orderEntry(1);
        }
     }
  }
//+------------------------------------------------------------------+
int openPendingBuys()
  {
   int total=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      int orderSelect=OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
      if(OrderType()==OP_BUYSTOP && OrderMagicNumber()==MagicNumber)
         total++;
     }
   return(total);
  }
//+------------------------------------------------------------------+
int openPendingSells()
  {
   int total=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      int orderSelect=OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
      if(OrderType()==OP_SELLSTOP && OrderMagicNumber()==MagicNumber)
         total++;
     }
   return(total);
  }
//+------------------------------------------------------------------+
int openBuys()
  {
   int total=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      int orderSelect=OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
      if(OrderType()==OP_BUY && OrderMagicNumber()==MagicNumber)
         total++;
     }
   return(total);
  }
//+------------------------------------------------------------------+
int openSels()
  {
   int total=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      int orderSelect=OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
      if(OrderType()==OP_SELL && OrderMagicNumber()==MagicNumber)
         total++;
     }
   return(total);
  }
//+------------------------------------------------------------------+
int OpenOrdersThisPair(string pair)
  {
   int total=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      int orderSelect = OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
      if(OrderSymbol()==pair && OrderMagicNumber()==MagicNumber)
         total++;
     }
   return(total);
  }
//+------------------------------------------------------------------+
bool isNewCandle()
  {
   static int barsOnChart=0;
   if(Bars==barsOnChart)
      return (false);

   barsOnChart=Bars;
   return (true);
  }
//+------------------------------------------------------------------+
void orderEntry(int direction)
  {
   int err=0;
   double lotSize= 0;
   double equity = AccountEquity();
   double riskedAmount=equity*RiskPercent*0.01;

   ssl = High[3] + 2*spread;
   bsl = Low[3] - spread;

//BUY order
   if(direction==0)
     {
      buyPrice=High[1]+2*spread;
      pipsToBsl=buyPrice-bsl;
      double btp=buyPrice+pipsToBsl*RewardRatio;

      lotSize=riskedAmount/((pipsToBsl/pips)*PipsValue);

      int orderBuy=OrderSend(Symbol(),OP_BUYSTOP,lotSize,buyPrice,3,bsl,btp,NULL,MagicNumber,0,Red);

      buyAvaibleToClose=true;

      if(orderBuy<0)
         Print("Error order BUY errorNumber= ",GetLastError());
     }
//SELL order
   if(direction==1)
     {
      sellPrice=Low[1]-spread;
      pipsToSsl=ssl-sellPrice;
      double stp=sellPrice-pipsToSsl*RewardRatio;

      lotSize=riskedAmount/((pipsToSsl/pips)*PipsValue);

      int orderSell=OrderSend(Symbol(),OP_SELLSTOP,lotSize,sellPrice,3,ssl,stp,NULL,MagicNumber,0,Green);

      sellAvaibleToClose=true;

      if(orderSell<0)
         Print("Error order SELL errorNumber= ",GetLastError());
     }
  }
//+------------------------------------------------------------------+
void traillingStop()
  {
   double ssl1 = NormalizeDouble(Ask+pipsToSsl,Digits);
   double bsl1 = NormalizeDouble(Bid-pipsToBsl,Digits);

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) && OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol())
        {
         //SELL conditions
         if(OrderType()==OP_SELL && OrderOpenPrice()-Ask>=pipsToSsl && (OrderStopLoss()>ssl1 || OrderStopLoss()==0))
           {
            bool orderSellModify=OrderModify(OrderTicket(),OrderOpenPrice(),ssl1,OrderTakeProfit(),0,clrNONE);

            if(!orderSellModify)
               Print("Error order modify SELL errorNumber= ",GetLastError());
           }
         //BUY conditions
         if(OrderType()==OP_BUY && Bid-OrderOpenPrice()>=pipsToBsl && OrderStopLoss()<bsl1)
           {
            bool orderBuyModify=OrderModify(OrderTicket(),OrderOpenPrice(),bsl1,OrderTakeProfit(),0,clrNONE);

            if(!orderBuyModify)
               Print("Error order modify BUY errorNumber= ",GetLastError());
           }
        }
     }
  }
//+------------------------------------------------------------------+
void closeBuyOrder()
  {
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         //BUY conditions
         if(OrderType()==OP_BUY && OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol())
           {
            bool result=OrderClose(OrderTicket(),OrderLots(),Bid,3,Blue);
            if(!result)
               Print("BUY close LastError = ",GetLastError());
           }
        }
      else Print("When selecting a trade BUY error ",GetLastError()," occurred");
     }
  }
//+------------------------------------------------------------------+
void closeSellOrder()
  {
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         if(OrderType()==OP_SELL && OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol())
           {
            bool result=OrderClose(OrderTicket(),OrderLots(),Ask,3,Blue);
            if(!result)
               Print("SELL close LastError = ",GetLastError());
           }
        }
      else Print("When selecting a trade SELL error ",GetLastError()," occurred");
     }
  }
//+------------------------------------------------------------------+
void deleteSellPendingOrder()
  {
   for(int j=OrdersTotal()-1; j>=0; j--)
     {
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES))
        {
         if(OrderType()==OP_SELLSTOP && OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol())
           {
            int ticket=OrderTicket();
            bool deleteOrder=OrderDelete(ticket,clrAqua);
            if(!deleteOrder)
               Print("Deleting SELLSTOP error, nr: ",GetLastError());
           }
        }
      else Print("When selecting a SELLSTOP order error ",GetLastError()," occurred");
     }
  }
//+------------------------------------------------------------------+
void deleteBuyPendingOrder()
  {
   for(int j=OrdersTotal()-1; j>=0; j--)
     {
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES))
        {
         if(OrderType()==OP_BUYSTOP && OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol())
           {
            int ticket=OrderTicket();
            bool deleteOrder=OrderDelete(ticket,clrAqua);
            if(!deleteOrder)
               Print("Deleting BUYSTOP error, nr: ",GetLastError());
           }
        }
      else Print("When selecting a BUYSTOP order error ",GetLastError()," occurred");
     }
  }
//+------------------------------------------------------------------+
