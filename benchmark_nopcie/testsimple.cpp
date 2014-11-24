
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

  int size1 = 8;
  int size2 = 16;
  int size3 = 32;
  int addr1 = 1 << 25;
  int addr2 = 1 << 26;
  int addr3 = 1 << 27;
  
  int lgSz1 = (int)log2((double)size1);
  int lgSz2 = (int)log2((double)size2);
  int lgSz3 = (int)log2((double)size3);

  if ( lgSz2 <= lgSz1 ) lgSz2 = lgSz1+1;
  if ( lgSz3 <= lgSz2 ) lgSz3 = lgSz2+1;

  int lgAddr1 = (int)log2((double)addr1);
  int lgAddr2 = (int)log2((double)addr2);
  int lgAddr3 = (int)log2((double)addr3);

  if ( lgAddr2 <= lgAddr1 ) lgAddr2 = lgAddr1+1;
  if ( lgAddr3 <= lgAddr2 ) lgAddr3 = lgAddr2+1;

  device->initValDelimit(lgSz1, lgSz2, lgSz3);
  device->initAddrDelimit(lgAddr1, lgAddr2, lgAddr3);
  
  int numTests;
  std::cout << "Input Number of Tests: ";
  std::cin >> numTests;
  device->start(numTests);

  fprintf(stderr, "Main::about to go to sleep\n");
  while(true){sleep(2);}
}
