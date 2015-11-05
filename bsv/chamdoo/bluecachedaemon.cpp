/* Copyright (c) 2014 Quanta Research Cambridge, Inc
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
#include <stdio.h>
#include <sys/mman.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <monkit.h>

#include "StdDmaIndication.h"
#include "MemServerRequest.h"
#include "MMURequest.h"
#include "BluecacheRequest.h"
#include "BluecacheIndication.h"
#include <string.h>

#include "protocol_binary.h"

#include "atomic.h"

#include <stdlib.h>     /* srand, rand */
#include <time.h>


#include <math.h>

#include <queue>
#include <iostream>

#include "bluecachedaemon.h"

#define ALLOC_SZ (1<<20)

#define DMABUF_SZ (1<<13)

#define NUM_BUFS (ALLOC_SZ/DMABUF_SZ)
volatile int dmaWrEnqPtr = 0;
volatile int dmaWrDeqPtr = 0;

volatile int dmaRdEnqPtr = 0;
volatile int dmaRdDeqPtr = 0;


int reqId = 0;
int eomCnt = 0;

int srcAlloc, dstAlloc;
unsigned int *srcBuffer = 0;
unsigned int *dstBuffer = 0;

int batched_requests = 0;
unsigned int dma_requests = 0;
atomic_t outstanding_requests = {0};
atomic_t dma_responses = {0};

volatile bool flushing = false;

int set_fails = 0;
int get_fails = 0;

int resp_cnt = 0;
int num_resps = 0;

int flush_type_0 = 0;
int flush_type_1 = 0;
int flush_type_2 = 0;
int flush_type_x = 0;
int flush_type_req_0 = 0;
int flush_type_req_1 = 0;
int flush_type_req_2 = 0;
int flush_type_req_3 = 0;



unsigned int old_dma_requests = 0;
int old_batched_requests = 0;
int old_outstanding_requests = 0;
int old_dma_responses = 0;

//timespec interval_start;
//timespec start, now;
double avgSendLatency = 0;
double avgLatency = 0;
//int numGets = 0;
atomic_t numGets = {0};

sem_t initDone_sem;

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

// char** keyArray;
// char** valArray;
// int* keylenArray;
// int* vallenArray;


bool* setStatus;

BluecacheRequestProxy *device = 0;

int pageSz = 8192;

class BluecacheIndication : public BluecacheIndicationWrapper{
public:
  uint32_t lowCnt_0;
  uint32_t upCnt_0;
  uint32_t max_0;

  uint32_t* fifoArray_0;

  virtual void sendData_0(uint32_t v){
    if ( (upCnt_0 - lowCnt_0) == max_0 ) {
      uint32_t* tempFifoArray = new uint32_t[max_0*2];
      memcpy(tempFifoArray, fifoArray_0, max_0*sizeof(uint32_t));
      delete fifoArray_0;
      fifoArray_0 = tempFifoArray;
      max_0*=2;
    }
    
    fifoArray_0[upCnt_0%max_0] = v;
    upCnt_0++;
  }
  
  virtual void elementReq_0(uint32_t v){
    for (int i = 0; i < v; i++ ){
      device->recvData_0(fifoArray_0[lowCnt_0%max_0]);
      lowCnt_0++;
    }
  }

  uint32_t lowCnt_1;
  uint32_t upCnt_1;
  uint32_t max_1;

  uint32_t* fifoArray_1;

  virtual void sendData_1(uint32_t v){
    if ( (upCnt_1 - lowCnt_1) == max_1 ) {
      uint32_t* tempFifoArray = new uint32_t[max_1*2];
      memcpy(tempFifoArray, fifoArray_1, max_1*sizeof(uint32_t));
      delete fifoArray_1;
      fifoArray_1 = tempFifoArray;
      max_1*=2;
    }
    
    fifoArray_1[upCnt_1%max_1] = v;
    upCnt_1++;
  }
  
  virtual void elementReq_1(uint32_t v){
    for (int i = 0; i < v; i++ ){
      device->recvData_1(fifoArray_1[lowCnt_1%max_1]);
      lowCnt_1++;
    }
  }

  uint32_t lowCnt_2;
  uint32_t upCnt_2;
  uint32_t max_2;

  uint32_t* fifoArray_2;

  virtual void sendData_2(uint32_t v){
    if ( (upCnt_2 - lowCnt_2) == max_2 ) {
      uint32_t* tempFifoArray = new uint32_t[max_2*2];
      memcpy(tempFifoArray, fifoArray_2, max_2*sizeof(uint32_t));
      delete fifoArray_2;
      fifoArray_2 = tempFifoArray;
      max_2*=2;
    }
    
    fifoArray_2[upCnt_2%max_2] = v;
    upCnt_2++;
  }
  
  virtual void elementReq_2(uint32_t v){
    for (int i = 0; i < v; i++ ){
      device->recvData_2(fifoArray_2[lowCnt_2%max_2]);
      lowCnt_2++;
    }
  }


  virtual void initDone(uint32_t dummy){
    fprintf(stderr, "Main:: Memcached init finished\n");
    sem_post(&initDone_sem);
    // pthread_mutex_lock(&mu_read);
    // pthread_cond_signal(&cond);
    // pthread_mutex_unlock(&mu_read);
  }
  int dmaReadResp;// = 0;
  virtual void rdDone(uint32_t bufId){
    //fprintf(stderr, "Main:: dma readBufId = %d done success, dmaReadResp = %d\n", bufId, dmaReadResp++);
    dmaRdEnqPtr=(dmaRdEnqPtr+1)%(2*NUM_BUFS);
  }
  virtual void wrDone(uint32_t bufId){
    //fprintf(stderr, "Main:: dma Write dmaWrEnqPtr = %d done success\n", dmaWrEnqPtr);
    dmaWrEnqPtr=(dmaWrEnqPtr+1)%(2*NUM_BUFS);
  }  
  BluecacheIndication(int id) : BluecacheIndicationWrapper(id){//, eraseAcks(0), dumpAcks(0){
    lowCnt_0 = 0;
    upCnt_0 = 0;
    max_0 = 2;
    fifoArray_0 = new uint32_t[max_0];

    lowCnt_1 = 0;
    upCnt_1 = 0;
    max_1 = 2;
    fifoArray_1 = new uint32_t[max_1];

    lowCnt_2 = 0;
    upCnt_2 = 0;
    max_2 = 2;
    fifoArray_2 = new uint32_t[max_2];
    dmaReadResp = 0;
  }

  ~BluecacheIndication(){
    delete fifoArray_0;
    delete fifoArray_1;
    delete fifoArray_2;
  }
};


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

void dump(const char *prefix, char *buf, size_t len)
{
    fprintf(stderr, "%s ", prefix);
    for (int i = 0; i < (len > 16 ? 16 : len) ; i++)
      fprintf(stderr, "%02x", (unsigned char)buf[i]);
    fprintf(stderr, "\n");
}


void initMemcached(int size1, int size2, int size3, int addr0, int addr1, int addr2, int addr3){

  int numHLines = addr0/64;
  int lgHLines = (int)log2((double)numHLines);
  
  addr0 = (1 << lgHLines)*64 + 2*(1<<20);
  int lgSz1 = (int)log2((double)size1);
  int lgSz2 = (int)log2((double)size2);
  int lgSz3 = (int)log2((double)size3);

  if ( 1<<lgSz1 < size1 ) lgSz1++;
  if ( 1<<lgSz2 < size2 ) lgSz2++;
  if ( 1<<lgSz3 < size3 ) lgSz3++;

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
  addr1 = addr0 + (randMax1+1)*size1;

  delta = addr2 - addr1;
  numSlots = delta/size2;
  lgNumSlots = (int)log2((double)numSlots);
  randMax2 = (1 << lgNumSlots) - 1;
  addr2 = addr1 + (randMax2+1)*size2;
  
  delta = addr3 - addr2;
  numSlots = delta/size3;
  lgNumSlots = (int)log2((double)numSlots);
  randMax3 = (1 << lgNumSlots) - 1;
  addr3 = addr2 + (randMax3+1)*size3;
  
  fprintf(stderr, "Init Bluecache: hash table size: %d(2^%d) rows\n", 1 << lgHLines, lgHLines);
  fprintf(stderr, "Init Bluecache: value store slab 0: size = %d bytes (2^%d), numEntries = %d(2^%d)\n", 1 << lgSz1, lgSz1, randMax1+1, (int)log2((double)randMax1+1));
  fprintf(stderr, "Init Bluecache: value store slab 1: size = %d bytes (2^%d), numEntries = %d(2^%d)\n", 1 << lgSz2, lgSz2, randMax2+1, (int)log2((double)randMax2+1));
  fprintf(stderr, "Init Bluecache: value store slab 2: size = %d bytes (2^%d), numEntries = %d(2^%d)\n", 1 << lgSz3, lgSz3, randMax3+1, (int)log2((double)randMax3+1));
  device->initTable(lgHLines);
  device->initValDelimit(randMax1, randMax2, randMax3, lgSz1, lgSz2, lgSz3);
  device->initAddrDelimit(addr0-addr0, addr1-addr0, addr2-addr0);

}


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
  while ( true ){
    if ( dmaRdEnqPtr != dmaRdDeqPtr ){
      int retval = (dmaRdDeqPtr%NUM_BUFS)*DMABUF_SZ;
      //fprintf(stderr, "Main::WaitIdleReadBuf, dmaRdDeqPtr = %d,  got next bufId = %d\n", dmaRdDeqPtr, retval);
      dmaRdDeqPtr=(dmaRdDeqPtr+1)%(2*NUM_BUFS);
      return retval;
    }
  }
}

int waitIdleWriteBuffer() {
  while ( true ){
    if ( dmaWrEnqPtr != dmaWrDeqPtr ){
      int retval = (dmaWrDeqPtr%NUM_BUFS)*DMABUF_SZ;
      //fprintf(stderr, "Main::WaitIdleWriteBuf, dmaWrDeqPtr = %d,  got next bufId = %d\n", dmaWrDeqPtr, retval);
      dmaWrDeqPtr=(dmaWrDeqPtr+1)%(2*NUM_BUFS);
      return retval;

    }
  }
}

void dmaBufMemwrite(char* reqBuf, size_t totalSize){
  atomic_inc(&outstanding_requests);

  int temp_batched_requests = batched_requests;

  if ( srcBuf_offset + totalSize < DMABUF_SZ ){
    batched_requests++;
  } else if ( srcBuf_offset + totalSize == DMABUF_SZ ) {
    batched_requests = 0;
  } else {
    batched_requests = 1;
  }

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
        //fprintf(stderr, "Number of DMA Read Requests = %d\n", dma_requests);
        dma_requests++;
		flush_type_req_3 += temp_batched_requests;
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
  batched_requests = 0;
  if ( srcBuf_offset > 0 && currSrcBase != -1 ){
    /*for ( int i = 0; i < srcBuf_offset; i++){
      fprintf(stderr, "Main::dumpbuf, token[%d] = %02x\n", i, *((char*)(srcBuffer) + currSrcBase + i));
      }*/
    device->startRead(currSrcBase, srcBuf_offset);
    //fprintf(stderr, "Number of DMA Read Requests = %d\n", dma_requests);
    dma_requests++;
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
      atomic_inc(&dma_responses);
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
 

void storePerfNumber(){
  FILE * pFile = fopen("/home/shuotao/perf_rps.txt", "w");
  if ( pFile ){
    int size = perf_sample.size();
    for ( int i = 0; i < size; i++ ){
      fprintf(pFile, "%d\n", perf_sample[i]);
    }
  } else {
    fprintf(stderr,"File open failed\n");
    exit(0);
  }
}

//pthread_spinlock_t spinlock;
pthread_mutex_t mutexlock;

sem_t* lockList;
bool** successList;
unsigned char*** valBufList;
size_t** valSizeList;
int clientCnt = 0;

int initMainThread(){
  
  pthread_mutex_lock(&mutexlock);
  sem_t* lockList_temp = new sem_t[clientCnt+1];
  bool** successList_temp = new bool*[clientCnt+1];
  unsigned char*** valBufList_temp = new unsigned char**[clientCnt+1];
  size_t** valSizeList_temp = new size_t*[clientCnt+1];
 
  if ( clientCnt > 0 ){
    for ( int i = 0; i < clientCnt; i++){
      lockList_temp[i] = lockList[i];
      successList_temp[i] = successList[i];
      valBufList_temp[i] = valBufList[i];
      valSizeList_temp[i] = valSizeList[i];
    }
    delete(lockList);
    delete(successList);
    delete(valBufList);
    delete(valSizeList);
  }
  //mutex = mutex_temp;
  lockList = lockList_temp;
  //sem_init(lockList+clientCnt, 1, 0);
  for (int i = 0; i < clientCnt + 1; i++ ){
    sem_init(lockList+i, 1, 0);
  }
  successList = successList_temp;
  valBufList = valBufList_temp;
  valSizeList = valSizeList_temp;

  //sem_init(mutex[clientCnt], 0, 1);
  pthread_mutex_unlock(&mutexlock);
  return clientCnt++;
}

void initBluecacheProxy(){
  //pthread_spin_init(&spinlock, 0);
  pthread_mutex_init(&mutexlock, NULL);

  if(sem_init(&initDone_sem, 1, 0)){
    fprintf(stderr, "failed to init done_sem\n");
    exit(1);
  }

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

  for (int i = 0; i < ALLOC_SZ/4; i++){
    srcBuffer[i] = i;
    dstBuffer[i] = 0x5a5abeef;
  }
   
  portalDCacheFlushInval(srcAlloc, ALLOC_SZ, srcBuffer);
  portalDCacheFlushInval(dstAlloc, ALLOC_SZ, dstBuffer);
  fprintf(stderr, "Main::flush and invalidate complete\n");
  
  unsigned int ref_srcAlloc = dma->reference(srcAlloc);
  unsigned int ref_dstAlloc = dma->reference(dstAlloc);
  
  fprintf(stderr, "ref_srcAlloc=%d\n", ref_srcAlloc);
  fprintf(stderr, "ref_dstAlloc=%d\n", ref_dstAlloc);

  pthread_t thread_response;
  pthread_create(&thread_response, NULL, decode_response, (void*) NULL);
  pthread_t thread_request;
  pthread_create(&thread_request, NULL, flush_request, (void*) NULL);


  int numBufs = ALLOC_SZ/DMABUF_SZ;

  srand(time(NULL));
  device->initDMARefs(ref_srcAlloc, ref_dstAlloc);
  device->reset(rand());

  dmaRdEnqPtr=NUM_BUFS;
  dmaRdDeqPtr=0;
  //pthread_mutex_lock(&mu_read);
  for (uint32_t t = 0; t < numBufs; t++) {
    uint32_t byteoffset = t * DMABUF_SZ;
    //freeReadBufId.push(byteoffset);
    device->freeWriteBufId(byteoffset);
  }
  //pthread_mutex_unlock(&mu_read);

  device->initDMABufSz(DMABUF_SZ);
  //initMemcached(8193, 8194, 8195 , 1<<25, (1<<25)+(1<<14)+8193*2048, 1<<27, 1<<29);
  //initMemcached(128, 256, 1024, 1<<25, 1<<26, 1<<27, 1<<29);
  //initMemcached(128, 256, 1024, 1<<28, 1<<28+1, 1<<29, 1<<30);
  //initMemcached(8193, 8194, 8195 , 1<<25, (1<<25)+(1<<14)+8193, 1<<27, 1<<29);
  initMemcached(pageSz*6, pageSz*64, pageSz*128 , 1<<25, (1<<25)+(1<<14)+pageSz*6, 1<<27, 1<<29);

  sem_wait(&initDone_sem);
}

void *flush_request(void *ptr){
  int num_of_flushes = 0;
  while (true){
    //pthread_spin_lock(&spinlock);
    pthread_mutex_lock(&mutexlock);
    int outstanding_reqs = atomic_read(&outstanding_requests);
    int dma_resps = atomic_read(&dma_responses);
	int sleep = 0;

    if ( !flushing  ){
      if ( batched_requests >= 64) {
        flush_type_0++;
		flush_type_req_0 += batched_requests;
        flushDmaBuf();
	  } else {
		if (flush_type_req_0 >= 6400 - 64) {
        	flushDmaBuf();
		}
	  }
		/*
	  } else if ( batched_requests > 0 && old_batched_requests == batched_requests && old_dma_requests == dma_requests ) {
        //fprintf(stderr, "batched_requests = %d, old_batched_requests = %d, dma_requests = %d, old_dma_requests = %d, num_of_flushes = %d\n", batched_requests, old_batched_requests, dma_requests, old_dma_requests, num_of_flushes++);
		flush_type_1++;
		flush_type_req_1 += batched_requests;
        flushDmaBuf();
        flushing = true;
		sleep = 1;
      } else if ( outstanding_reqs > 0 && outstanding_reqs == old_outstanding_requests && old_dma_responses == dma_resps ){
        //fprintf(stderr, "outstanding_requests = %d, old_outstanding_requests = %d, dma_responses = %d, old_dma_responses = %d, num_of_flushes = %d\n", outstanding_reqs, old_outstanding_requests, dma_resps, old_dma_responses, num_of_flushes++);
		flush_type_2++;
		flush_type_req_2 += batched_requests;
        flushDmaBuf();
        flushing = true;
		sleep = 1;
      } else {
        flush_type_x++;
	  }
		*/
    }
    old_batched_requests = batched_requests;
    old_dma_requests = dma_requests;
    old_outstanding_requests = outstanding_reqs;
    old_dma_responses = dma_resps;
    //pthread_spin_unlock(&spinlock);
    pthread_mutex_unlock(&mutexlock);

	//if (sleep)
	//	usleep(100);
  } 
}

int numReqs = 0;
int numFlushes = 0;
void sendSet(void* key, void* val, size_t keylen, size_t vallen, uint32_t opaque, bool* success){
  //pthread_spin_lock(&spinlock);
  pthread_mutex_lock(&mutexlock);
  //fprintf(stderr, "Main:: send Set request, clientId = %d, numReqs = %d\n", opaque, numReqs);
  sendSet(key, val, keylen, vallen, opaque);
  //fprintf(stderr, "Main:: send Set numReqs = %d, clientCnt = %d\n", numReqs, clientCnt);
  if (numReqs == (6399)){
    //fprintf(stderr, "Main:: flushing pipeline, flushCnt = %d\n", numFlushes++);
    flushDmaBuf();
    flushing = true;
  }

  numReqs++;
  //fprintf(stderr, "Main:: send Set return pointers, clientId = %d\n", opaque);  
  successList[opaque] = success;
  //pthread_spin_unlock(&spinlock);
  pthread_mutex_unlock(&mutexlock);
  //fprintf(stderr,"Main:: sendSet start waiting, clientId = %d\n", opaque);
  //pthread_yield();
  sem_wait(&lockList[opaque]);
  //fprintf(stderr,"Main:: sendSet done waiting, clientId = %d\n", opaque);
}
void sendGet(void* key, size_t keylen, uint32_t opaque, unsigned char** val, size_t* vallen){
  timespec start, end;
  clock_gettime(CLOCK_REALTIME, &start);
  //fprintf(stderr, "Main:: send Get request trying to grab lock, clientId = %d\n", opaque);
  //pthread_spin_lock(&spinlock);
  pthread_mutex_lock(&mutexlock);
  sendGet(key, keylen, opaque);
  //fprintf(stderr, "Main:: send Get numReqs = %d, clientCnt = %d\n", numReqs, clientCnt);
  /*
  if ( numReqs % clientCnt == clientCnt - 1 ){
    //fprintf(stderr, "Main:: flushing pipeline, flushCnt = %d\n", numFlushes++);
    flushDmaBuf();
    flushing = true;
  }
  */

  numReqs++;
  //fprintf(stderr, "Main:: send Get return pointers, clientId = %d\n", opaque);  
  valBufList[opaque] = val;
  valSizeList[opaque] = vallen;
  //pthread_spin_unlock(&spinlock);
  pthread_mutex_unlock(&mutexlock);
  //fprintf(stderr,"Main:: sendGet start waiting, clientId = %d\n", opaque);
  clock_gettime(CLOCK_REALTIME, &end);
  double diff = timespec_diff_usec(start, end);
  //avgSendLatency = avgSendLatency*(double)numGets/(double)(numGets+1) + diff/(double)(numGets+1);
  //pthread_yield();
  sem_wait(&lockList[opaque]);
  clock_gettime(CLOCK_REALTIME, &end);
  diff = timespec_diff_usec(start, end);
  int nGets = atomic_read(&numGets);
  avgLatency = avgLatency*(double)nGets/(double)(nGets+1) + diff/(double)(nGets+1);
  //fprintf(stderr,"Main:: sendGet get Result from FPGA, clientId = %d, numGets = %d\n", opaque, nGets);
  //numGets++;
  atomic_inc(&numGets);
}
void sendDelete(void* key, size_t keylen, uint32_t opaque, bool* success){
  //pthread_spin_lock(&spinlock);
  pthread_mutex_lock(&mutexlock);
  sendDelete(key, keylen, opaque);
  //fprintf(stderr, "Main:: send Delete numReqs = %d, clientCnt = %d\n", numReqs, clientCnt);
  /*
  if ( numReqs % clientCnt == clientCnt - 1 ){
    flushDmaBuf();
    flushing = true;
  }
  */
  numReqs++;
  successList[opaque] = success;
  //pthread_spin_unlock(&spinlock);
  pthread_mutex_unlock(&mutexlock);
  sem_wait(&lockList[opaque]);
}
           

void *decode_response(void *ptr){
  int respCnt = 0;
  protocol_binary_response_header resphdr;
  while (true){
    dmaBufMemreadBuf(&resphdr, sizeof(protocol_binary_response_header));
    resp_cnt++;
    //printhdr(resphdr);
    if ( resphdr.response.magic != PROTOCOL_BINARY_RES ){
      printhdr(resphdr);
      fprintf(stderr, "Main:: response magic is not right\n");
      exit(0);
    }
    if (resphdr.response.opcode == PROTOCOL_BINARY_CMD_SET){
      if ( resphdr.response.status != PROTOCOL_BINARY_RESPONSE_SUCCESS) {
        //fprintf(stderr,"Main:: Set %d fails\n", resphdr.response.opaque);
        //printhdr(resphdr);
        *(successList[resphdr.response.opaque]) = false;
      } else {
        //fprintf(stderr,"Main:: Set %d succeeds\n", resphdr.response.opaque);
        *(successList[resphdr.response.opaque]) = true;
      }
      sem_post(&(lockList[resphdr.response.opaque]));
    } else if (resphdr.response.opcode == PROTOCOL_BINARY_CMD_GET){
      //      fprintf(stderr, "Main:: Get RespCnt = %d\n", respCnt++);
      if(resphdr.response.status == PROTOCOL_BINARY_RESPONSE_SUCCESS){
        //fprintf(stderr,"Main:: Get %d succeeds, vallen = %d\n", resphdr.response.opaque, resphdr.response.bodylen);
        unsigned char* valrecv = new unsigned char[resphdr.response.bodylen];
        dmaBufMemreadBuf(valrecv, resphdr.response.bodylen);
        *(valBufList[resphdr.response.opaque]) = valrecv;
        *(valSizeList[resphdr.response.opaque]) = resphdr.response.bodylen;
      }
      else {
        //fprintf(stderr,"Main:: Get %d fails\n", resphdr.response.opaque);
        //get_fails++;
      }
      sem_post(&(lockList[resphdr.response.opaque]));
    } else if (resphdr.response.opcode == PROTOCOL_BINARY_CMD_EOM ){
      //dmaBufMemreadBuf(&resphdr, sizeof(protocol_binary_response_header));
      //printhdr(resphdr);
      //fprintf(stderr, "Main:: EOM\n");
      assert(resphdr.response.magic == PROTOCOL_BINARY_RES );
      assert(resphdr.response.opcode == PROTOCOL_BINARY_CMD_EOM);
      assert(resphdr.response.bodylen == 0);
      resetDMADstBuf();
      //pthread_mutex_lock(&mutexlock);
      flushing = false;
      //pthread_mutex_unlock(&mutexlock);
      respCnt=0;
      // pthread_mutex_lock(&mu_write);
      // num_resps = resp_cnt;
      // resp_cnt = 0;
      // pthread_cond_signal(&cond_write);
      // pthread_mutex_unlock(&mu_write);
      //      fprintf(stderr, "Response Thread: receive EOM, eomCnt = %d\n", eomCnt++);
    } else if (resphdr.response.opcode == PROTOCOL_BINARY_CMD_DELETE ) {
      assert(resphdr.response.magic == PROTOCOL_BINARY_RES );

      assert(resphdr.response.bodylen == 0);
      *(successList[resphdr.response.opaque]) = true;
      sem_post(&(lockList[resphdr.response.opaque]));
    } else {
      printhdr(resphdr);
      fprintf(stderr,"Main: Response not supported\n");
      exit(1);
    }
    //    fprintf(stderr, "Main:: finish checking a response\n");
    atomic_dec(&outstanding_requests);
  }
}
