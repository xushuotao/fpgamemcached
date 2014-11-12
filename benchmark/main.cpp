#include <stdio.h>
#include <stdlib.h>
//#include "GeneratedTypes.h"
#include <assert.h>
#include <unistd.h>
#include <pthread.h>

#include "StdDmaIndication.h"
#include "DmaDebugRequestProxy.h"
#include "MMUConfigRequestProxy.h"
#include "ServerIndicationWrapper.h"
#include "ServerRequestProxy.h"

#include <unistd.h>
#include <math.h>
#include <string.h>

#include <queue>
#include <time.h>
#include <sys/time.h>
#include <iostream>


// user included
#include "protocol_binary.h"

#define DMA_BUFFER_COUNT 4

#ifdef BSIM
int iters = 100;
#else
int iters = 100000;
#endif

int srcAllocs[DMA_BUFFER_COUNT];         // = portalAlloc(alloc_sz);
int dstAllocs[DMA_BUFFER_COUNT];         // = portalAlloc(alloc_sz);

unsigned int *srcBuffers[DMA_BUFFER_COUNT];// = (unsigned int *)portalMmap(srcAlloc, alloc_sz);
unsigned int *dstBuffers[DMA_BUFFER_COUNT];// = (unsigned int *)portalMmap(dstAlloc, alloc_sz);

unsigned int ref_srcAllocs[DMA_BUFFER_COUNT];
unsigned int ref_dstAllocs[DMA_BUFFER_COUNT];

pthread_mutex_t mutex;
pthread_cond_t  cond;
sem_t           done_sem;

Response_Header header;

std::queue<int> freeList;

class ServerIndication : public ServerIndicationWrapper {  
public:
  bool process_response(Response_Header header, char* &dtaBuf, int id){

    int dtalen;
    if (header.status != PROTOCOL_BINARY_RESPONSE_SUCCESS) {
      fprintf(stderr, "Operation not successful\n");
      return false;
    }

    switch (header.opcode){
    case PROTOCOL_BINARY_CMD_GET:
      dtalen = header.bodylen - header.keylen;
      dtaBuf = new char[dtalen];
      memcpy(dtaBuf, (char*)dstBuffers[id], dtalen); 
      //    fprintf(stderr, "process_response: GET command, nBytes = %d\n", dtalen);
      break;
    case PROTOCOL_BINARY_CMD_SET:
      // fprintf(stderr, "process_response: SET command\n");
      break;
    default:
      fprintf(stderr, "Protocol Not Supported\n");
      return false;
      break;
    }
    
    return true;
  }


  int cnt;

  virtual void done(Response_Header resp, uint32_t id) {
    //fprintf(stderr, "\x1b[31mIndication: Done(cnt = %d, id = %d)\x1b[0m\n", cnt, id);
    pthread_mutex_lock(&mutex);
    freeList.push(id);
    pthread_mutex_unlock(&mutex);
    char* dtaBuf;
    if (!process_response(resp, dtaBuf, id)) {
      exit(0);
    }
    
    if (++cnt == 2*iters) {
      sem_post(&done_sem);
    }
  }
    
  ServerIndication(unsigned int id) : ServerIndicationWrapper(id), cnt(0) {}  
};

ServerIndication   *indication;          // = new ServerIndication(IfcNames_ServerIndication);
ServerRequestProxy *device;              // = new ServerRequestProxy(IfcNames_ServerRequest);

DmaDebugRequestProxy  *hostDmaDebugRequest; //    = new DmaDebugRequestProxy(IfcNames_HostDmaDebugRequest);
MMUConfigRequestProxy *dmap;             //                   = new MMUConfigRequestProxy(IfcNames_HostMMUConfigRequest);
DmaManager            *dma;              //                    = new DmaManager(hostDmaDebugRequest, dmap);
DmaDebugIndication    *hostDmaDebugIndication; // = new DmaDebugIndication(dma, IfcNames_HostDmaDebugIndication);
MMUConfigIndication   *hostMMUConfigIndication; // = new MMUConfigIndication(dma, IfcNames_HostMMUConfigIndication);



//std::queue<int> freeDstList;

size_t generate_keydtaBuf(const void* key,
                          size_t      keylen,
                          const void* dta,
                          size_t      dtalen,
                          int id
                          ){
  int dta_offset = ceil((float)keylen/8.0);
  *((uint64_t*)srcBuffers[id] + dta_offset  - 1) = 0;
  memcpy((char*)srcBuffers[id], key, keylen);
  memcpy(((char*)srcBuffers[id]) + (dta_offset<<3), dta, dtalen);
  return (dta_offset<<3) + dtalen;
}

Request_Header gen_req_header(protocol_binary_command cmd,
                              const void*             key,
                              size_t                  keylen,
                              const void*             dta,
                              size_t dtalen){
  Request_Header                                      request;
  memset(&request, 0, sizeof(request));
  request.magic   = PROTOCOL_BINARY_REQ;
  request.opcode  = cmd;
  request.keylen  = keylen;
  request.bodylen = keylen + dtalen;
  request.opaque  = 0xdeadbeef;
  
  return request;
}



void client_set(const void* key,
                size_t      keylen,
                const void* dta,
                size_t dtalen){

  //int dta_offset = ceil((float)keylen/8.0)*8;
  
  int ind = -1;
  while (true){
    pthread_mutex_lock(&mutex);
    if ( !freeList.empty() ){
      ind = freeList.front();
      freeList.pop();
      pthread_mutex_unlock(&mutex);
      break;
    }
    pthread_mutex_unlock(&mutex);
  }
  size_t bufLen = generate_keydtaBuf(key, keylen, dta, dtalen, ind);
  device->start(gen_req_header(PROTOCOL_BINARY_CMD_SET, key, keylen, dta, dtalen), ref_srcAllocs[ind], ref_dstAllocs[ind], bufLen, ind);

}
   
 


void client_get(char* key, size_t keylen){

  int ind = -1;
  while (true){
    pthread_mutex_lock(&mutex);
    if ( !freeList.empty() ){
      ind = freeList.front();
      freeList.pop();
      pthread_mutex_unlock(&mutex);
      break;
    }
    pthread_mutex_unlock(&mutex);
  }
  size_t bufLen = generate_keydtaBuf(key, keylen, NULL, 0, ind);
  device->start(gen_req_header(PROTOCOL_BINARY_CMD_GET, key, keylen, NULL, 0), ref_srcAllocs[ind], ref_dstAllocs[ind], bufLen, ind);


}

void initSystem(int size1,
                int size2,
                int size3,
                int addr1,
                int addr2,
                int addr3){

  int               lgSz1 = (int)log2((double)size1);
  int               lgSz2 = (int)log2((double)size2);
  int               lgSz3 = (int)log2((double)size3);

  if ( lgSz2 <= lgSz1 ) lgSz2 = lgSz1+1;
  if ( lgSz3 <= lgSz2 ) lgSz3 = lgSz2+1;

  int lgAddr1 = (int)log2((double)addr1);
  int lgAddr2 = (int)log2((double)addr2);
  int lgAddr3 = (int)log2((double)addr3);

  if ( lgAddr2 <= lgAddr1 ) lgAddr2 = lgAddr1+1;
  if ( lgAddr3 <= lgAddr2 ) lgAddr3 = lgAddr2+1;

  device->initValDelimit(lgSz1, lgSz2, lgSz3);
  device->initAddrDelimit(lgAddr1, lgAddr2, lgAddr3);
}
   

int main(){

  mutex = PTHREAD_MUTEX_INITIALIZER;
  cond  = PTHREAD_COND_INITIALIZER;

  if(sem_init(&done_sem, 1, 0)){
    fprintf(stderr, "failed to init done_sem\n");
    exit(1);
  }


  indication = new ServerIndication(IfcNames_ServerIndication);
  device     = new ServerRequestProxy(IfcNames_ServerRequest);
  
  hostDmaDebugRequest     = new DmaDebugRequestProxy(IfcNames_HostDmaDebugRequest);
  dmap                    = new MMUConfigRequestProxy(IfcNames_HostMMUConfigRequest);
  dma                     = new DmaManager(hostDmaDebugRequest, dmap);
  hostDmaDebugIndication  = new DmaDebugIndication(dma, IfcNames_HostDmaDebugIndication);
  hostMMUConfigIndication = new MMUConfigIndication(dma, IfcNames_HostMMUConfigIndication);
  

  size_t alloc_sz = 256 + (1 << 20);     // + key_offset;
  
  fprintf(stderr, "Main::allocating memory...\n");

  for (int i = 0; i < DMA_BUFFER_COUNT; i++){
    srcAllocs[i] = portalAlloc(alloc_sz);
    dstAllocs[i] = portalAlloc(alloc_sz);
    
    srcBuffers[i] = (unsigned int *)portalMmap(srcAllocs[i], alloc_sz);
    dstBuffers[i] = (unsigned int *)portalMmap(dstAllocs[i], alloc_sz);
  }

  portalExec_start();

  for (int i = 0; i < DMA_BUFFER_COUNT; i++){
    portalDCacheFlushInval(srcAllocs[i], alloc_sz, srcBuffers[i]);
    portalDCacheFlushInval(dstAllocs[i], alloc_sz, dstBuffers[i]);
    fprintf(stderr, "Main::flush and invalidate [pair %d] complete\n", i);

    ref_srcAllocs[i] = dma->reference(srcAllocs[i]);
    ref_dstAllocs[i] = dma->reference(dstAllocs[i]);
  
    fprintf(stderr, "ref_srcAllocs[%d] = %d\n", i, ref_srcAllocs[i]);
    fprintf(stderr, "ref_dstAllocs[%d] = %d\n", i, ref_dstAllocs[i]);
  }

  fprintf(stderr, "Main::initialize free lists\n");
  for (int i = 0; i < DMA_BUFFER_COUNT; i++){
    freeList.push(i);
  }

  initSystem(8,16,32, 1<<25, 1<<26, 1<<27);
   

  /****** Benchmark Code *******/
  srand(time(NULL));

  timeval t1, t2;
  double elapsedTime;//, avg_t_set=0, avg_t_get=0;

  int keySz = 64;                    //k+1;// rand()%255 + 1;//64;
  int valSz;
  std::cout << "Input value size: ";
  std::cin >> valSz;

  char* key   = (char*) malloc (keySz);
  char* value = (char*) malloc(valSz);

  int i;
  for (i=0; i<valSz; i++)
    value[i] = rand()%26+'a';
  
  gettimeofday(&t1, NULL);
  for ( int k = 0; k < iters; k++ ){
    for (i=0; i<keySz; i++)
      key[i] = rand()%26+'a';
    client_set(key, keySz, value, valSz);
    client_get(key, keySz);
  }

  sem_wait(&done_sem);
  gettimeofday(&t2, NULL);
  elapsedTime = (t2.tv_sec - t1.tv_sec) * 1000.0; // sec to ms
  elapsedTime += (t2.tv_usec - t1.tv_usec) / 1000.0;   // us to ms
  printf("Main:: Done executing %d queries in %lf millisecs\n", iters*2, elapsedTime );
  printf("Main:: %f queries per second\n", iters*2/elapsedTime*1000);

}
