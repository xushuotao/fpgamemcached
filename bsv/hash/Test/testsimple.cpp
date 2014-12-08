
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <time.h>

#include "SimpleIndicationWrapper.h"
#include "SimpleRequestProxy.h"
#include "GeneratedTypes.h"

#include "../jenkins_sw/jenkins_hash.h";

uint32_t hash_val;

class SimpleIndication : public SimpleIndicationWrapper
{  
public:
  uint32_t cnt;
  void incr_cnt(){
    if (++cnt == 1)
      exit(0);
  }

   virtual void getHash(uint32_t a) {
      fprintf(stderr,"GetHash: %d\n", a);
      assert(hash_val == a);
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

  srand(time(NULL));
  size_t keylen = rand()%257;
  char* key = new char[keylen];
  for (uint32_t i = 0; i < keylen; i++) {
     key[i] = rand();
  }

  fprintf(stderr, "Main:: keylen = %d\n", keylen);
  
  hash_val = jenkins_hash((void*)key, keylen); 
  fprintf(stderr,"Main:: jenkins: %d\n", hash_val);
  
  uint64_t* k = (uint64_t*)key;
  //TripleWord triple;

  device->start(keylen);

  while ( keylen >= 8){
    device->key(*k);
    k++;
    keylen -= 8;
  }

  if (keylen > 0) {
    device->key((*k) &  (((uint64_t)1 << (keylen*8))-1));
  }
/*
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
     case 0 : break;  // zero length strings require no mixing 
  }
     */                                
  delete key;
                                     
  
  fprintf(stderr, "Main::about to go to sleep\n");
  while(true){sleep(2);}
}
