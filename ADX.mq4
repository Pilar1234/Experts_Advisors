//+------------------------------------------------------------------+
//|                                                     Skeleton.mq4 |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

extern bool UseHours=true;
extern int HighHour = 20;
extern int DownHour = 6;
extern double PipsValue=34.73;

extern bool UseTraillingStop=true;

extern double RewardRatio=2;;
extern double RiskPercent=3;

extern int MagicNumber=1234;
double pips,spread;
double pipsToBsl,pipsToSsl;
double buyPrice,sellPrice;
bool buyPriceAllowed=false;
bool sellPriceAllowed=false;
//+------------------------------------------------------------------+
int OnInit()
  {
   double tickSize=MarketInfo(Symbol(),MODE_TICKSIZE);
   if(tickSize==0.00001 || tickSize==0.001)
      pips=tickSize*10;
   else pips=tickSize;

   spread=MarketInfo(Symbol(),MODE_SPREAD)*tickSize;

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {  }
//+------------------------------------------------------------------+
void OnTick()
  {
   Comment("Wartość spread-u: "+DoubleToString(spread,Digits)+
           "\nWielkość pips-a: "+DoubleToString(pips,Digits)
           );

   if(Ask>buyPrice && buyPriceAllowed)
     {
      buyPriceAllowed=false;
      deleteSellPendingOrder();
      closeSellOrder();
     }
   if(Bid<sellPrice && sellPriceAllowed)
     {
     sellPriceAllowed=false;
      deleteBuyPendingOrder();
      closeBuyOrder();
     }
   if(isNewCandle())
      checkForTrade();
   if(UseTraillingStop)
      traillingStop();

  }
//+------------------------------------------------------------------+
void checkForTrade()
  {
   double price,stopLoss;

   double previousMainADX=iADX(Symbol(),0,14,PRICE_CLOSE,MODE_MAIN,2);
   double previousPlusDIADX=iADX(Symbol(),0,14,PRICE_CLOSE,MODE_PLUSDI,2);
   double previousMinusDIADX=iADX(Symbol(),0,14,PRICE_CLOSE,MODE_MINUSDI,2);

   double currentMainADX=iADX(Symbol(),0,14,PRICE_CLOSE,MODE_MAIN,1);
   double currentPlusDIADX=iADX(Symbol(),0,14,PRICE_CLOSE,MODE_PLUSDI,1);
   double currentMinusDIADX=iADX(Symbol(),0,14,PRICE_CLOSE,MODE_MINUSDI,1);

   if(previousMinusDIADX>previousPlusDIADX && currentPlusDIADX>currentMinusDIADX && previousMinusDIADX<previousMainADX && currentPlusDIADX<currentMainADX)
     {
      SendNotification("Utworzył się sygnał BUY");
      stopLoss=Low[1]-spread;
      price=High[1];
      if(Hour()>DownHour && Hour()<HighHour)
         orderEntry(0,price,stopLoss);
      if(!UseHours)
         orderEntry(0,price,stopLoss);
     }
   if(previousMinusDIADX<previousPlusDIADX && currentPlusDIADX<currentMinusDIADX && previousPlusDIADX<previousMainADX && currentMinusDIADX<currentMainADX)
     {
      SendNotification("Utworzył się sygnał SELL");
      stopLoss=High[1]+2*spread;
      price=Low[1];
      if(Hour()>DownHour && Hour()<HighHour)
         orderEntry(1,price,stopLoss);
      if(!UseHours)
         orderEntry(1,price,stopLoss);
     }
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
void orderEntry(int direction,double openPrice,double sl)
  {
   int err=0;
   double lotSize= 0;
   double equity = AccountEquity();
   double riskedAmount=equity*RiskPercent*0.01;

//BUY order
   if(direction==0)
     {
      buyPrice=openPrice+2*spread;
      pipsToBsl=openPrice-sl;
      double btp=openPrice+pipsToBsl*RewardRatio;

      lotSize=riskedAmount/((pipsToBsl/pips)*PipsValue);
      
      buyPriceAllowed = true;
      int orderBuy=OrderSend(Symbol(),OP_BUYSTOP,lotSize,buyPrice,3,sl,btp,NULL,MagicNumber,0,Black);

      if(orderBuy<0)
        {
         err=GetLastError();
         Print("Error order BUY errorNumber= ",err);
        }
     }
//SELL order
   if(direction==1)
     {
      sellPrice=openPrice-spread;
      pipsToSsl=sl-sellPrice;
      double stp=openPrice-pipsToSsl*RewardRatio;

      lotSize=riskedAmount/((pipsToSsl/pips)*PipsValue);
      
      sellPriceAllowed=true;
      int orderSell=OrderSend(Symbol(),OP_SELLSTOP,lotSize,sellPrice,3,sl,stp,NULL,MagicNumber,0,Green);

      if(orderSell<0)
        {
         err=GetLastError();
         Print("Error order SELL errorNumber= ",err);
        }
     }
  }
//+------------------------------------------------------------------+
void traillingStop()
  {
   int err=0;
   double ssl = NormalizeDouble(Ask+pipsToSsl,Digits);
   double bsl = NormalizeDouble(Bid-pipsToBsl,Digits);

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) && OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol())
        {
         //SELL conditions
         if(OrderType()==OP_SELL && OrderOpenPrice()-Ask>=pipsToSsl && (OrderStopLoss()>ssl || OrderStopLoss()==0))
           {
            bool orderSellModify=OrderModify(OrderTicket(),OrderOpenPrice(),ssl,OrderTakeProfit(),0,clrNONE);

            if(!orderSellModify)
              {
               err=GetLastError();
               Print("Error order modify SELL errorNumber= ",err);
              }
            continue;
           }
         //BUY conditions
         if(OrderType()==OP_BUY && Bid-OrderOpenPrice()>=pipsToBsl && OrderStopLoss()<bsl)
           {
            bool orderBuyModify=OrderModify(OrderTicket(),OrderOpenPrice(),bsl,OrderTakeProfit(),0,clrNONE);

            if(!orderBuyModify)
              {
               err=GetLastError();
               Print("Error order modify BUY errorNumber= ",err);
              }
           }
        }
     }
  }
//BUY conditions
void closeBuyOrder()
  {
   int err=0;
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         if(OrderType()==OP_BUY && OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol())
           {
            bool result=OrderClose(OrderTicket(),OrderLots(),Bid,3,Blue);
            if(!result)
              {
               err=GetLastError();
               Print("BUY close LastError = ",err);
              }
           }
        }
      else Print("When selecting a trade BUY error ",GetLastError()," occurred");
     }
  }
//SELL conditions
void closeSellOrder()
  {
   int err=0;
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         if(OrderType()==OP_SELL && OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol())
           {
            bool result=OrderClose(OrderTicket(),OrderLots(),Ask,3,Blue);
            if(!result)
              {
               err=GetLastError();
               Print("SELL close LastError = ",GetLastError());
              }
           }
        }
      else Print("When selecting a trade SELL error ",GetLastError()," occurred");
     }
  }
//+------------------------------------------------------------------+
void deleteSellPendingOrder()
  {
   int err=0;
   for(int j=OrdersTotal()-1; j>=0; j--)
     {
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES))
        {
         if(OrderType()==OP_SELLSTOP && OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol())
           {
            int ticket=OrderTicket();
            bool deleteOrder=OrderDelete(ticket,clrAqua);
            if(!deleteOrder)
              {
               err=GetLastError();
               Print("Deleting SELLSTOP error, nr: ",err);
              }
           }
        }
      else Print("When selecting a SELLSTOP order error ",GetLastError()," occurred");
     }
  }
//+------------------------------------------------------------------+
void deleteBuyPendingOrder()
  {
   int err=0;
   for(int j=OrdersTotal()-1; j>=0; j--)
     {
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES))
        {
         if(OrderType()==OP_BUYSTOP && OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol())
           {
            int ticket=OrderTicket();
            bool deleteOrder=OrderDelete(ticket,clrAqua);
            if(!deleteOrder)
              {
               err=GetLastError();
               Print("Deleting BUYSTOP error, nr: ",err);
              }
           }
        }
      else Print("When selecting a BUYSTOP order error ",GetLastError()," occurred");
     }
  }
//+------------------------------------------------------------------+
