
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <math.h>
#include <iostream>
#include <string.h>

#include "SimpleIndicationWrapper.h"
#include "SimpleRequestProxy.h"
#include "GeneratedTypes.h"

int numTests;

class SimpleIndication : public SimpleIndicationWrapper
{  
public:
  virtual void finish(uint64_t lowDta, uint64_t highDta, uint32_t reqId) {
    fprintf(stderr, "Host gets value %016lx%016lx, reqId = %d\n", highDta,lowDta, reqId);
  }
  SimpleIndication(unsigned int id) : SimpleIndicationWrapper(id){}
};

SimpleIndication *indication = 0;
SimpleRequestProxy *device = 0;

int main(int argc, const char **argv)
{
  indication = new SimpleIndication(IfcNames_SimpleIndication);
  device = new SimpleRequestProxy(IfcNames_SimpleRequest);

  portalExec_start();
  
  uint64_t addr;
  uint32_t nBytes;
  std::cout << "Input Address: ";
  std::cin >> addr;

  std::cout << "Input nBytes: ";
  std::cin >> nBytes;
  //device->start(numTests);
  device->start(addr, nBytes, 100);
  
  fprintf(stderr, "Main::about to go to sleep\n");
  while(true){sleep(2);}
}
