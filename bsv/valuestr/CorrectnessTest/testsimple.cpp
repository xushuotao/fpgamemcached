
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
  virtual void getVal(uint64_t v1, uint64_t v0){
    //pthread_mutex_lock(&mu);
    rdArray[burstCnt++] = v0;
    //pthread_mutex_unlock(&mu);
    if ( burstCnt + 1 <= burstLimit ){
      rdArray[burstCnt++] = v1;
    }
    if (burstCnt == burstLimit){
      /*gettimeofday(&t2, NULL);
      elapsedTime = (t2.tv_sec - t1.tv_sec) * 1000.0;      // sec to ms
      elapsedTime += (t2.tv_usec - t1.tv_usec) / 1000.0;   // us to ms
      printf("Main:: Done executing read in %lf millisecs\n", elapsedTime );
      //exit(0);*/
      burstCnt = 0;
      pthread_cond_broadcast(&cond);
    //incr_cnt();
    }
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
  pthread_mutex_init(&mu, NULL);
  pthread_cond_init(&cond, NULL);

  srand(time(NULL));
  //dumpLimit = 72;
  //char key[9] = "deadbeef";
  uint64_t data = 1;
  int numBytes;// = rand()%1000;
  int addr;// = rand()%128;

 
  for ( addr = 0; addr < 64; addr++ ) {
    for ( numBytes = 1; numBytes <= 256; numBytes++ ){
      int loopCnt = (int)ceil(numBytes/8.0);
      burstLimit = loopCnt;
      
      uint64_t* wrArray = new uint64_t[loopCnt];
  
      rdArray = new uint64_t[loopCnt];
      
      fprintf(stderr, "Request: addr = %d, numBytes = %d, loopCnt = %d\n", addr, numBytes, loopCnt);
  
  
      gettimeofday(&t1, NULL);
      device->writeReq(addr,numBytes);
      for ( int i = 0; i < loopCnt; i++){
        data = rand();
        data = data << 32;
        data = data | rand();
        //data = i + 1;
        device->writeVal(data);
        wrArray[i] = data;
      }
      /*gettimeofday(&t2, NULL);
      elapsedTime = (t2.tv_sec - t1.tv_sec) * 1000.0;      // sec to ms
      elapsedTime += (t2.tv_usec - t1.tv_usec) / 1000.0;   // us to ms
      printf("Main:: Done executing write in %lf millisecs\n", elapsedTime );
  
      gettimeofday(&t1, NULL);*/
      device->readReq(addr,numBytes);

      pthread_cond_wait(&cond,&mu);
      /*gettimeofday(&t2, NULL);
        elapsedTime = (t2.tv_sec - t1.tv_sec) * 1000.0;      // sec to ms
        elapsedTime += (t2.tv_usec - t1.tv_usec) / 1000.0;   // us to ms
        printf("Main:: Done executing read in %lf millisecs\n", elapsedTime );
      */
      if (memcmp(wrArray, rdArray, numBytes) == 0){
        fprintf(stderr, "Main::Done, Pass\n");
      } else {
        fprintf(stderr, "Main::Done, Fail\n");
        for ( int j = 0; j < (int)ceil(numBytes/8.0); j++ ){
          printf("Main:: wrArray[%d] = %lx, rdArray[%d] = %lx match = %d\n", j,wrArray[j], j,rdArray[j], wrArray[j]!=rdArray[j]);
        }
        exit(0);
      }
    }
  }
  /*
  fprintf(stderr, "Main::about to go to sleep\n"); 
  while(true){};
  while(true){
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
