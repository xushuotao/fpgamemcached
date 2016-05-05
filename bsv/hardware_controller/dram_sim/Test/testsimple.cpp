
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <time.h>

#include <pthread.h>

#include "SimpleIndicationWrapper.h"
#include "SimpleRequestProxy.h"
#include "GeneratedTypes.h"

//#include "../jenkins_sw/jenkins_hash.h";

//uint32_t dumpLimit;

class SimpleIndication : public SimpleIndicationWrapper
{  
public:
  uint32_t cnt;
  void incr_cnt(){
    cnt++;
    //if (++cnt == 1)
    //exit(0);
  }
  
  virtual void readRes(const DDRLine data){
    fprintf(stderr, "GetLine[%d]: %016lx %016lx %016lx %016lx %016lx %016lx %016lx %016lx\n",cnt, data.v0, data.v1, data.v2, data.v3, data.v4, data.v5, data.v6, data.v7);
    incr_cnt();
  }
  SimpleIndication(unsigned int id) : SimpleIndicationWrapper(id), cnt(0){}
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
  
  DDRLine data;

  data.v0 = 0x1;
  data.v1 = 0x2;
  data.v2 = 0x3;
  data.v3 = 0x4;
  data.v4 = 0x5;
  data.v5 = 0x6;
  data.v6 = 0x7;
  data.v7 = 0x8;

  for ( uint64_t i = 0; i < 64; i++ ) {
    device->write(i, data, 64);
    device->readReq(i, 64);
  }

#ifdef FLAG
  srand(time(NULL));
  size_t keylen = rand()%1000;
  char* key = new char[keylen];
  for (uint32_t i = 0; i < keylen; i++) {
     key[i] = rand();
  }

  fprintf(stderr, "Main:: keylen = %d\n", keylen);
  
  hash_val = jenkins_hash((void*)key, keylen); 
  fprintf(stderr,"Main:: jenkins: %d\n", hash_val);

  uint32_t* k = (uint32_t*)key;
  TripleWord triple;

  device->start(keylen);

  while ( keylen >= 12){
     triple.low = k[0];
     triple.mid = k[1];
     triple.high = k[2];
     device->key(triple);
     k += 3;
     keylen -= 12;
  }

  memset(&triple, 0, sizeof(triple));
  switch(keylen)
  {
     case 11: triple.high=k[2]&0xffffff; triple.mid=k[1]; triple.low=k[0]; device->key(triple); break;
     case 10: triple.high=k[2]&0xffff; triple.mid=k[1]; triple.low=k[0]; device->key(triple); break;
     case 9 : triple.high=k[2]&0xff; triple.mid=k[1]; triple.low=k[0]; device->key(triple); break;
     case 8 : triple.mid=k[1]; triple.low=k[0]; device->key(triple); break;
     case 7 : triple.mid=k[1]&0xffffff; triple.low=k[0]; device->key(triple); break;
     case 6 : triple.mid=k[1]&0xffff; triple.low=k[0]; device->key(triple); break;
     case 5 : triple.mid=k[1]&0xff; triple.low=k[0]; device->key(triple); break;
     case 4 : triple.low=k[0]; device->key(triple); break;
     case 3 : triple.low=k[0]&0xffffff; device->key(triple); break;
     case 2 : triple.low=k[0]&0xffff; device->key(triple); break;
     case 1 : triple.low=k[0]&0xff; device->key(triple); break;
     case 0 : break;  /* zero length strings require no mixing */
  }
                                     
  delete key;                                 
#endif
  fprintf(stderr, "Main::about to go to sleep\n");
  while(true){sleep(2);}
}
