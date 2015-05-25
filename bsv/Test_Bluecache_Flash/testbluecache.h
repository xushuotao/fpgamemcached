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



class BluecacheIndication : public BluecacheIndicationWrapper
{
public:
  int eraseAcks;
  int dumpAcks;
  virtual void eraseDone(uint32_t tag, uint32_t status){
    pthread_mutex_lock(&mu_read);
    
    int idx = tag2blockTable[tag];
    int block = idx%BLOCKS_PER_CHIP;
    int chip = (idx/BLOCKS_PER_CHIP)%CHIPS_PER_BUS;
    int bus = (idx/(BLOCKS_PER_CHIP*CHIPS_PER_BUS))%NUM_BUSES;
    if (status == 0) {
      fprintf(stderr,"Main:: eraseDone, Flash bus_%d, chip_%d, block_%d is FRESH\n", bus, chip, block);
      flashStatus[bus][chip][block] = FRESH;
    }
    else{
      fprintf(stderr,"Main:: eraseDone, Flash bus_%d, chip_%d, block_%d is BAD\n", bus, chip, block);
      flashStatus[bus][chip][block] = BAD;
    }
    eraseTagQ.push(tag);

    
    if (++eraseAcks == REAL_TotalBlocks){
      fprintf(stderr, "Main:: all erases ack\n");
      pthread_cond_signal(&cond); 
    }
    pthread_mutex_unlock(&mu_read);

  }
  
  virtual void dumpMapResp(uint32_t blockIdx, uint32_t status){
    pthread_mutex_lock(&mu_read);
    int block = blockIdx;
    int chip = (dumpAcks/REAL_BLOCKS_PER_CHIP)%CHIPS_PER_BUS;
    int bus = (dumpAcks/(REAL_BLOCKS_PER_CHIP*CHIPS_PER_BUS))%NUM_BUSES;
    if (status == 1) {
      fprintf(stderr,"Main:: dumpBlockStatus, Flash bus_%d, chip_%d, block_%d is FRESH\n", bus, chip, block);
      flashStatus[bus][chip][block] = FRESH;
    }
    else{
      fprintf(stderr,"Main:: dumpBlockStatus, Flash bus_%d, chip_%d, block_%d is WRITTEN\n", bus, chip, block);
      flashStatus[bus][chip][block] = WRITTEN;
    }
    
    if (++dumpAcks == REAL_TotalBlocks){
      pthread_cond_signal(&cond); 
    }
    pthread_mutex_unlock(&mu_read);
  }

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
  BluecacheIndication(int id) : BluecacheIndicationWrapper(id), eraseAcks(0), dumpAcks(0){}
};

double timespec_diff_sec( timespec start, timespec end ) {
  double t = end.tv_sec - start.tv_sec;
  t += ((double)(end.tv_nsec - start.tv_nsec)/1000000000L);
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
/*
void checkSetResp(int numTests){
  protocol_binary_response_header resphdr;
  for (int i = 0; i < numTests; i++){
    //fprintf(stderr, "Main:: checking set resp %d\n", i);
    dmaBufMemreadBuf(&resphdr, sizeof(protocol_binary_response_header));
    if ( resphdr.response.magic != PROTOCOL_BINARY_RES ){
      printhdr(resphdr);
      fprintf(stderr, "Main:: set %d is not right\n", i);
      exit(0);
    }
    assert(resphdr.response.opcode == PROTOCOL_BINARY_CMD_SET);
    //assert(resphdr.response.status == PROTOCOL_BINARY_RESPONSE_SUCCESS);
    if ( resphdr.response.status != PROTOCOL_BINARY_RESPONSE_SUCCESS) {
      fprintf(stderr,"Main:: Set %d fails\n", i);
      printhdr(resphdr);
      set_fails++;
      setStatus[resphdr.response.opaque] = false;
    } else {
      setStatus[resphdr.response.opaque] = true;
    }
    assert(resphdr.response.bodylen == 0);
    //fprintf(stderr, "Main:: finish checking set resp %d\n", i);
   
  }

  dmaBufMemreadBuf(&resphdr, sizeof(protocol_binary_response_header));
  printhdr(resphdr);
  assert(resphdr.response.magic == PROTOCOL_BINARY_RES );
  assert(resphdr.response.opcode == PROTOCOL_BINARY_CMD_EOM);
  assert(resphdr.response.bodylen == 0);
  resetDMADstBuf();

}

void checkGetResp(int numTests){
  protocol_binary_response_header resphdr;
  char* valrecv;
  
  for (int i = 0; i < numTests; i++){
    //fprintf(stderr, "Main:: checking get resp %d\n", i);
    
    //valrecv = new char[vallenArray[i]];
    dmaBufMemreadBuf(&resphdr, sizeof(protocol_binary_response_header));

    //printhdr(resphdr);
    if ( resphdr.response.magic != PROTOCOL_BINARY_RES ){
      fprintf(stderr,"Main:: Get %d header incorrect\n", i);
      printhdr(resphdr);
      fprintf(stderr, "Main:: vallenArray[%d] = %d\n", i, vallenArray[i]);
      exit(0);
    }
    //assert(resphdr.response.magic == PROTOCOL_BINARY_RES);
    assert(resphdr.response.opcode == PROTOCOL_BINARY_CMD_GET);
    if(resphdr.response.status == PROTOCOL_BINARY_RESPONSE_SUCCESS){
      valrecv = new char[resphdr.response.bodylen];
      
      dmaBufMemreadBuf(valrecv, resphdr.response.bodylen);
      if ( setStatus[resphdr.response.opaque] ) {
        assert(resphdr.response.bodylen == vallenArray[resphdr.response.opaque]);
        if ( memcmp(valrecv, valArray[resphdr.response.opaque], resphdr.response.bodylen)){
          fprintf(stderr, "Main:: value is not received correctly\n");
          for(int j = 0; j < vallenArray[resphdr.response.opaque]; j++){
            fprintf(stderr, "Main:: valrecv[%d] = %x, valArray[%d] = %x, match = %d\n", j, valrecv[j], j, valArray[resphdr.response.opaque][j], valrecv[j]==valArray[resphdr.response.opaque][j]); 
          }
          exit(0);
        }
      }
      delete valrecv;
    }
    else {
      fprintf(stderr,"Main:: Get %d fails\n", i);
      get_fails++;
    }

    //fprintf(stderr, "Main:: finish checking get resp %d\n", i);
  }

  dmaBufMemreadBuf(&resphdr, sizeof(protocol_binary_response_header));
  printhdr(resphdr);
  assert(resphdr.response.magic == PROTOCOL_BINARY_RES );
  assert(resphdr.response.opcode == PROTOCOL_BINARY_CMD_EOM);
  assert(resphdr.response.bodylen == 0);
  resetDMADstBuf();
}*/
 
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

void formatBlueming(){
  fprintf(stderr, "Main:: Formatting Blueming\n");
  for ( int bus = 0; bus < NUM_BUSES; bus++ ){
    for ( int chip = 0; chip < CHIPS_PER_BUS; chip++){
      for ( int block = 0; block < REAL_BLOCKS_PER_CHIP; block++){
        int realblock = (block+currUNINITBlockId[bus][chip])%BLOCKS_PER_CHIP;
        int tag = waitIdleEraseTag();
        pthread_mutex_lock(&mu_read);
        tag2blockTable[tag] = indexRealConvert(bus, chip, realblock);
        pthread_mutex_unlock(&mu_read);
        fprintf(stderr, "Main:: Erase bus = %d, chip = %d, block = %d, tag = %d\n", bus, chip, block, tag);
        device->eraseBlock(bus, chip, realblock, tag);
      }
    }
  }
  fprintf(stderr, "Main:: Finish sending erase cmds to Blueming\n");
  pthread_mutex_lock(&mu_read);
  fprintf(stderr, "Main:: Waiting for all erase acks from Blueming\n");
  pthread_cond_wait(&cond, &mu_read);
  pthread_mutex_unlock(&mu_read);
  fprintf(stderr, "Main:: Finish formatting Blueming\n");
    
}

int searchNextFreshBlock(int bus, int chip){
  for ( int i = currFRESHBlockId[bus][chip]; i < BLOCKS_PER_CHIP; i++){
    if (flashStatus[bus][chip][i] == FRESH){
      (currFRESHBlockId[bus][chip])++;
      return i;
    }
  }
  return -1;
}

int firstFreshBlock(int bus, int chip){
  for ( int i = 0; i < BLOCKS_PER_CHIP; i++){
    if (flashStatus[bus][chip][i] == FRESH){
      return i;
    }
  }
  return 0;
}

int firstUninitBlock(int bus, int chip){
  for ( int i = 0; i < BLOCKS_PER_CHIP; i++){
    if (flashStatus[bus][chip][i] == UNINIT){
      return i;
    }
  }
  return 0;
}

Bool populateMappingTable(){
  int blockMapTable[NUM_BUSES*CHIPS_PER_BUS*REAL_BLOCKS_PER_CHIP];
  for ( int bus = 0; bus < NUM_BUSES; bus++ ){
    for ( int chip = 0; chip < CHIPS_PER_BUS; chip++){
      for ( int block = 0; block < REAL_BLOCKS_PER_CHIP; block++){
        int blkId = searchNextFreshBlock(bus,chip);
        if ( blkId < 0 )
          return false;
        else
          blockMapTable[indexVirtualConvert(bus, chip, block)] = blkId;
      }
    }
  }
  
  for ( int i = 0; i < NUM_BUSES*CHIPS_PER_BUS*REAL_BLOCKS_PER_CHIP; i++){
    device->populateMap(i, blockMapTable[i]);
  }
  return true;
}

void storeFlashStatus(){
  device->dumpMap(0);
  pthread_mutex_lock(&mu_read);
  pthread_cond_wait(&cond, &mu_read);
  pthread_mutex_unlock(&mu_read);
  FILE * pFile = fopen("/home/shuotao/bluemingstatus.txt", "w");
  if ( pFile ){
    for ( int bus = 0; bus < NUM_BUSES; bus++ ){
      for ( int chip = 0; chip < CHIPS_PER_BUS; chip++){
        for ( int block = 0; block < BLOCKS_PER_CHIP; block++){
          fprintf(pFile, "%d\n", flashStatus[bus][chip][block]);
        }
      }
    }
    fclose(pFile);
  } else {
    fprintf(stderr,"File open failed\n");
    exit(0);
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


void *decode_response(void *ptr);
           
           
int runtest(int argc, const char ** argv)
{

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

  int numBufs = ALLOC_SZ/DMABUF_SZ;

  /****** erase blocks if bad blocktable doesn't exist******/
  pthread_mutex_lock(&mu_read);
  for ( int i = 0; i < 128; i++){
    eraseTagQ.push(i);
  }

  for ( int bus = 0; bus < NUM_BUSES; bus++ ){
    for ( int chip = 0; chip < CHIPS_PER_BUS; chip++){
      currFRESHBlockId[bus][chip] = 0;
      currUNINITBlockId[bus][chip] = 0;
      for ( int block = 0; block < BLOCKS_PER_CHIP; block++){
        flashStatus[bus][chip][block] = UNINIT;
      }
    }
  }
  pthread_mutex_unlock(&mu_read);

  
  FILE * pFile = fopen("/home/shuotao/bluemingstatus.txt", "r");
  if ( pFile ){
    fprintf(stderr, "Main:: FlashStatus File Exists on Disk\n");
    for ( int bus = 0; bus < NUM_BUSES; bus++ ){
      for ( int chip = 0; chip < CHIPS_PER_BUS; chip++){
        for ( int block = 0; block < BLOCKS_PER_CHIP; block++){
          fscanf(pFile, "%d", &(flashStatus[bus][chip][block]));
        }
      }
    }
    fclose(pFile);
  } else {
    fprintf(stderr, "Main:: FlashStatus File does not Exists on Disk\n");
    formatBlueming();
  }
  
  pthread_mutex_lock(&mu_read);
  for ( int bus = 0; bus < NUM_BUSES; bus++ ){
    for ( int chip = 0; chip < CHIPS_PER_BUS; chip++){
      currFRESHBlockId[bus][chip] = firstFreshBlock(bus,chip);
      currUNINITBlockId[bus][chip] = firstUninitBlock(bus,chip);
    }
  }
  pthread_mutex_unlock(&mu_read);



  while( !populateMappingTable() ){
    formatBlueming();
    /*if (!populateMappingTable()){
      fprintf(stderr,"Main:: Not enough number of good blocks on device\n");
      exit(0);
      }*/
    
    for ( int bus = 0; bus < NUM_BUSES; bus++ ){
      for ( int chip = 0; chip < CHIPS_PER_BUS; chip++){
        currUNINITBlockId[bus][chip] = firstUninitBlock(bus,chip);
      }
    }
  }



  device->initDMARefs(ref_srcAlloc, ref_dstAlloc);

  pthread_mutex_lock(&mu_read);
  for (uint32_t t = 0; t < numBufs; t++) {
    uint32_t byteoffset = t * DMABUF_SZ;
    freeReadBufId.push(byteoffset);
    device->freeWriteBufId(byteoffset);
  }
  pthread_mutex_unlock(&mu_read);
  

  device->initDMABufSz(DMABUF_SZ);
  //initMemcached(8193, 8194, 8195 , 1<<25, (1<<25)+(1<<14)+8193*2048, 1<<27, 1<<29);
  initMemcached(128, 256, 1024, 1<<25, 1<<26, 1<<27, 1<<29);
  //initMemcached(128, 256, 1024, 1<<28, 1<<28+1, 1<<29, 1<<30);
  //initMemcached(8193, 8194, 8195 , 1<<25, (1<<25)+(1<<14)+8193, 1<<27, 1<<29);

  //sem_wait(&initDone_sem);
  pthread_mutex_lock(&mu_read);
  pthread_cond_wait(&cond, &mu_read);
  pthread_mutex_unlock(&mu_read);


  int numTests, numGets;
  std::cout << "Enter number of Sets: ";
  std::cin >> numTests;
  std::cout << "Enter number of Gets: ";
  std::cin >> numGets;
  //std:: cout << std::endl;

  keyArray = new char*[numTests];
  valArray = new char*[numTests];
  
  keylenArray = new int[numTests];
  vallenArray = new int[numTests];

  setStatus = new bool[numTests];

  int keylen;
  int vallen;
  srand (time(NULL));
  timespec start, now;
  
  clock_gettime(CLOCK_REALTIME, &start);
  for ( int i = 0; i < numTests; i++ ){
    //keylen = 64;//rand()%255 + 1;
    //vallen = 8192-8-keylen;
    //keylen = rand()%255+1;
    //vallen = rand()%255+1;
    keylen = 64;
    vallen = 64;
    keylenArray[i] = keylen;
    vallenArray[i] = vallen;

    keyArray[i] = new char[keylen];
    for ( int j = 0; j < keylen; j++ ){
      keyArray[i][j] = rand();
    }

    valArray[i] = new char[vallen];
    for (int j = 0; j < vallen; j++){
      valArray[i][j] = j;//rand();
    }
    sendSet(keyArray[i], valArray[i], keylen, vallen, i);
  }
  flushDmaBuf();

  //checkSetResp(numTests);
  pthread_mutex_lock(&mu_write);
  pthread_cond_wait(&cond_write, &mu_write);
  pthread_mutex_unlock(&mu_write);
                         
  clock_gettime(CLOCK_REALTIME, & now);
  fprintf(stderr, "Main:: Set Test Successful, num_resps = %d\n", num_resps);
  fprintf(stderr, "Main:: Set Test Successful, %f MRPS\n", (num_resps-1)/(timespec_diff_sec(start, now)*1000000));
  sleep(1);

  clock_gettime(CLOCK_REALTIME, & start);
  for ( int i = 0; i < numGets; i++ ){
    //int i = (keylen-1)*32+j;
    //keylen = 64;//rand()%256 + 1;
    //int j = rand()%128;
    int j = rand()%numTests;
    //int j = i%numTests; 
    keylen = keylenArray[j];
    sendGet(keyArray[j], keylen, j);
  }
  flushDmaBuf();

  pthread_mutex_lock(&mu_write);
  pthread_cond_wait(&cond_write, &mu_write);
  pthread_mutex_unlock(&mu_write);
  

  //checkGetResp(numTests);
  clock_gettime(CLOCK_REALTIME, & now);
  fprintf(stderr, "Main:: Get Test Successful, num_resps = %d\n", num_resps);
  fprintf(stderr, "Main:: Get Test Successful, %f MRPS\n", (num_resps-1)/(timespec_diff_sec(start, now)*1000000));


  fprintf(stderr, "Main:: All tests finished, set fails = %d, get fails = %d\n", set_fails, get_fails);
  storeFlashStatus();
  //storePerfNumber();
  fprintf(stderr, "Main:: FlashStatus Store on Disk = %d\n");
  
  exit(0);
}

void *decode_response(void *ptr){
  protocol_binary_response_header resphdr;
  while (true){
    dmaBufMemreadBuf(&resphdr, sizeof(protocol_binary_response_header));
    resp_cnt++;
    /*clock_gettime(CLOCK_REALTIME, &now); 
    if (greaterThanInterval(interval_start, now)){
      perf_sample.push_back((resp_cnt)/(timespec_diff_sec(start, now)*1000));
      interval_start = now;
      }*/
    if ( resphdr.response.magic != PROTOCOL_BINARY_RES ){
      printhdr(resphdr);
      fprintf(stderr, "Main:: response magic is not right\n");
      exit(0);
    }
    if (resphdr.response.opcode == PROTOCOL_BINARY_CMD_SET){
      //assert(resphdr.response.status == PROTOCOL_BINARY_RESPONSE_SUCCESS);
      if ( resphdr.response.status != PROTOCOL_BINARY_RESPONSE_SUCCESS) {
        fprintf(stderr,"Main:: Set %d fails\n", resphdr.response.opaque);
        printhdr(resphdr);
        set_fails++;
        setStatus[resphdr.response.opaque] = false;
      } else {
        setStatus[resphdr.response.opaque] = true;
      }
      assert(resphdr.response.bodylen == 0);
    } else if (resphdr.response.opcode == PROTOCOL_BINARY_CMD_GET){
      if(resphdr.response.status == PROTOCOL_BINARY_RESPONSE_SUCCESS){
        char* valrecv = new char[resphdr.response.bodylen];
      
        dmaBufMemreadBuf(valrecv, resphdr.response.bodylen);
        if ( setStatus[resphdr.response.opaque] ) {
          assert(resphdr.response.bodylen == vallenArray[resphdr.response.opaque]);
          if ( memcmp(valrecv, valArray[resphdr.response.opaque], resphdr.response.bodylen)){
            fprintf(stderr, "Main:: value is not received correctly\n");
          for(int j = 0; j < vallenArray[resphdr.response.opaque]; j++){
            fprintf(stderr, "Main:: valrecv[%d] = %x, valArray[%d] = %x, match = %d\n", j, valrecv[j], j, valArray[resphdr.response.opaque][j], valrecv[j]==valArray[resphdr.response.opaque][j]); 
          }
          exit(0);
        }
        }
        delete valrecv;
      }
      else {
        fprintf(stderr,"Main:: Get %d fails\n", resphdr.response.opaque);
        get_fails++;
      }
    } else if (resphdr.response.opcode == PROTOCOL_BINARY_CMD_EOM ){
      //dmaBufMemreadBuf(&resphdr, sizeof(protocol_binary_response_header));
      //printhdr(resphdr);
      assert(resphdr.response.magic == PROTOCOL_BINARY_RES );
      assert(resphdr.response.opcode == PROTOCOL_BINARY_CMD_EOM);
      assert(resphdr.response.bodylen == 0);
      resetDMADstBuf();
      pthread_mutex_lock(&mu_write);
      num_resps = resp_cnt;
      resp_cnt = 0;
      pthread_cond_signal(&cond_write);
      pthread_mutex_unlock(&mu_write);
    } else {
      printhdr(resphdr);
      fprintf(stderr,"Main: Response not supported\n");
      exit(1);
    }
    //fprintf(stderr, "Main:: finish checking set resp %d\n", i);
  }
}
#endif // _TESTMEMREAD_H_
