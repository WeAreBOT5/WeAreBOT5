//+-------------------------------------------------------------------+
//|                                                           Buy.mq5 |
//|                                      Copyright 2013, Marcus Wyatt |
//|                                         http://www.exceptionz.com |
//|Sale in, Position Management and Lots Calculation by Italo Coutinho|
//|                                     Copyright 2020, Italo Coutinho|
//|                                  https://github.com/ItaloCoutinho |
//+-------------------------------------------------------------------+
#property copyright "Copyright 2020, Italo Coutinho"
#property link      "https://github.com/ItaloCoutinho"
#property version   "4.00"

//#property script_show_inputs

//--- input parameters
input double      RiskPercentage = 0.37; // Risk Percentage per Trade
input int      LossRatio    = 5; // Loss Ratio
                                 /* Risco x Retorno
                                    5x1 = 5
                                    4x1 = 4
                                    3x1 = 3
                                    2x1 = 2
                                    1x1 = 1
                                    1x2 = 0.5
                                    1x3 = 0.33
                                    1x4 = 0.25
                                    1x5 = 0.2  */
                                    
input double TakeProfit = 115; //Take Profit - em Pontos (para , use .)

/*Fix Account Total $
   Para trabalhar com balança fixa e incrementar o risco a cada 6 meses ou 1 ano
   */
input int AccBalance = 711; //Account Balance - Valor da conta total (todas as caixas)
input bool FixBalance = true; //Fix Account Balance (true = sim, false = não)

//Scale in and Breakeven
input bool ScaleIn = true; //Do you scale in? - Você faz Scale in?
input bool Autobreakeven = true; //Deseja que automaticamente modifique a primeira posição para o Breakeven e a secunda para o Preço da primeira entrada
input int AutobreakevenSecure = 2; /*Ticks to garantee Breakeven on the first entry
                                    Quantidade de ticks que deseja sair antes do Breakeven para garantir que saia da operação! */

// Variáveis de controle
double StopLoss;
bool ActPos = false;

//Importação de Bibliotecas
#include <Trade\Trade.mqh>                                
#include <Trade\PositionInfo.mqh>                         
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

CTrade         *m_trade;
CSymbolInfo    *m_symbol;
CPositionInfo  *m_position_info; 
CAccountInfo   *m_account;

#define MAX_PERCENT 0.2

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart() {
    m_trade = new CTrade();
    m_symbol = new CSymbolInfo();   
    m_position_info = new CPositionInfo();   
    m_account = new CAccountInfo();
    
    double ticksize     = m_symbol.TickSize();
    
    m_symbol.Name(Symbol());
    m_symbol.RefreshRates();
    
    double point        = m_symbol.Point();     
    double digits       = m_symbol.Digits();
    double spread       = m_symbol.Spread();
    double lots_step    = m_symbol.LotsStep();
    
    double sl_lots;
    
    double sl;
    double tp;
    
    m_position_info.Select(Symbol());
    
    if (m_position_info.Identifier()>0)
      ActPos = true;
    
    //Print(m_position_info.Identifier());
    
    if (ScaleIn == true && ActPos == true)
    {
      sl = m_position_info.StopLoss();
      
      sl_lots = m_symbol.Ask() - sl;
      
      if (Autobreakeven == true)
      {
         //Print("Breakeven First Entry, Profit Second Entry");
         tp = m_position_info.PriceOpen()-AutobreakevenSecure*ticksize;
         m_trade.PositionModify(Symbol(),sl,tp);
      }
    }
    else
    {
       sl = NormalizeDouble(m_symbol.Ask() - TakeProfit*LossRatio, (int)digits);    
       tp = NormalizeDouble(m_symbol.Ask() + TakeProfit, (int)digits); 
       sl_lots = TakeProfit*LossRatio;
    }
    
    double lots = TradeSize(sl_lots);
    
    m_trade.PositionOpen(Symbol(), ORDER_TYPE_BUY, lots, m_symbol.Ask(), sl, tp);
    /*while(!m_trade.PositionOpen(Symbol(), ORDER_TYPE_BUY, lots, m_symbol.Ask(), sl, tp))
    {
        //Print("PositionOpen() Buy FAILED!!. Return code=",m_trade.ResultRetcode(), ". Code description: ",m_trade.ResultRetcodeDescription());    
        lots = lots-lots_step;
    }*/
    
    if(m_position_info != NULL)
        delete m_position_info;
    
    if(m_symbol != NULL)
        delete m_symbol;  
    
    if(m_trade != NULL)
        delete m_trade;  
    
    if(m_account != NULL)
        delete m_account; 
}

//+-------------------------------------------------------------------------+
//|                      Money Managment                                    |   
//+-------------------------------------------------------------------------+   
double TradeSize(double SL) {

   double lots_min     = m_symbol.LotsMin();
   double lots_max     = m_symbol.LotsMax();
   long   leverage     = m_account.Leverage();
   double lots_size    = SymbolInfoDouble(Symbol(),SYMBOL_TRADE_CONTRACT_SIZE);
   double lots_step    = m_symbol.LotsStep();
   double ticksize     = m_symbol.TickSize();
   double tickvalue    = m_symbol.TickValue();
   double percentage   = RiskPercentage / 100;
   
   if(percentage > MAX_PERCENT) percentage = MAX_PERCENT;
   
   double final_account_balance =  MathMin(m_account.Balance(), m_account.Equity());
   int normalization_factor = 0;
   double lots = 0.0;
   
   if(lots_step == 0.01) { normalization_factor = 2; }
   if(lots_step == 0.1)  { normalization_factor = 1; }
   
   lots = (final_account_balance*(RiskPercentage/100.0))/(lots_size/leverage);
   lots = NormalizeDouble(lots, normalization_factor);
   
   double MaxStop;
   if (m_account.Balance() <= 5 || FixBalance)
       MaxStop = AccBalance * (RiskPercentage / 100);
   else
       MaxStop = m_account.Balance() * (RiskPercentage / 100);

   //Print("Account Balance: {3} {0}, with MaxRisk: {1}%, and MaxStop {3} {2}", Account.Balance, MaxRisk, MaxStop, Account.Currency);
   
   /*Print(RiskPercentage / 100);
   Print(m_account.Balance());*/
   
   StopLoss = SL/ticksize;
   StopLoss = (int)round(StopLoss);
   StopLoss = StopLoss*ticksize;
        
   double Loss = StopLoss * tickvalue;
   
   if (tickvalue < 0.1)
      Loss = Loss*100;
   else if (tickvalue < 1)
      Loss = Loss *10;
   
   /*Print("Stop Loss: ", StopLoss);
   Print(tickvalue);
   Print(Loss);*/

   //Print("Max Stop: {5} {0}, with Loss {5} {1}, PipValue {5} {3}, Stop loss: {4}", MaxStop, Loss, Symbol.PipSize, Symbol.PipValue, StopLoss, Account.Currency);

   lots = MaxStop / Loss;
   lots = (int)round(lots);
   lots = MathFloor(lots/lots_step)*lots_step;
   
   if (lots_step<1)
      lots = lots*lots_step;
   
   /*Print(MaxStop);
   Print(lots);
   Print("Loss: ",Loss, ", MaxStop: ", MaxStop);*/
   
   //Print("Lots: ",lots);
   
   if (lots < lots_min) { lots = lots_min; }
   if (lots > lots_max) { lots = lots_max; }
   //----
   
   //Print("Lots: ",lots);
   return( lots );
}

double AccountPercentStopPips(double lots) {
    double balance      = MathMin(m_account.Balance(), m_account.Equity());
    double moneyrisk    = balance * RiskPercentage / 100;
    double spread       = m_symbol.Spread();
    double point        = m_symbol.Point();
    double ticksize     = m_symbol.TickSize();
    double tickvalue    = m_symbol.TickValue();
    double tickvaluefix = tickvalue * point / ticksize; // A fix for an extremely rare occasion when a change in ticksize leads to a change in tickvalue
    
    double stoploss = moneyrisk / (lots * tickvaluefix ) - spread;
    
    if (stoploss < m_symbol.StopsLevel())
        stoploss = m_symbol.StopsLevel(); // This may rise the risk over the requested
        
    stoploss = NormalizeDouble(stoploss, 0);
    
    return (stoploss);
}

//+------------------------------------------------------------------+

