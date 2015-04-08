
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <time.h>

#include <math.h>
#include <pthread.h>
#include <string.h>

#include "SimpleIndicationWrapper.h"
#include "SimpleRequestProxy.h"
#include "GeneratedTypes.h"

#include <sys/time.h>
#include <iostream>

//#include "../jenkins_sw/jenkins_hash.h";

//uint32_t dumpLimit;
uint64_t* rdArray;
uint32_t burstCnt = 0;
uint32_t burstLimit;

timeval t1, t2;
double elapsedTime, sum_t_set=0, sum_t_get=0;

pthread_mutex_t mu;
pthread_cond_t cond;

class SimpleIndication : public SimpleIndicationWrapper
{  
public:
  virtual void done(uint64_t v){
    fprintf(stderr, "Benchmark done in %d cycles\n", v);
    exit(0);
  }
  
  
  SimpleIndication(unsigned int id) : SimpleIndicationWrapper(id){}
};

int main(int argc, const char **argv)
{
  SimpleIndication *indication = new SimpleIndication(IfcNames_SimpleIndication);
  SimpleRequestProxy *device = new SimpleRequestProxy(IfcNames_SimpleRequest);
  
  pthread_t tid;
  fprintf(stderr, "Main::creating exec thread\n");
  if(pthread_create(&tid, NULL,  portalExec, NULL)){
    fprintf(stderr, "Main::error creating exec thread\n");
    exit(1);
  }

  int numReqs;
  std::cin >> numReqs;
  device->start(numReqs);
    
  fprintf(stderr, "Main::about to go to sleep\n"); 
  while(true){};

}
