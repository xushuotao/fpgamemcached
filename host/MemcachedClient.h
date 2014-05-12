#include <stdio.h>
#include <stdlib.h>

#include <assert.h>

// xbvs-related
#include "ServerIndicationWrapper.h"
#include "ServerRequestProxy.h"
#include "GeneratedTypes.h"

// user included




#ifndef _MEMCACHEDCLIENT_H_
#define _MEMCACHEDCLIENT_H_



class MemcachedClient {
public:
   MemcachedClient();
   ~MemcachedClient();

   bool set(const void* key,
            size_t keylen,
            const void* dta,
            size_t dtalen);
   char* get(char* key, size_t keylen);


   

private:
   class ServerIndication : public ServerIndicationWrapper {  
   public:
      int cnt;

      pthread_mutex_t mu;
      pthread_cond_t  cond;
      
      virtual void hexdump(uint32_t a) {
         printf("hexdump: %08x\n", a);
         printf("%d\n",cnt);
         if (cnt == 7) {
            pthread_cond_broadcast(&cond);
         }
         cnt++;
      }
      ServerIndication(unsigned int id) : ServerIndicationWrapper(id), cnt(0){}

       
   };   

   void generate_command(char* buf,
                         size_t bufsz,
                         uint8_t cmd,
                         const void* key,
                         size_t keylen,
                         const void* dta,
                         size_t dtalen);
   void send_binary_protocol(const char* buf, size_t bufsz);

  
   ServerIndication *indication;
   ServerRequestProxy *device;

   
   
};

#endif

//#include "MemcachedClient.cpp"

   
