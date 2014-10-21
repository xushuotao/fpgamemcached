
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <time.h>

#include <math.h>
#include <pthread.h>
#include <string.h>

#include "StdDmaIndication.h"
#include "DmaDebugRequestProxy.h"
#include "MMUConfigRequestProxy.h"

#include "SimpleIndicationWrapper.h"
#include "SimpleRequestProxy.h"
#include "GeneratedTypes.h"

#include <sys/time.h>
#include <iostream>

using namespace std;

//#include "../jenkins_sw/jenkins_hash.h";

//uint32_t dumpLimit;
uint64_t* rdArray;
uint32_t burstCnt = 0;
uint32_t burstLimit;

timeval t1, t2;
double elapsedTime, sum_t_set=0, sum_t_get=0;

//pthread_mutex_t mu;
//pthread_cond_t cond;
sem_t done_write;
sem_t done_read;

class SimpleIndication : public SimpleIndicationWrapper
{  
public:
  virtual void rdDone(){
    sem_post(&done_read);
  }

  virtual void wrDone(){
    sem_post(&done_write);
  }
  
  /*virtual void getVal(uint64_t a){
    //pthread_mutex_lock(&mu);
    rdArray[burstCnt++] = a;
    //pthread_mutex_unlock(&mu);
    if (burstCnt == burstLimit){
      gettimeofday(&t2, NULL);
      elapsedTime = (t2.tv_sec - t1.tv_sec) * 1000.0;      // sec to ms
      elapsedTime += (t2.tv_usec - t1.tv_usec) / 1000.0;   // us to ms
      printf("Main:: Done executing read in %lf millisecs\n", elapsedTime );
      exit(0);
      //pthread_cond_broadcast(&cond);
    //incr_cnt();
    }
    }*/
  
  SimpleIndication(unsigned int id) : SimpleIndicationWrapper(id){}
};

int main(int argc, const char **argv)
{
  if(sem_init(&done_read, 1, 0)){
    fprintf(stderr, "failed to init done_read\n");
    exit(1);
  }

  if(sem_init(&done_write, 1, 0)){
    fprintf(stderr, "failed to init done_write\n");
    exit(1);
  }

  SimpleIndication *indication = new SimpleIndication(IfcNames_SimpleIndication);
  SimpleRequestProxy *device = new SimpleRequestProxy(IfcNames_SimpleRequest);

  DmaDebugRequestProxy *hostDmaDebugRequest = new DmaDebugRequestProxy(IfcNames_HostDmaDebugRequest);
  MMUConfigRequestProxy *dmap = new MMUConfigRequestProxy(IfcNames_HostMMUConfigRequest);
  DmaManager *dma = new DmaManager(hostDmaDebugRequest, dmap);
  DmaDebugIndication *hostDmaDebugIndication = new DmaDebugIndication(dma, IfcNames_HostDmaDebugIndication);
  MMUConfigIndication *hostMMUConfigIndication = new MMUConfigIndication(dma, IfcNames_HostMMUConfigIndication);

  fprintf(stderr, "Main::allocating memory...\n");

  size_t alloc_sz = 10240;
  
  int srcAlloc = portalAlloc(alloc_sz);
  int dstAlloc = portalAlloc(alloc_sz);
 
  unsigned int *srcBuffer = (unsigned int *)portalMmap(srcAlloc, alloc_sz);
  unsigned int *dstBuffer = (unsigned int *)portalMmap(dstAlloc, alloc_sz);

  portalExec_start();

  /* for (int i = 0; i < numWords; i++){
    srcBuffer[i] = i;
    dstBuffer[i] = 0x5a5abeef;
    }*/

  portalDCacheFlushInval(srcAlloc, alloc_sz, srcBuffer);
  portalDCacheFlushInval(dstAlloc, alloc_sz, dstBuffer);
  fprintf(stderr, "Main::flush and invalidate complete\n");

  unsigned int ref_srcAlloc = dma->reference(srcAlloc);
  unsigned int ref_dstAlloc = dma->reference(dstAlloc);
  
  fprintf(stderr, "ref_srcAlloc=%d\n", ref_srcAlloc);
  fprintf(stderr, "ref_dstAlloc=%d\n", ref_dstAlloc);

    

  srand(time(NULL));
  //dumpLimit = 72;
  //char key[9] = "deadbeef";
  uint64_t data = 1;
  int numBytes;// = 64;//128;//rand()%1000;
  cout << "Enter num of Bytes: ";
  cin >> numBytes;
  cout << endl;
  int loopCnt = (int)ceil(numBytes/8.0);
  burstLimit = loopCnt;

  uint64_t* wrArray = new uint64_t[loopCnt];
  int addr = 128;//rand()%128;

  rdArray = new uint64_t[loopCnt];

  fprintf(stderr, "Request: addr = %d, numBytes = %d, loopCnt = %d\n", addr, numBytes, loopCnt);
  

  for ( int i = 0; i < loopCnt; i++){
    //data = rand();
    //  device->writeVal(data);
    wrArray[i] = data++;
  }

  
  
  #ifdef BSIM
  int iterations = 10;
  #else
  int iterations = 10000;
  #endif
  for ( int j = 0; j < iterations; j++) {
    gettimeofday(&t1, NULL);
    memcpy(srcBuffer, wrArray, numBytes);//sizeof(uint64_t)+1);
    device->writeReq(addr,numBytes,ref_srcAlloc);
    sem_wait(&done_read);  

  
    gettimeofday(&t2, NULL);
    elapsedTime = (t2.tv_sec - t1.tv_sec) * 1000.0;      // sec to ms
    elapsedTime += (t2.tv_usec - t1.tv_usec) / 1000.0;   // us to ms
    printf("Main:: Done executing write in %lf millisecs\n", elapsedTime );

    sum_t_set += elapsedTime;
  
    gettimeofday(&t1, NULL);

  
    device->readReq(addr,numBytes, ref_dstAlloc);
    sem_wait(&done_write);

    memcpy(rdArray, dstBuffer, numBytes);//sizeof(uint64_t)+1);
  
    gettimeofday(&t2, NULL);
    elapsedTime = (t2.tv_sec - t1.tv_sec) * 1000.0;      // sec to ms
    elapsedTime += (t2.tv_usec - t1.tv_usec) / 1000.0;   // us to ms
    printf("Main:: Done executing read in %lf millisecs\n", elapsedTime );

    sum_t_get += elapsedTime;
  
    if (memcmp(wrArray, rdArray, numBytes) == 0){
      fprintf(stderr, "Main::Done, Pass\n");
    } else {
      fprintf(stderr, "Main::Done, Fail\n");
      for (int i = 0; i < loopCnt; i++ ){
        printf("writeArray[%d] = %d, rdArray[%d] = %d\n", i, wrArray[i],  i, rdArray[i]);
      }
    }
  }

  printf("Main: average write latency of %d bytes data is %lf millisecs\n", numBytes, sum_t_set/(double)iterations);
  printf("Main: average read latency of %d bytes data is %lf millisecs\n", numBytes, sum_t_get/(double)iterations);

  /*fprintf(stderr, "Main::about to go to sleep\n"); 
  while(true){};
  /* while(true){
    pthread_mutex_lock(&mu);
    if (burstCnt == loopCnt) {
      gettimeofday(&t2, NULL);
      elapsedTime = (t2.tv_sec - t1.tv_sec) * 1000.0;      // sec to ms
      elapsedTime += (t2.tv_usec - t1.tv_usec) / 1000.0;   // us to ms
      printf("Main:: Done executing read in %lf millisecs\n", elapsedTime );

      if (memcmp(wrArray, rdArray, numBytes) == 0){
        fprintf(stderr, "Main::Done, Pass\n");
      } else {
        fprintf(stderr, "Main::Done, Fail\n");
      }
 
      exit(0);
    }
    pthread_mutex_unlock(&mu);
  }
  */
}
