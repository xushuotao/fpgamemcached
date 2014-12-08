
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <math.h>
#include <iostream>

#include "SimpleIndicationWrapper.h"
#include "SimpleRequestProxy.h"
#include "GeneratedTypes.h"


class SimpleIndication : public SimpleIndicationWrapper
{  
public:
  virtual void finish(uint64_t v) {
    fprintf(stderr, "FPGA finishes in %d cycles.\n", v);
    sleep(1);
    exit(0);
  }
  SimpleIndication(unsigned int id) : SimpleIndicationWrapper(id){}
};



int main(int argc, const char **argv)
{
  SimpleIndication *indication = new SimpleIndication(IfcNames_SimpleIndication);
  SimpleRequestProxy *device = new SimpleRequestProxy(IfcNames_SimpleRequest);

  portalExec_start();

  int size1 = 32;
  int size2 = 64;
  int size3 = 128;
  int addr0 = 1 << 25;
  int addr1 = 1 << 26;
  int addr2 = 1 << 27;
  int addr3 = 1 << 29;

  int numHLines = addr0/((16+256)*4);
  int lgHLines = (int)log2((double)numHLines);
  
  addr0 = (1 << lgHLines) * ((16+256)*4);
  int lgSz1 = (int)log2((double)size1);
  int lgSz2 = (int)log2((double)size2);
  int lgSz3 = (int)log2((double)size3);

  if ( lgSz2 <= lgSz1 ) lgSz2 = lgSz1+1;
  if ( lgSz3 <= lgSz2 ) lgSz3 = lgSz2+1;
  size1 = 1<<lgSz1;
  size2 = 1<<lgSz2;
  size3 = 1<<lgSz3;
  
  int delta, numSlots, lgNumSlots;
  int randMax1, randMax2, randMax3; 

  delta = addr1 - addr0;
  numSlots = delta/size1;
  lgNumSlots = (int)log2((double)numSlots);
  randMax1 = (1 << lgNumSlots) - 1;
  addr1 = addr0 + randMax1*size1;

  delta = addr2 - addr1;
  numSlots = delta/size2;
  lgNumSlots = (int)log2((double)numSlots);
  randMax1 = (1 << lgNumSlots) - 1;
  addr2 = addr1 + randMax2*size1;
  
  delta = addr3 - addr2;
  numSlots = delta/size3;
  lgNumSlots = (int)log2((double)numSlots);
  randMax1 = (1 << lgNumSlots) - 1;
  addr3 = addr2 + randMax3*size1;
  
  /*

  int lgAddr1 = (int)log2((double)addr1);
  int lgAddr2 = (int)log2((double)addr2);
  int lgAddr3 = (int)log2((double)addr3);

  if ( lgAddr2 <= lgAddr1 ) lgAddr2 = lgAddr1+1;
  if ( lgAddr3 <= lgAddr2 ) lgAddr3 = lgAddr2+1;
  */
  device->initTable(lgHLines);
  device->initValDelimit(randMax1, randMax2, randMax3, lgSz1, lgSz2, lgSz3);
  device->initAddrDelimit(addr1, addr2, addr3);
  
  int numTests;
  std::cout << "Input Number of Tests: ";
  std::cin >> numTests;
  device->start(numTests);

  fprintf(stderr, "Main::about to go to sleep\n");
  while(true){sleep(2);}
}
