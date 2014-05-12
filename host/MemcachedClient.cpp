#include "MemcachedClient.h"

#include <unistd.h>

// xbvs-related


#include "protocol_binary.h"

MemcachedClient::MemcachedClient(){
   indication = new ServerIndication(IfcNames_ServerIndication);
   device = new ServerRequestProxy(IfcNames_ServerRequest);

   pthread_t tid;
   fprintf(stderr, "Constructor::creating exec thread\n");
   if(pthread_create(&tid, NULL,  portalExec, NULL)){
      fprintf(stderr, "Constructor::error creating exec thread\n");
      exit(1);
   }
}

bool MemcachedClient::set(const void* key,
                          size_t keylen,
                          const void* dta,
                          size_t dtalen){
   pthread_mutex_lock(&(indication->mu));
   size_t bufsz = sizeof(protocol_binary_request_header) + keylen + dtalen; 
   char* buf = new char[bufsz];

   printf("bufsize = %d\n", bufsz);
   
   generate_command(buf, bufsz, PROTOCOL_BINARY_CMD_SET, key, keylen, dta, dtalen);

   send_binary_protocol(buf, bufsz);

   printf("shit\n");

   //usleep(1000000);
   delete buf;

   pthread_cond_wait(&(indication->cond), &(indication->mu));
   pthread_mutex_unlock(&(indication->mu));
}

char* MemcachedClient::get(char* key, size_t keylen){
   
}

void MemcachedClient::generate_command(char* buf,
                                       size_t bufsz,
                                       uint8_t cmd,
                                       const void* key,
                                       size_t keylen,
                                       const void* dta,
                                       size_t dtalen) {

   protocol_binary_request_no_extras *request = (protocol_binary_request_no_extras*)buf;
   assert(bufsz == sizeof(*request) + keylen + dtalen);

   memset(request, 0, sizeof(*request));
   request->message.header.request.magic = PROTOCOL_BINARY_REQ;
   request->message.header.request.opcode = cmd;
   request->message.header.request.keylen = keylen;
   request->message.header.request.bodylen = keylen + dtalen;
   request->message.header.request.opaque = 0xdeadbeef;

   off_t key_offset = sizeof(protocol_binary_request_no_extras);

   //if (key != NULL) {
   memcpy(buf + key_offset, key, keylen);
      //}
      // if (dta != NULL) {
   memcpy(buf + key_offset + keylen, dta, dtalen);
      // }                                                 
}

void MemcachedClient::send_binary_protocol(const char* buf, size_t bufsz){
   uint32_t send_word;

   off_t buf_offset = 0;

   size_t step_sz = sizeof(send_word);

   while (buf_offset + step_sz <= bufsz){
      memcpy(&send_word, buf + buf_offset, step_sz);
      printf("%08x\n", send_word);
      device->receive_cmd(send_word);
      buf_offset+=step_sz;
   }

   if (buf_offset < bufsz) {
      send_word = 0;
      memcpy(&send_word, buf + buf_offset, bufsz - buf_offset);
      printf("%08x\n", send_word);
      device->receive_cmd(send_word);
   }
}





/*
  fprintf(stderr, "Main::calling say1(%d)\n", v1a);
  device->say1(v1a);  
  fprintf(stderr, "Main::calling say2(%d, %d)\n", v2a,v2b);
  device->say2(v2a,v2b);
  fprintf(stderr, "Main::calling say3(S1{a:%d,b:%d})\n", s1.a,s1.b);
  device->say3(s1);
  fprintf(stderr, "Main::calling say4(S2{a:%d,b:%d,c:%d})\n", s2.a,s2.b,s2.c);
  device->say4(s2);
  fprintf(stderr, "Main::calling say5(%08x, %016zx, %08x)\n", v5a, v5b, v5c);
  device->say5(v5a, v5b, v5c);  
  fprintf(stderr, "Main::calling say6(%08x, %016zx, %08x)\n", v6a, v6b, v6c);
  device->say6(v6a, v6b, v6c);  
  fprintf(stderr, "Main::calling say7(%08x, %08x)\n", s3.a, s3.e1);
  device->say7(s3);  

  fprintf(stderr, "Main::about to go to sleep\n");
  while(true){sleep(2);}
*/

