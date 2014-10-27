#include "MemcachedClient.h"
//#include "GeneratedTypes.h"
#include <unistd.h>
#include <math.h>
#include <string.h>

// xbvs-related


#include "protocol_binary.h"

//int key_offset = ceil((float)sizeof(Protocol_Binary_Request_Header)/8.0)*8;


MemcachedClient::MemcachedClient(){
  
  indication = new ServerIndication(IfcNames_ServerIndication);
  device = new ServerRequestProxy(IfcNames_ServerRequest);

  hostDmaDebugRequest = new DmaDebugRequestProxy(IfcNames_HostDmaDebugRequest);
  dmap = new MMUConfigRequestProxy(IfcNames_HostMMUConfigRequest);
  dma = new DmaManager(hostDmaDebugRequest, dmap);
  hostDmaDebugIndication = new DmaDebugIndication(dma, IfcNames_HostDmaDebugIndication);
  hostMMUConfigIndication = new MMUConfigIndication(dma, IfcNames_HostMMUConfigIndication);

  fprintf(stderr, "Main::allocating memory...\n");

  size_t alloc_sz = 256 + (1 << 20);// + key_offset;
  
  srcAlloc = portalAlloc(alloc_sz);
  dstAlloc = portalAlloc(alloc_sz);
 
  srcBuffer = (unsigned int *)portalMmap(srcAlloc, alloc_sz);
  dstBuffer = (unsigned int *)portalMmap(dstAlloc, alloc_sz);

  portalExec_start();

  portalDCacheFlushInval(srcAlloc, alloc_sz, srcBuffer);
  portalDCacheFlushInval(dstAlloc, alloc_sz, dstBuffer);
  fprintf(stderr, "Main::flush and invalidate complete\n");

  ref_srcAlloc = dma->reference(srcAlloc);
  ref_dstAlloc = dma->reference(dstAlloc);
  
  fprintf(stderr, "ref_srcAlloc=%d\n", ref_srcAlloc);
  fprintf(stderr, "ref_dstAlloc=%d\n", ref_dstAlloc);

}

bool MemcachedClient::set(const void* key,
                          size_t keylen,
                          const void* dta,
                          size_t dtalen){

  int dta_offset = ceil((float)keylen/8.0)*8;
  
  generate_keydtaBuf(key, dta_offset, dta, dtalen);
  
  device->start(gen_req_header(PROTOCOL_BINARY_CMD_SET, key, keylen, dta, dtalen), ref_srcAlloc, ref_dstAlloc, dta_offset + dtalen);

  //sem_wait(&indication->done_sem);

  pthread_mutex_lock(&indication->mutex);
  pthread_cond_wait(&indication->cond, &indication->mutex);
  //fprintf(stderr, "Wait finished\n");
  Response_Header header = indication->header;
  pthread_mutex_unlock(&indication->mutex);

  char* retval = NULL;
  return process_response(header, retval);
  
  
}
   
 


char* MemcachedClient::get(char* key, size_t keylen){

  generate_keydtaBuf(key, keylen, NULL, 0);
  //fprintf(stderr, "shit\n");
  device->start(gen_req_header(PROTOCOL_BINARY_CMD_GET, key, keylen, NULL, 0), ref_srcAlloc, ref_dstAlloc, keylen);

  //sem_wait(&indication->done_sem);
  pthread_mutex_lock(&indication->mutex);
  pthread_cond_wait(&indication->cond, &indication->mutex);
  Response_Header header = indication->header;
  pthread_mutex_unlock(&indication->mutex);

  char* retval = NULL;
  
  process_response(header, retval);

  return retval;

}

void MemcachedClient::initSystem(int size1,
                                 int size2,
                                 int size3,
                                 int addr1,
                                 int addr2,
                                 int addr3){
  int lgSz1 = (int)log2((double)size1);
  int lgSz2 = (int)log2((double)size2);
  int lgSz3 = (int)log2((double)size3);

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




void MemcachedClient::generate_keydtaBuf(const void*             key,
                                       size_t                  keylen,
                                       const void*             dta,
                                       size_t                  dtalen){
  //memcpy(srcBuffer, &header, sizeof(header));
  memcpy(srcBuffer, key, keylen);
  memcpy(((char*)srcBuffer) + keylen, dta, dtalen);
}

Request_Header MemcachedClient::gen_req_header(protocol_binary_command cmd,
                                               const void* key,
                                               size_t keylen,
                                               const void* dta,
                                               size_t dtalen){
  Request_Header request;
  memset(&request, 0, sizeof(request));
  request.magic = PROTOCOL_BINARY_REQ;
  request.opcode = cmd;
  request.keylen = keylen;
  request.bodylen = keylen + dtalen;
  request.opaque = 0xdeadbeef;
  
  return request;
}



bool MemcachedClient::process_response(Response_Header header, char* &dtaBuf){

  int dtalen;
  if (header.status != PROTOCOL_BINARY_RESPONSE_SUCCESS) {
    fprintf(stderr, "Operation not successful\n");
    return false;
  }

  switch (header.opcode){
  case PROTOCOL_BINARY_CMD_GET:
    dtalen = header.bodylen - header.keylen;
    dtaBuf = new char[dtalen];
    memcpy(dtaBuf, (char*)dstBuffer, dtalen); 
    fprintf(stderr, "process_response: GET command, nBytes = %d\n", dtalen);
    break;
  case PROTOCOL_BINARY_CMD_SET:
    fprintf(stderr, "process_response: SET command\n");
    break;
  default:
    fprintf(stderr, "Protocol Not Supported\n");
    return false;
    break;
  }
  
  return true;
}

/*
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
*/
/*
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
*/




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

