
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <time.h>

#include <math.h>
#include <pthread.h>
#include <string.h>
#include <vector>

#include "SimpleIndicationWrapper.h"
#include "SimpleRequestProxy.h"
#include "GeneratedTypes.h"

#include <sys/time.h>

#define NUM_TAGS 128

//SimpleIndication *indication = NULL;// = new SimpleIndication(IfcNames_SimpleIndication);
SimpleRequestProxy *device = NULL;// = new SimpleRequestProxy(IfcNames_SimpleRequest);


//#include "../jenkins_sw/jenkins_hash.h";

//uint32_t dumpLimit;
char* dataBuf;
//uint64_t* rdArray;
uint32_t burstCnt = 0;
uint32_t burstLimit;

uint32_t numTests;

timeval t1, t2;
double elapsedTime, sum_t_set=0, sum_t_get=0;

pthread_mutex_t mu;
pthread_cond_t wrAckCond;

uint64_t rdAddr;

typedef struct {
  bool busy;
  int addr;
  int numBytes;
} TagTableEntry;

TagTableEntry readTagTable[NUM_TAGS];

int getNextTag() {
  int tag = -1;
  while ( tag < 0 ) {
    pthread_mutex_lock(&mu);
    for ( int t = 0; t < NUM_TAGS; t++ ) {
      if ( !readTagTable[t].busy ) {
        readTagTable[t].busy = true;
        tag = t;
        break;
      }
    }
    pthread_mutex_unlock(&mu);
  }
  return tag;
}

void readReq(int addr, int numBytes, int tag) {
  pthread_mutex_lock(&mu);
  readTagTable[tag].addr = addr;
  readTagTable[tag].numBytes = numBytes;

  pthread_mutex_unlock(&mu);
  fprintf(stderr, "Read Request: addr = %d, numBytes = %d, tag = %d\n", rdAddr, numBytes, tag);

  device->readReq(addr,numBytes,tag);

  }


class SimpleIndication : public SimpleIndicationWrapper
{  
public:
  uint64_t** rdArray;
  uint32_t wordCnt[NUM_TAGS];
  uint32_t numWords[NUM_TAGS];
  //uint32_t numBytes[NUM_TAGS];
  uint32_t testCnt;
  virtual void getVal(uint64_t a, uint32_t tag){
    //pthread_mutex_lock(&mu);
    if ( wordCnt[tag] == 0 ){
      pthread_mutex_lock(&mu);
      int numBytes = readTagTable[tag].numBytes;
      pthread_mutex_unlock(&mu);

      numWords[tag] = (int)ceil(numBytes/8.0);
      rdArray[tag] = new uint64_t[numWords[tag]];
    }

    rdArray[tag][wordCnt[tag]] = a;
    fprintf(stderr, "indication[wordCnt=%d, numWords=%d] got Val = %08lx, tag = %d\n",wordCnt[tag], numWords[tag],a, tag);
    
    if ( wordCnt[tag] + 1 == numWords[tag] ) {
      pthread_mutex_lock(&mu);
      int rdAddr = readTagTable[tag].addr;
      int numBytes = readTagTable[tag].numBytes;
      readTagTable[tag].busy = false;
      pthread_mutex_unlock(&mu);
      
      if (memcmp(dataBuf+rdAddr, rdArray[tag], numBytes) == 0){
        fprintf(stderr, "Main::Test_%d, Tag_%d, Done, Pass\n", testCnt, tag);
      } else {
        fprintf(stderr, "Main::Test_%d, Tag_%d, Done, Fail\n", testCnt, tag);
        uint64_t* wrArray = (uint64_t*)(dataBuf+rdAddr);
        for ( int j = 0; j < (int)ceil(numBytes/8.0); j++ ){
          printf("Main:: wrArray[%d] = %lx, rdArray[%d] = %lx match = %d\n", j,wrArray[j], j,rdArray[j], wrArray[j] != rdArray[tag][j]);
        }
        exit(0);
      }
      wordCnt[tag] = 0;
      free(rdArray[tag]);

      if (++testCnt == numTests){
        fprintf(stderr, "Main::All tests passed\n");
        exit(0);
      }      
    }
    else {
      wordCnt[tag]++;
    }
    //pthread_mutex_unlock(&mu);

  }

  virtual void wrAck(uint64_t v){
    pthread_mutex_lock(&mu);
    rdAddr = v;
    //printf("Main:: Received wrAck addr = %ld\n", v );
    pthread_cond_broadcast(&wrAckCond);
    pthread_mutex_unlock(&mu);
    //printf("Main:: Received wrAck addr = %ld exiting\n", v );
  }
  
  SimpleIndication(unsigned int id) : SimpleIndicationWrapper(id), testCnt(0){
    for ( int i = 0 ; i < NUM_TAGS; i++) {
      wordCnt[i] = 0;
      numWords[i] = 0;
    }
    rdArray = new uint64_t*[NUM_TAGS];
  }
};

int main(int argc, const char **argv)
{
  SimpleIndication *indication = new SimpleIndication(IfcNames_SimpleIndication);
  device = new SimpleRequestProxy(IfcNames_SimpleRequest);
  
  /* pthread_t tid;
  fprintf(stderr, "Main::creating exec thread\n");
  if(pthread_create(&tid, NULL,  portalExec, NULL)){
    fprintf(stderr, "Main::error creating exec thread\n");
    exit(1);
    }*/
  pthread_mutex_init(&mu, NULL);
  pthread_cond_init(&wrAckCond, NULL);

  printf("Main:: trying initializing readTagTable\n");
  
  pthread_mutex_lock(&mu);
  for (int t = 0; t < NUM_TAGS; t++) {
    readTagTable[t].busy = false;
  }
  pthread_mutex_unlock(&mu);

  printf("Main:: done initializing readTagTable\n");
  
  portalExec_start();
  printf( "Done portalExec_start\n" ); fflush(stdout);

  //sleep(1);

  srand(time(NULL));
  //dumpLimit = 72;
  //char key[9] = "deadbeef";
  uint64_t data = 1;
  int numBytes;// = rand()%1000;
  int addr;// = rand()%128;

  std::vector<uint64_t> sizeVec;
  std::vector<uint64_t> addrVec;

  //int maxSz = 1<<13;//(1 << 20);
  int maxSz = (1 << 20)*3;
  dataBuf = new char[maxSz];
 
  addr = 0;

  int pageCnt = 0;
  int pageSize = (1 << 13);
  do {
    
    //numBytes = rand()%pageSize+1;
    numBytes = pageSize;

    if (pageCnt + numBytes >= pageSize){
      numBytes = pageSize - pageCnt;
      pageCnt = 0;
    }
    else{
      pageCnt+=numBytes;
    }
                                    

    int loopCnt = (int)ceil(numBytes/8.0);
    //burstLimit = loopCnt;
    
    uint64_t* wrArray = new uint64_t[loopCnt];
  
          
    fprintf(stderr, "Write Request: addr = %d, numBytes = %d, loopCnt = %d\n", addr, numBytes, loopCnt);
    
    pthread_mutex_lock(&mu);  
    gettimeofday(&t1, NULL);
    device->writeReq(numBytes);
    for ( int i = 0; i < loopCnt; i++){
      data       = rand();
      data       = data << 32;
      data       = data | rand();
      //data     = i + 1;
      device->writeVal(data);
      wrArray[i] = data;
    }
    gettimeofday(&t2, NULL);
    elapsedTime = (t2.tv_sec - t1.tv_sec) * 1000.0; // sec to ms
    elapsedTime += (t2.tv_usec - t1.tv_usec) / 1000.0; // us to ms
    

    //printf("Main:: wait for write ack\n");
    pthread_cond_wait(&wrAckCond,&mu);
    pthread_mutex_unlock(&mu);

    memcpy(dataBuf+addr, wrArray, numBytes);
    addrVec.push_back(rdAddr);
    sizeVec.push_back(numBytes);

    free(wrArray);
    
    //printf("Main:: Done executing write in %lf millisecs\n", elapsedTime );
      
    gettimeofday(&t1, NULL);

    addr = addr + numBytes;
  } while ( addr < maxSz );

  //sleep(1);

  
  //  pthread_mutex_unlock(&mu);
  //pthread_mutex_unlock(&mu);
  printf("Main:: Doing read\n" );  
  
  numTests = 256;//256;//
  //numTests = addrVec.size();
  
  for ( int t = 0; t < numTests; t++ ){
    //int i = rand()%128 + 256;
    int i = rand()%(addrVec.size());
    //int i = t;

    rdAddr = addrVec[i];
    numBytes = sizeVec[i];

    int tag = -1;
    while ( tag < 0 ) {
      pthread_mutex_lock(&mu);
      for ( int t = 0; t < NUM_TAGS; t++ ) {
        if ( !readTagTable[t].busy ) {
          readTagTable[t].busy = true;
          tag = t;
          break;
        }
      }

      if (tag >= 0){
         readTagTable[tag].addr = rdAddr;
         readTagTable[tag].numBytes = numBytes;
         fprintf(stderr, "Read Request: addr = %d, numBytes = %d, tag = %d\n", rdAddr, numBytes, tag);
         device->readReq(rdAddr,numBytes,tag);
   
      }
      pthread_mutex_unlock(&mu);
    }

    /*
    pthread_mutex_lock(&mu);
    readTagTable[tag].addr = rdAddr;
    readTagTable[tag].numBytes = numBytes;

    
    
    fprintf(stderr, "Read Request: addr = %d, numBytes = %d, tag = %d\n", rdAddr, numBytes, tag);

    device->readReq(rdAddr,numBytes,tag);
    pthread_mutex_unlock(&mu);
    */
    //usleep(1000);
  
    //readReq(rdAddr, numBytes, getNextTag());
  }

  while (true){
    sleep(1);
  }
  
}
