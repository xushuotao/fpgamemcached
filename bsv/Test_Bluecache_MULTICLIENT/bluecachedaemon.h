#ifndef _TESTBLUECACHE_
#define _TESTBLUECACHE_
#ifdef __cplusplus
extern "C" {
#endif


#include <stdint.h>
#include <semaphore.h>

  extern double avgLatency;
  extern double avgSendLatency;

  extern int flush_type_0;
  extern int flush_type_1;

  extern int pageSz;

// void printhdr(protocol_binary_response_header v1);
// void dump(const char *prefix, char *buf, size_t len);
// void initMemcached(int size1, int size2, int size3, int addr0, int addr1, int addr2, int addr3);
  double timespec_diff_sec( timespec start, timespec end );

// int waitIdleReadBuffer();
// int waitIdleWriteBuffer();
// void dmaBufMemwrite(char* reqBuf, size_t totalSize);
// void sendSet(void* key, void* val, size_t keylen, size_t vallen, uint32_t opaque);
// void sendGet(void* key, size_t keylen, uint32_t opaque);
// void sendDelete(void* key, size_t keylen, uint32_t opaque);
  void sendSet(void* key, void* val, size_t keylen, size_t vallen, uint32_t opaque, bool* success);
  void sendGet(void* key, size_t keylen, uint32_t opaque, unsigned char** val, size_t* vallen);
  void sendDelete(void* key, size_t keylen, uint32_t opaque, bool* success);
  int initMainThread();
// void sendEom();
// void flushDmaBuf();
// void dmaBufMemreadBuf(void* respBuf, size_t totalSize);
// void resetDMADstBuf();
// void storePerfNumber();
  void initBluecacheProxy();
  void *flush_request(void *ptr);
  void *decode_response(void *ptr);


#ifdef __cplusplus
}
#endif

#endif // _TESTMEMREAD_H_
