#include <stdio.h>
#include <stdlib.h>
//#include "GeneratedTypes.h"
#include <assert.h>
#include <unistd.h>
#include<pthread.h>
// xbvs-related
#include "ServerIndicationWrapper.h"
#include "ServerRequestProxy.h"


// user included




#ifndef _MEMCACHEDCLIENT_H_
#define _MEMCACHEDCLIENT_H_



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
    size_t dtaCnt;
    char* data;

    uint64_t* d;

    pthread_mutex_t mu;
    //pthread_cond_t  cond;
    bool sysReady_i;
    bool dtaReady_i;

    void resetSys (bool v){
      pthread_mutex_lock(&mu);
      sysReady_i = v;
      pthread_mutex_unlock(&mu);
    }

    void resetDta (bool v){
      pthread_mutex_lock(&mu);
      dtaReady_i = false;
      pthread_mutex_unlock(&mu);
    }

    bool sysReady (){
      pthread_mutex_lock(&mu);
      pthread_mutex_unlock(&mu);
      return sysReady_i;
    }
    
    bool dtaReady (){
      pthread_mutex_lock(&mu);
      pthread_mutex_unlock(&mu);
      return dtaReady_i;
    }

    virtual void ready4dta() {
      pthread_mutex_lock(&mu);
      printf("ready4data on client\n");
      printf("dtaReady = %d\n", dtaReady_i);
      dtaReady_i = true;
      printf("dtaReady = %d\n", dtaReady_i);
      pthread_mutex_unlock(&mu);
    }

    virtual void initRdBuf(uint64_t v){
      data = (char*) malloc (v);//new char[v];
      d =  (uint64_t*) data;
      dtaCnt = v;
    }

    virtual void valData(uint64_t v) {
      //char* inputPtr = (char*) &v;
      if (dtaCnt > 8) {
        *d = v;
        d++;
        dtaCnt -= 8;
      }
      else {
        *d = v;
        pthread_mutex_lock(&mu);
        dtaReady_i = true;
        pthread_mutex_unlock(&mu);
      }
      /*
      if (dtaCnt >= 8) {
        for (int i = 0; i < 8; i++){
          data[i] = inputPtr[i];
        }
        d += 8;
        dtaCnt -= 8;
      }
      else {
        printf("Got data %016x\n", v);
        for (int i = 0; i < dtaCnt; i++){
          printf("%c, %02x\n", inputPtr[i], inputPtr[i]);
          data[i] = inputPtr[i];
        }
        pthread_mutex_lock(&mu);
        dtaReady_i = true;
        pthread_mutex_unlock(&mu);
      }
      */
    }
    
    virtual void hexdump(uint32_t a) {
       printf("hexdump: %08x\n", a);
      //      printf("%d\n",cnt);
    }
    ServerIndication(unsigned int id) : ServerIndicationWrapper(id), dtaCnt(0), sysReady_i(true), dtaReady_i(false) {}


       
  };   

  Protocol_Binary_Request_Header gen_req_header(Protocol_Binary_Command cmd,
                                                const void*             key,
                                                size_t                  keylen,
                                                const void*             dta,
                                                size_t                  dtalen);
  //void send_binary_protocol(const char* buf, size_t bufsz);

  
  ServerIndication *indication;
  ServerRequestProxy *device;

   
   
};

#endif

//#include "MemcachedClient.cpp"

   
