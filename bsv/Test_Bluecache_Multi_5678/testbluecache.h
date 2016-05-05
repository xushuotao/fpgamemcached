#ifndef _TESTMEMREAD_H_
#define _TESTMEMREAD_H_

#include "StdDmaIndication.h"
#include "MemServerRequest.h"
#include "MMURequest.h"
#include "BluecacheRequest.h"
#include "BluecacheIndication.h"
#include <string.h>

#include "protocol_binary.h"

#include <stdlib.h>     /* srand, rand */
#include <time.h>


#include <math.h>

#include <queue>
#include <iostream>

#define ALLOC_SZ (1<<20)

#define DMABUF_SZ (1<<13)
//#define DMABUF_SZ (1<<7)


#ifdef BSIM
#define PagesPerBlock 16
#define BLOCKS_PER_CHIP 128
#define CHIPS_PER_BUS 8
#define NUM_BUSES 8
#define FlashCapacity 16
#else
#define PagesPerBlock 256
#define BLOCKS_PER_CHIP 4096
#define CHIPS_PER_BUS 8
#define NUM_BUSES 8
#define FlashCapacity 256
#endif



#define ONEMB (1<<20)

#define TotalBlocks (BLOCKS_PER_CHIP*CHIPS_PER_BUS*NUM_BUSES)
#define BlockSize (PagesPerBlock*8192)

#define REAL_BLOCKS_PER_CHIP ((FlashCapacity*ONEMB)/BlockSize/(NUM_BUSES*CHIPS_PER_BUS))
#define REAL_TotalBlocks ((FlashCapacity*ONEMB)/BlockSize)


typedef enum {
  UNINIT,
  BAD,
  FRESH,
  WRITTEN
} FlashStatusT;

FlashStatusT flashStatus[NUM_BUSES][CHIPS_PER_BUS][BLOCKS_PER_CHIP];
int tag2blockTable[128];
int currFRESHBlockId[NUM_BUSES][CHIPS_PER_BUS];
int currUNINITBlockId[NUM_BUSES][CHIPS_PER_BUS];

//sem_t initDone_sem, wrDone_sem;

//protocol_binary_request_header* headerArray;

int* keylenArray;
int* vallenArray;

int reqId = 0;

int srcAlloc, dstAlloc;
unsigned int *srcBuffer = 0;
unsigned int *dstBuffer = 0;


int set_fails = 0;
int get_fails = 0;

int resp_cnt = 0;
int num_resps = 0;
int eomCnt = 0;
timespec * time_start;
double avgLatency;
int getResps = 0;

int pageSz = 8192;

int numTests;
//timespec interval_start;
//timespec start, now;

std::vector<uint32_t> perf_sample;

std::queue<uint32_t> eraseTagQ;

std::queue<uint32_t> freeReadBufId;
std::queue<uint32_t> busyReadBufId;

std::queue<uint32_t> returnWriteBufId;

uint32_t currSrcBase = -1;
int srcBuf_offset = DMABUF_SZ;

uint32_t currDstBase = -1;
int dstBuf_offset = DMABUF_SZ;


pthread_mutex_t mu_read, mu_write;
pthread_cond_t cond, cond_write;

char** keyArray;
char** valArray;

bool* setStatus;

BluecacheRequestProxy *device = 0;

void printhdr(protocol_binary_response_header v1){
  fprintf(stderr, "magic %x\n", v1.response.magic);
  fprintf(stderr, "opcode %x\n", v1.response.opcode);
  fprintf(stderr, "keylen %x\n", v1.response.keylen);
  fprintf(stderr, "extlen %x\n", v1.response.extlen);
  fprintf(stderr, "datatype %x\n", v1.response.datatype);
  fprintf(stderr, "status %x\n", v1.response.status);
  fprintf(stderr, "bodylen %x\n", v1.response.bodylen);
  fprintf(stderr, "opaque %x\n", v1.response.opaque);
  fprintf(stderr, "cas %lx\n", v1.response.cas);
}



class BluecacheIndication : public BluecacheIndicationWrapper
{
public:

  virtual void initDone(uint32_t dummy){
    fprintf(stderr, "Main:: Memcached init finished\n");
    //sem_post(&initDone_sem);
    pthread_mutex_lock(&mu_read);
    pthread_cond_signal(&cond);
    pthread_mutex_unlock(&mu_read);
  }
  
  virtual void rdDone(uint32_t bufId){
    pthread_mutex_lock(&mu_read);
    freeReadBufId.push(bufId);
    pthread_mutex_unlock(&mu_read);
    //fprintf(stderr, "Main:: dma readBufId = %d done success\n", bufId);
  }
  virtual void wrDone(uint32_t bufId){
    pthread_mutex_lock(&mu_write);
    returnWriteBufId.push(bufId);
    pthread_mutex_unlock(&mu_write);
    //fprintf(stderr, "Main:: dma writeBufId = %d done success\n", bufId);
  }  

  virtual void hexDump(unsigned int data) {
    fprintf(stderr,"Aurora Lane Status %x--\n", data );
    /*timespec now;
    clock_gettime(CLOCK_REALTIME, & now);
    printf( "aurora data! %f\n", timespec_diff_sec(aurorastart, now) );*/
    //fflush(stdout);
  }

  BluecacheIndication(int id) : BluecacheIndicationWrapper(id){}

  //  ~BluecacheIndication(){}
};

double timespec_diff_sec( timespec start, timespec end ) {
  double t = end.tv_sec - start.tv_sec;
  t += ((double)(end.tv_nsec - start.tv_nsec)/1000000000L);
  return t;
}

double timespec_diff_usec( timespec start, timespec end ) {
  double t = (end.tv_sec - start.tv_sec)*1e6;
  t += ((double)(end.tv_nsec - start.tv_nsec)/1e3);
  return t;
}


/*bool greaterThanInterval(timespec start, timespec end ){
  uint64_t t_ms = (end.tv_sec - start.tv_sec)*(1000);
  t_ms += ((end.tv_nsec - start.tv_nsec)/1000000L);
  return t_ms>=20;
  }*/


int waitIdleReadBuffer() {
  int tag = -1;
  //fprintf(stderr, "Main::WaitIdleReadBuf, trying to get next bufId\n");
  while ( tag < 0 ) {
    pthread_mutex_lock(&mu_read);
    if ( !freeReadBufId.empty() ) {
      tag = freeReadBufId.front();
      freeReadBufId.pop();
    }
    pthread_mutex_unlock(&mu_read);
  }
  //fprintf(stderr, "Main::WaitIdleReadBuf, got next bufId = %d\n", tag);
  return tag;
}

int waitIdleWriteBuffer() {
  if (currDstBase != -1 ){
    //fprintf(stderr, "Main::WaitIdleWriteBuf, trying dequeue\n");
    pthread_mutex_lock(&mu_write);
    if ( !returnWriteBufId.empty() ) {
      //fprintf(stderr, "Main::WaitIdleWriteBuf, deq bufId = %d\n", returnWriteBufId.front());
      returnWriteBufId.pop();
    }
    pthread_mutex_unlock(&mu_write);
    //fprintf(stderr, "Main::WaitIdleWriteBuf, done dequeue\n");
  }
  
  //fprintf(stderr, "Main::WaitIdleWriteBuf, trying to get next bufId\n");
  int tag = -1;
  while ( tag < 0 ) {
    pthread_mutex_lock(&mu_write);
    if ( !returnWriteBufId.empty() ) {
      tag = returnWriteBufId.front();
    }
    pthread_mutex_unlock(&mu_write);
  }
  //fprintf(stderr, "Main::WaitIdleWriteBuf, got next bufId = %d\n", tag);
  return tag;
}

void dmaBufMemwrite(char* reqBuf, size_t totalSize){
  while (totalSize > 0 ){
    
    if ( srcBuf_offset + totalSize < DMABUF_SZ) {
      //fprintf(stderr, "Main:: currSrcBase = %d, srcBuf_offset = %d\n", currSrcBase, srcBuf_offset);
      memcpy((char*)srcBuffer + currSrcBase + srcBuf_offset, reqBuf, totalSize);
      srcBuf_offset+=totalSize;
      totalSize = 0;
    } else {
      if (currSrcBase != -1){
        memcpy((char*)srcBuffer + currSrcBase + srcBuf_offset, reqBuf, DMABUF_SZ - srcBuf_offset);
        reqBuf+=(DMABUF_SZ-srcBuf_offset);
        totalSize-=(DMABUF_SZ-srcBuf_offset);
        device->startRead(currSrcBase, DMABUF_SZ);
      }
      srcBuf_offset=0;
      currSrcBase = waitIdleReadBuffer();
    }
  }
}



void sendSet(void* key, void* val, size_t keylen, size_t vallen, uint32_t opaque){
  protocol_binary_request_header header;
  memset(&header, 0, sizeof(protocol_binary_request_header));
  header.request.magic = PROTOCOL_BINARY_REQ;
  header.request.opcode = PROTOCOL_BINARY_CMD_SET;
  header.request.keylen = keylen;
  header.request.bodylen = keylen + vallen;
  header.request.opaque = opaque;

  size_t totalSize = sizeof(protocol_binary_request_header) + keylen + vallen;
  char* reqBuf = new char[totalSize];
  char* srcBuf = reqBuf;
  memcpy(srcBuf, &header, sizeof(protocol_binary_request_header));
  srcBuf+=sizeof(protocol_binary_request_header);
  memcpy(srcBuf, key, keylen);
  srcBuf+=keylen;
  memcpy(srcBuf, val, vallen);
  dmaBufMemwrite(reqBuf, totalSize);
  delete reqBuf;
}

void sendGet(void* key, size_t keylen, uint32_t opaque){
  protocol_binary_request_header header;
  memset(&header, 0, sizeof(protocol_binary_request_header));
  header.request.magic = PROTOCOL_BINARY_REQ;
  header.request.opcode = PROTOCOL_BINARY_CMD_GET;
  header.request.keylen = keylen;
  header.request.bodylen = keylen;
  header.request.opaque = opaque;

  size_t totalSize = sizeof(protocol_binary_request_header) + keylen;
  char* reqBuf = new char[totalSize];
  char* srcBuf = reqBuf;
  memcpy(srcBuf, &header, sizeof(protocol_binary_request_header));
  srcBuf+=sizeof(protocol_binary_request_header);
  memcpy(srcBuf, key, keylen);
  dmaBufMemwrite(reqBuf, totalSize);
  delete reqBuf;
}

void sendDelete(void* key, size_t keylen, uint32_t opaque){
  protocol_binary_request_header header;
  memset(&header, 0, sizeof(protocol_binary_request_header));
  header.request.magic = PROTOCOL_BINARY_REQ;
  header.request.opcode = PROTOCOL_BINARY_CMD_DELETE;
  header.request.keylen = keylen;
  header.request.bodylen = keylen;
  header.request.opaque = opaque;

  size_t totalSize = sizeof(protocol_binary_request_header) + keylen;
  char* reqBuf = new char[totalSize];
  char* srcBuf = reqBuf;
  memcpy(srcBuf, &header, sizeof(protocol_binary_request_header));
  srcBuf+=sizeof(protocol_binary_request_header);
  memcpy(srcBuf, key, keylen);
  dmaBufMemwrite(reqBuf, totalSize);
  delete reqBuf;
}

void sendEom(){
  protocol_binary_request_header header;
  memset(&header, 0, sizeof(protocol_binary_request_header));
  header.request.magic = PROTOCOL_BINARY_REQ;
  header.request.opcode = PROTOCOL_BINARY_CMD_EOM;
  header.request.keylen = 0;
  header.request.bodylen = 0;
  header.request.opaque = 0;

  size_t totalSize = sizeof(protocol_binary_request_header);
  char* reqBuf = new char[totalSize];
  char* srcBuf = reqBuf;
  memcpy(srcBuf, &header, sizeof(protocol_binary_request_header));
  dmaBufMemwrite(reqBuf, totalSize);
  delete reqBuf;
}

void flushDmaBuf(){
  sendEom();
  if ( srcBuf_offset > 0 && currSrcBase != -1 ){
    /*for ( int i = 0; i < srcBuf_offset; i++){
      fprintf(stderr, "Main::dumpbuf, token[%d] = %02x\n", i, *((char*)(srcBuffer) + currSrcBase + i));
      }*/
    device->startRead(currSrcBase, srcBuf_offset);
    srcBuf_offset = 0;
    currSrcBase = waitIdleReadBuffer();
  }
}


void dmaBufMemreadBuf(void* respBuf, size_t totalSize){

  
  size_t offset = 0;
  while (totalSize > 0 ){
    if ( dstBuf_offset + totalSize < DMABUF_SZ) {
      //fprintf(stderr, "Main:: currDstBase = %d, dstBuf_offset = %d, totalSize = %d\n", currDstBase, dstBuf_offset, totalSize);
      memcpy(respBuf, (char*)dstBuffer + currDstBase + dstBuf_offset, totalSize);
      dstBuf_offset+=totalSize;
      totalSize = 0;
    } else {
      if (currDstBase != -1){
        //fprintf(stderr, "Main:: currDstBase = %d, dstBuf_offset = %d, totalSize = %d\n",currDstBase, dstBuf_offset, totalSize);
        memcpy(respBuf, (char*)dstBuffer + currDstBase + dstBuf_offset, DMABUF_SZ - dstBuf_offset);
        respBuf+=(DMABUF_SZ-dstBuf_offset);
        totalSize-=(DMABUF_SZ-dstBuf_offset);
        device->freeWriteBufId(currDstBase);
      }
      dstBuf_offset=0;
      currDstBase = waitIdleWriteBuffer();
    }
  }
}


void resetDMADstBuf(){
  //sendEom();
  if ( dstBuf_offset > 0 && currDstBase != -1 ){
    //device->freeWriteBufId(currDstBase);
    dstBuf_offset = DMABUF_SZ;
    //currDstBase = -1;
  }
}
 
int indexVirtualConvert(int bus, int chip, int block){
  return block + REAL_BLOCKS_PER_CHIP*chip + REAL_BLOCKS_PER_CHIP*CHIPS_PER_BUS*bus;
}

int indexRealConvert(int bus, int chip, int block){
  return block + BLOCKS_PER_CHIP*chip + BLOCKS_PER_CHIP*CHIPS_PER_BUS*bus;
}
 
int waitIdleEraseTag(){
  int tag = -1;
  //fprintf(stderr, "Main::WaitIdleReadBuf, trying to get next bufId\n");
  while ( tag < 0 ) {
    pthread_mutex_lock(&mu_read);
    if ( !eraseTagQ.empty() ) {
      tag = eraseTagQ.front();
      eraseTagQ.pop();
    }
    pthread_mutex_unlock(&mu_read);
  }
  //fprintf(stderr, "Main::WaitIdleReadBuf, got next bufId = %d\n", tag);
  return tag;
}

void auroraifc_start(int myid) {
  device->setNetId(myid);
  device->auroraStatus(0);
  usleep(100);
}


void *decode_response(void *ptr);

void initBluecache(){

  int numBufs = ALLOC_SZ/DMABUF_SZ;

  device->reset(rand());
  sleep(1);

  pthread_mutex_lock(&mu_read);
  for (uint32_t t = 0; t < numBufs; t++) {
    uint32_t byteoffset = t * DMABUF_SZ;
    freeReadBufId.push(byteoffset);
    device->freeWriteBufId(byteoffset);
  }
  pthread_mutex_unlock(&mu_read);


  device->initTable();
  fprintf(stderr, "waiting for table to be initialized\n");
  pthread_mutex_lock(&mu_read);
  pthread_cond_wait(&cond, &mu_read);
  pthread_mutex_unlock(&mu_read);
}
           
           
int runtest(int argc, const char ** argv)
{
  char hostname[32];
  gethostname(hostname,32);

  unsigned long myid = strtoul(hostname+strlen("bdbm"), NULL, 0);
  if ( strstr(hostname, "bdbm") == NULL 
       && strstr(hostname, "umma") == NULL
       && strstr(hostname, "lightning") == NULL ) {
    myid = 0;

  }
  char* userhostid = getenv("BDBM_ID");
  if ( userhostid != NULL ) {
    myid = strtoul(userhostid, NULL, 0);
  }

  srand(time(NULL)+myid);

  int test_result = 0;

  BluecacheIndication *deviceIndication = 0;

  fprintf(stderr, "Main::%s %s\n", __DATE__, __TIME__);

  device = new BluecacheRequestProxy(IfcNames_BluecacheRequest);
  deviceIndication = new BluecacheIndication(IfcNames_BluecacheIndication);
  MemServerRequestProxy *hostMemServerRequest = new MemServerRequestProxy(IfcNames_HostMemServerRequest);
  MMURequestProxy *dmap = new MMURequestProxy(IfcNames_HostMMURequest);
  DmaManager *dma = new DmaManager(dmap);
  MemServerIndication *hostMemServerIndication = new MemServerIndication(hostMemServerRequest, IfcNames_HostMemServerIndication);
  MMUIndication *hostMMUIndication = new MMUIndication(dma, IfcNames_HostMMUIndication);

  fprintf(stderr, "Main::allocating memory...\n");
  srcAlloc = portalAlloc(ALLOC_SZ);//, 1);
  dstAlloc = portalAlloc(ALLOC_SZ);//, 1);


  srcBuffer = (unsigned int *)portalMmap(srcAlloc, ALLOC_SZ);
  dstBuffer = (unsigned int *)portalMmap(dstAlloc, ALLOC_SZ);

  pthread_mutex_init(&mu_read, NULL);
  pthread_cond_init(&cond, NULL);
  pthread_mutex_init(&mu_write, NULL);
  pthread_cond_init(&cond_write, NULL);


  portalExec_start();

  fprintf(stderr,"HERE!!!\n");

  for (int i = 0; i < ALLOC_SZ/4; i++){
    srcBuffer[i] = i;
    dstBuffer[i] = 0x5a5abeef;
  }

  fprintf(stderr,"HERE2!!!\n");
   
  portalDCacheFlushInval(srcAlloc, ALLOC_SZ, srcBuffer);
  portalDCacheFlushInval(dstAlloc, ALLOC_SZ, dstBuffer);
  fprintf(stderr, "Main::flush and invalidate complete\n");
  
  unsigned int ref_srcAlloc = dma->reference(srcAlloc);
  unsigned int ref_dstAlloc = dma->reference(dstAlloc);
  
  fprintf(stderr, "ref_srcAlloc=%d\n", ref_srcAlloc);
  fprintf(stderr, "ref_dstAlloc=%d\n", ref_dstAlloc);

  printf( "initializing aurora with node id %ld\n", myid ); fflush(stdout);
  auroraifc_start(myid);

  device->initDMARefs(ref_srcAlloc, ref_dstAlloc);
  device->initDMABufSz(DMABUF_SZ);

  pthread_t thread_response;
  pthread_create(&thread_response, NULL, decode_response, (void*) NULL);

  initBluecache();

  // if ( myid == 6 ){
  //   //exit(0);
  //   while (true){};
  // }

  int numGets;

  #ifndef BSIM
  std::cout << "Enter number of set requests: ";
  std::cin >> numTests;

  std::cout << "Enter number of get requests: ";
  std::cin >> numGets;
  #else
  numTests = 100;
  numGets = 100;
  #endif

  keyArray = new char*[numTests];
  valArray = new char*[numTests];
  
  keylenArray = new int[numTests];
  vallenArray = new int[numTests];

  setStatus = new bool[numTests];

  //time_start = new timespec[threadcount];

  int keylen;
  int vallen;

  timespec start, now;
  
  clock_gettime(CLOCK_REALTIME, &start);
  int keytoken = 0;
  int valtoken = 0;
  for ( int i = 0; i < numTests; i++ ){
    //for ( int threadId = 0; threadId < threadcount; threadId++ ){
      keylen = rand()%255 + 1;
      //keylen = 255;
      // vallen = pageSz - keylen - 8;
      //keylen = 64;
      #ifndef BSIM
      vallen = pageSz - keylen - 8;
      #else
      vallen = rand()%(6*pageSz-keylen-8)+1;
      #endif

      //vallen = 8192-8-keylen;
      //keylen = rand()%255+1;
      //vallen = pageSz-keylen;
      //vallen = rand()%(pageSz/2 - keylen) + 1;
      //vallen = rand()%(6*pageSz-keylen-8)+1;//rand()%255+1;

      //vallen = rand()%(128*pageSz-keylen-8)+1;//rand()%255+1;
      //vallen = (91*pageSz-keylen-8)+1;//rand()%255+1;
      //vallen = 8192-24;
      //vallen = 6*pageSz-keylen;//rand()%255+1;
      //vallen = (1000-keylen-8);
      // keylen = 64;
      // vallen = 64;p
      int arrayIndex = i;//*threadcount + threadId;
      keylenArray[arrayIndex] = keylen;
      vallenArray[arrayIndex] = vallen;

      keyArray[arrayIndex] = new char[keylen];
      for ( int j = 0; j < keylen; j++ ){
        keyArray[arrayIndex][j] = rand();
        //keyArray[arrayIndex][j] = keytoken++;
      }

      valArray[arrayIndex] = new char[vallen];
      for (int j = 0; j < vallen; j++){
        valArray[arrayIndex][j] = rand();
        //valArray[arrayIndex][j] = valtoken++;
      }
      //fprintf(stderr, "Main:: set request = %d, i = %d, threadid = %d\n", arrayIndex, i , threadId);
      sendSet(keyArray[arrayIndex], valArray[arrayIndex], keylen, vallen, arrayIndex);
      //sendGet(keyArray[arrayIndex], keylen, arrayIndex);
  }
  flushDmaBuf();

  pthread_mutex_lock(&mu_write);
  pthread_cond_wait(&cond_write, &mu_write);
  pthread_mutex_unlock(&mu_write);
    //}
  // while ( true ){
  //   pthread_mutex_lock(&mu_write);
  //   //pthread_cond_wait(&cond_write, &mu_write);
  //   if (eomCnt == numTests ){
  //     eomCnt = 0;
  //     pthread_mutex_unlock(&mu_write);
  //     break;
  //   }
  //   pthread_mutex_unlock(&mu_write);
  // }

  clock_gettime(CLOCK_REALTIME, & now);
  fprintf(stderr, "Main:: Set Test Successful, num_resps = %d\n", numTests);
  fprintf(stderr, "Main:: Set Test Successful, %f MRPS\n", numTests/(timespec_diff_sec(start, now)*1000000));
  sleep(10);

  // // for ( int i = 0; i < numTests/2; i++){
  // //   int j = i%numTests;
  // //   keylen = keylenArray[j];
  // //   sendDelete(keyArray[j], keylen, j);
  // // }
  // fprintf(stderr, "Main:: Starting Get tests\n");
  

  clock_gettime(CLOCK_REALTIME, & start);
  for ( int i = 0; i < numGets; i++ ){
    //fprintf(stderr, "Main:: Get batch i = %d, numGets = %d, threadcount = %d\n", i, numGets, threadcount);
    //for ( int threadId = 0; threadId < threadcount; threadId++ ){
      //int i = (keylen-1)*32+j;
      //keylen = 64;//rand()%256 + 1;
      //int j = rand()%128;
      //int j = rand()%numTests;
    int j = rand()%(numTests);//*threadcount);
      //int j = (i*threadcount + threadId)%(6400-256)+256;
      //int j = rand()%6400;
    keylen = keylenArray[j];
    //clock_gettime(CLOCK_REALTIME, time_start+threadId);      
      //fprintf(stderr, "Main:: get request = %d\n", j);
      //sendGet(keyArray[j], keylen, threadId);
      sendGet(keyArray[j], keylen, j);
  }
  flushDmaBuf();
  pthread_mutex_lock(&mu_write);
  pthread_cond_wait(&cond_write, &mu_write);
  pthread_mutex_unlock(&mu_write);
    //}
  // while ( true ){
  //   pthread_mutex_lock(&mu_write);
  //   //pthread_cond_wait(&cond_write, &mu_write);
  //   if (eomCnt == numGets ){
  //     eomCnt = 0;
  //     pthread_mutex_unlock(&mu_write);
  //     break;
  //   }
  //   pthread_mutex_unlock(&mu_write);
  // }

  // pthread_mutex_lock(&mu_write);
  // pthread_cond_wait(&cond_write, &mu_write);
  // pthread_mutex_unlock(&mu_write);


  //checkGetResp(numTests);
  clock_gettime(CLOCK_REALTIME, & now);
  fprintf(stderr, "Main:: Get Test Successful, num_resps = %d\n", numGets);
  fprintf(stderr, "Main:: Get Test Successful, %f MRPS\n", (numGets)/(timespec_diff_sec(start, now)*1000000));
  fprintf(stderr, "Main:: Get Test Successful, avgLatency = %lf, over %d Gets\n", avgLatency, getResps);


  fprintf(stderr, "Main:: All tests finished, set fails = %d, get fails = %d\n", set_fails, get_fails);

  // initBluecache();

  // clock_gettime(CLOCK_REALTIME, &start);
  // for ( int threadId = 0; threadId < threadcount; threadId++ ){
  //   for ( int i = 0; i < numTests; i++ ){
  //     keylen = 64;//rand()%255 + 1;
  //     //vallen = 8192-8-keylen;
  //     //keylen = rand()%255+1;
  //     vallen = pageSz-8-keylen;
  //     //vallen = (1.5*pageSz - keylen - 8) + 1;
  //     //vallen = rand()%(6*pageSz-keylen-8)+1;//rand()%255+1;
  //     //vallen = (1000-keylen-8);
  //     // keylen = 64;
  //     // vallen = 64;
  //     int arrayIndex = threadId*numTests + i;
  //     keylenArray[arrayIndex] = keylen;
  //     vallenArray[arrayIndex] = vallen;

  //     keyArray[arrayIndex] = new char[keylen];
  //     for ( int j = 0; j < keylen; j++ ){
  //       keyArray[arrayIndex][j] = rand();
  //     }

  //     valArray[arrayIndex] = new char[vallen];
  //     for (int j = 0; j < vallen; j++){
  //       valArray[arrayIndex][j] = rand();
  //     }
  //     sendSet(keyArray[arrayIndex], valArray[arrayIndex], keylen, vallen, arrayIndex);
  //   }
  //   flushDmaBuf();

  //   //checkSetResp(numTests);
  //   // pthread_mutex_lock(&mu_write);
  //   // pthread_cond_wait(&cond_write, &mu_write);
  //   // pthread_mutex_unlock(&mu_write);
  // }
  // while ( true ){
  //   pthread_mutex_lock(&mu_write);
  //   //pthread_cond_wait(&cond_write, &mu_write);
  //   if (eomCnt == threadcount ){
  //     eomCnt = 0;
  //     pthread_mutex_unlock(&mu_write);
  //     break;
  //   }
  //   pthread_mutex_unlock(&mu_write);
  // }

  // clock_gettime(CLOCK_REALTIME, & now);
  // fprintf(stderr, "Main:: Set Test Successful, num_resps = %d\n", numTests*threadcount);
  // fprintf(stderr, "Main:: Set Test Successful, %f MRPS\n", numTests*threadcount/(timespec_diff_sec(start, now)*1000000));
  // sleep(1);


  // clock_gettime(CLOCK_REALTIME, & start);
  // for ( int threadId = 0; threadId < threadcount; threadId++ ){
  //   for ( int i = 0; i < numGets; i++ ){
  //     //int i = (keylen-1)*32+j;
  //     //keylen = 64;//rand()%256 + 1;
  //     //int j = rand()%128;
  //     //int j = rand()%numTests;
  //     //int j = i%numTests;
  //     int j = numTests*threadId + i;
  //     keylen = keylenArray[j];
  //     clock_gettime(CLOCK_REALTIME, time_start+j);      
  //     sendGet(keyArray[j], keylen, j);
  //   }
  //   flushDmaBuf();

  //   // pthread_mutex_lock(&mu_write);
  //   // pthread_cond_wait(&cond_write, &mu_write);
  //   // pthread_mutex_unlock(&mu_write);
  // }
  // while ( true ){
  //   pthread_mutex_lock(&mu_write);
  //   //pthread_cond_wait(&cond_write, &mu_write);
  //   if (eomCnt == threadcount ){
  //     eomCnt = 0;
  //     pthread_mutex_unlock(&mu_write);
  //     break;
  //   }
  //   pthread_mutex_unlock(&mu_write);
  // }

  // // pthread_mutex_lock(&mu_write);
  // // pthread_cond_wait(&cond_write, &mu_write);
  // // pthread_mutex_unlock(&mu_write);


  // //checkGetResp(numTests);
  // clock_gettime(CLOCK_REALTIME, & now);
  // fprintf(stderr, "Main:: Get Test Successful, num_resps = %d\n", numGets*threadcount);
  // fprintf(stderr, "Main:: Get Test Successful, %f MRPS\n", (numGets*threadcount)/(timespec_diff_sec(start, now)*1000000));
  // fprintf(stderr, "Main:: Get Test Successful, avgLatency = %lf, over %d Gets\n", avgLatency, getResps);


  // fprintf(stderr, "Main:: All tests finished, set fails = %d, get fails = %d\n", set_fails, get_fails);
  while ( true ){
    sleep(1);
  }
  //sleep(1);
  //exit(0);
}

void *decode_response(void *ptr){

  protocol_binary_response_header resphdr;
  timespec now;
  while (true){
    dmaBufMemreadBuf(&resphdr, sizeof(protocol_binary_response_header));
    resp_cnt++;
    /*clock_gettime(CLOCK_REALTIME, &now); 
    if (greaterThanInterval(interval_start, now)){
      perf_sample.push_back((resp_cnt)/(timespec_diff_sec(start, now)*1000));
      interval_start = now;
      }*/
    //printhdr(resphdr);
    if ( resphdr.response.magic != PROTOCOL_BINARY_RES ){
      printhdr(resphdr);
      fprintf(stderr, "Main:: response magic is not right\n");
      exit(0);
    }

    //printhdr(resphdr);
    if (resphdr.response.opcode == PROTOCOL_BINARY_CMD_SET){
      //assert(resphdr.response.status == PROTOCOL_BINARY_RESPONSE_SUCCESS);
      if ( resphdr.response.status != PROTOCOL_BINARY_RESPONSE_SUCCESS) {
        fprintf(stderr,"Main:: Set %d fails\n", resphdr.response.opaque);
        printhdr(resphdr);
        set_fails++;
        setStatus[resphdr.response.opaque] = false;
      } else {
        //fprintf(stderr,"Main:: Set %d success\n", resphdr.response.opaque);
        setStatus[resphdr.response.opaque] = true;
      }
      assert(resphdr.response.bodylen == 0);
    } else if (resphdr.response.opcode == PROTOCOL_BINARY_CMD_GET){
      if(resphdr.response.status == PROTOCOL_BINARY_RESPONSE_SUCCESS){
        char* valrecv = new char[resphdr.response.bodylen];
      
        dmaBufMemreadBuf(valrecv, resphdr.response.bodylen);
        if ( setStatus[resphdr.response.opaque] ) {
          assert(resphdr.response.bodylen == vallenArray[resphdr.response.opaque]);

          // if ( memcmp(valrecv, valArray[resphdr.response.opaque], resphdr.response.bodylen)){
          //   printhdr(resphdr);
          //   fprintf(stderr, "Main:: value is not received correctly\n");
          //   for(int j = 0; j < vallenArray[resphdr.response.opaque]; j++){
          //     fprintf(stderr, "Main:: valrecv[%d] = %x, valArray[%d] = %x, match = %d\n", j, valrecv[j], j, valArray[resphdr.response.opaque][j], valrecv[j]==valArray[resphdr.response.opaque][j]); 
          //   }
          //   //exit(0);
          // }
        }
        delete valrecv;
      }
      else {
        //fprintf(stderr,"Main:: Get %d fails\n", resphdr.response.opaque);
        get_fails++;
      }
      clock_gettime(CLOCK_REALTIME, &now);
      // double diff = timespec_diff_usec(time_start[resphdr.response.opaque], now);
      // avgLatency = avgLatency*(double)getResps/(double)(getResps+1) + diff/(double)(getResps+1);
      getResps++;
    } else if (resphdr.response.opcode == PROTOCOL_BINARY_CMD_EOM ){
      //dmaBufMemreadBuf(&resphdr, sizeof(protocol_binary_response_header));
      //printhdr(resphdr);
      assert(resphdr.response.magic == PROTOCOL_BINARY_RES );
      assert(resphdr.response.opcode == PROTOCOL_BINARY_CMD_EOM);
      assert(resphdr.response.bodylen == 0);
      resetDMADstBuf();
      
      fprintf(stderr, "EOM received eomCnt = %d\n", eomCnt);

      pthread_mutex_lock(&mu_write);
      num_resps = resp_cnt;
      resp_cnt = 0;
      // if ( eomCnt + 1 == numTests ){
      pthread_cond_signal(&cond_write);
      //   eomCnt = 0;
      // }else{
      //   eomCnt++;
      // }
      eomCnt++;
      pthread_mutex_unlock(&mu_write);
    } else if (resphdr.response.opcode == PROTOCOL_BINARY_CMD_DELETE ) {
      assert(resphdr.response.magic == PROTOCOL_BINARY_RES );

      assert(resphdr.response.bodylen == 0);
      // pthread_mutex_lock(&mu_write);
      // num_resps = resp_cnt;
      // resp_cnt = 0;
      // pthread_cond_signal(&cond_write);
      // pthread_mutex_unlock(&mu_write);
    } else {
      printhdr(resphdr);
      fprintf(stderr,"Main: Response not supported\n");
      exit(1);
    }
    //fprintf(stderr, "Main:: finish checking one resp\n");
  }
}
#endif // _TESTMEMREAD_H_
