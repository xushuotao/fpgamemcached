#ifndef _MEMCACHEDCLIENT_H_
#define _MEMCACHEDCLIENT_H_

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


// user included
#include "protocol_binary.h"



class MemcachedClient {
public:
  MemcachedClient();
  ~MemcachedClient();

  bool set(const void* key,
           size_t      keylen,
           const void* dta,
           size_t      dtalen);
  char* get(char* key, size_t keylen);

  void initSystem(int size1,
                  int size2,
                  int size3,
                  int addr1,
                  int addr2,
                  int addr3);

   

private:

  class ServerIndication : public ServerIndicationWrapper {  
  public:
    
    pthread_mutex_t mutex;
    pthread_cond_t cond;
    //sem_t done_sem;
    Response_Header header;

    virtual void done(Response_Header resp) {
      pthread_mutex_lock(&mutex);
      header = resp;
      //fprintf(stderr, "Indication got response header, magic = %d, opcode = %d and set = %d\n", resp.magic, resp.opcode, PROTOCOL_BINARY_CMD_SET);
      pthread_cond_signal(&cond);
      pthread_mutex_unlock(&mutex);
      //sem_post(&done_sem);
    }
    
    ServerIndication(unsigned int id) : ServerIndicationWrapper(id) {
      /*if(sem_init(&done_sem, 1, 0)){
        fprintf(stderr, "failed to init done_sem\n");
        exit(1);
        }*/
      mutex = PTHREAD_MUTEX_INITIALIZER;
      cond = PTHREAD_COND_INITIALIZER;
    }
   
  };   

  void generate_keydtaBuf(const void*             key,
                          size_t                  keylen,
                          const void*             dta,
                          size_t                  dtalen);

  Request_Header gen_req_header(protocol_binary_command cmd,
                                                const void*             key,
                                                size_t                  keylen,
                                                const void*             dta,
                                                size_t                  dtalen);
  //void send_binary_protocol(const char* buf, size_t bufsz);
  bool process_response(Response_Header header, char* &dtaBuf);

  
  ServerIndication *indication;
  ServerRequestProxy *device;
  
  DmaDebugRequestProxy *hostDmaDebugRequest;// = new DmaDebugRequestProxy(IfcNames_HostDmaDebugRequest);
  MMUConfigRequestProxy *dmap;// = new MMUConfigRequestProxy(IfcNames_HostMMUConfigRequest);
  DmaManager *dma;// = new DmaManager(hostDmaDebugRequest, dmap);
  DmaDebugIndication *hostDmaDebugIndication;// = new DmaDebugIndication(dma, IfcNames_HostDmaDebugIndication);
  MMUConfigIndication *hostMMUConfigIndication;// = new MMUConfigIndication(dma, IfcNames_HostMMUConfigIndication);

  //size_t alloc_sz = 10240;
  
  int srcAlloc;// = portalAlloc(alloc_sz);
  int dstAlloc;// = portalAlloc(alloc_sz);
 
  unsigned int *srcBuffer;// = (unsigned int *)portalMmap(srcAlloc, alloc_sz);
  unsigned int *dstBuffer;// = (unsigned int *)portalMmap(dstAlloc, alloc_sz);

  unsigned int ref_srcAlloc;
  unsigned int ref_dstAlloc;
   
};

#endif

//#include "MemcachedClient.cpp"

   
