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
/*
 *
 * Note: the parameters set in this file and Top.bsv have been chose carefully.  They represent the
 *       minimal resource usage required to achieve maximum memory bandwidth utilization on the kc705
 *       and zedboard platforms.
 *       
 *       dma_read_buff: the zedboard requires at least 5 outstanding read commands to achieve full
 *       memory read bandwidth of 0.89 (40 64-bit beats with a burst-len of 8 beats).  We are unsure 
 *       exactly why, but each time a read request is transmitted, there is a 1-cycle delay in the 
 *       pipelined read responses (which otherwise return 64 bits per cycle).   With a burst length of 8 
 *       beats, this implies an 11% overhead.  The kc705 requires at least 8 outstanding read commands
 *       to achieve full read bandwidth of 1.0 (64 64-bit beats with a burst-len of 8 beats).  The
 *       unbuffered version of this test (memread_nobuff) achieves full throughput simply by permitting
 *       an unlimited number of outstanding read commands.  This is only safe if the application can 
 *       guarantee the availability of buffering to receive read responses.  If you don't know, be safe and
 *       use buffering.
 *        
 */

#ifndef _TESTMEMREAD_H_
#define _TESTMEMREAD_H_

#include "StdDmaIndication.h"
#include "MemServerRequest.h"
#include "MMURequest.h"
#include "MemreadRequest.h"
#include "MemreadIndication.h"
#include <string.h>

#include "protocol_binary.h"

#include <stdlib.h>     /* srand, rand */
#include <time.h>


#include <iostream>

sem_t test_sem;

protocol_binary_request_header* headerArray;
int* keylenArray;

size_t alloc_sz = 1<<20;

char** keyArray;

bool cmp(protocol_binary_request_header v1, protocol_binary_request_header v2){
  bool retval = true;
  retval&=(v1.request.magic == v2.request.magic);
  retval&=(v1.request.opcode == v2.request.opcode);
  retval&=(v1.request.keylen == v2.request.keylen);
  retval&=(v1.request.extlen == v2.request.extlen);
  retval&=(v1.request.datatype == v2.request.datatype);
  retval&=(v1.request.reserved == v2.request.reserved);
  retval&=(v1.request.bodylen == v2.request.bodylen);
  retval&=(v1.request.opaque == v2.request.opaque);
  retval&=(v1.request.cas == v2.request.cas);
  fprintf(stderr, "magic %x, %x\n", v1.request.magic, v2.request.magic);
  fprintf(stderr, "opcode %x, %x\n", v1.request.opcode, v2.request.opcode);
  fprintf(stderr, "keylen %x, %x\n", v1.request.keylen, v2.request.keylen);
  fprintf(stderr, "extlen %x, %x\n", v1.request.extlen, v2.request.extlen);
  fprintf(stderr, "datatype %x, %x\n", v1.request.datatype, v2.request.datatype);
  fprintf(stderr, "reserved %x, %x\n", v1.request.reserved, v2.request.reserved);
  fprintf(stderr, "bodylen %x, %x\n", v1.request.bodylen, v2.request.bodylen);
  fprintf(stderr, "opaque %x, %x\n", v1.request.opaque, v2.request.opaque);
  fprintf(stderr, "cas %x, %x\n", v1.request.cas, v2.request.cas);
  return retval;
}



void dump(const char *prefix, char *buf, size_t len)
{
    fprintf(stderr, "%s ", prefix);
    for (int i = 0; i < (len > 16 ? 16 : len) ; i++)
	fprintf(stderr, "%02x", (unsigned char)buf[i]);
    fprintf(stderr, "\n");
}

class MemreadIndication : public MemreadIndicationWrapper
{
public:
  unsigned int cnt0;
  unsigned int cnt;
  int keyCnt;
  char* keyRecv;
  virtual void readHeader(uint64_t v0, uint64_t v1, uint64_t v2){
    protocol_binary_request_header h;
    uint64_t *ptr = (uint64_t*)&h;
    ptr[0] = v0;
    ptr[1] = v1;
    ptr[2] = v2;
    //fprintf(stderr, "Main:: header right = %d\n", cmp(v, header) );
    if (memcmp(&h,headerArray+cnt0,sizeof(protocol_binary_request_header)) == 0) {
      fprintf(stderr, "Main:: header parsing[%d] success\n", cnt0++);
    }
    else {
      fprintf(stderr, "Main:: header parsing[%d] failed\n", cnt0++);
      cmp(h, headerArray[cnt0]);
      exit(0);
    }

  }
  virtual void readTokens(uint64_t v0, uint64_t v1){

    fprintf(stderr, "Main:: header kvToken = %016lx%016lx\n", v1, v0 );
    
    if (keyCnt == 0 ) keyRecv = new char[keylenArray[cnt]];
    
    if ( keyCnt + 16 >= keylenArray[cnt] ){
      //fprintf(stderr, "Main:: niga suck\n");
      uint64_t keys [2] = {v0, v1};
      memcpy(keyRecv + keyCnt, &keys, keylenArray[cnt] - keyCnt);
      //((uint64_t*)keyRecv)[keyCnt/16] = v0;
      //((uint64_t*)keyRecv)[keyCnt/16+1] = v1;
      //std::cout << "niga suck";

      if ( memcmp(keyArray[cnt], keyRecv, keylenArray[cnt]) == 0 ) {
        fprintf(stderr, "Main:: key parsing[%d] success\n", cnt++);
      }
      else {
        fprintf(stderr, "Main:: key parsing[%d] fail\n", cnt++);
        for ( int i = 0; i < keylenArray[cnt]; i++ ){
          fprintf(stderr, "Main:: sent_key[%d] = %02x,  recv_key[%d] = %02x\n", i, keyArray[cnt][i], i, keyRecv[i]);
        }
        exit(0);
      }
      delete keyRecv;
      keyCnt = 0;

    }
    else {
      uint64_t keys[2] = {v0, v1};
      memcpy(keyRecv + keyCnt, keys, 16);
      keyCnt+=16;
    }
  }  
  MemreadIndication(int id) : MemreadIndicationWrapper(id), cnt0(0), cnt(0), keyCnt(0){}
};

MemreadRequestProxy *device = 0;

static int running = 1;


int runtest(int argc, const char ** argv)
{

  int test_result = 0;
  int srcAlloc;
  unsigned int *srcBuffer = 0;

  MemreadIndication *deviceIndication = 0;

  fprintf(stderr, "Main::%s %s\n", __DATE__, __TIME__);

  device = new MemreadRequestProxy(IfcNames_MemreadRequest);
  deviceIndication = new MemreadIndication(IfcNames_MemreadIndication);
  MemServerRequestProxy *hostMemServerRequest = new MemServerRequestProxy(IfcNames_HostMemServerRequest);
  MMURequestProxy *dmap = new MMURequestProxy(IfcNames_HostMMURequest);
  DmaManager *dma = new DmaManager(dmap);
  MemServerIndication *hostMemServerIndication = new MemServerIndication(hostMemServerRequest, IfcNames_HostMemServerIndication);
  MMUIndication *hostMMUIndication = new MMUIndication(dma, IfcNames_HostMMUIndication);

  fprintf(stderr, "Main::allocating memory...\n");
  srcAlloc = portalAlloc(alloc_sz);
  srcBuffer = (unsigned int *)portalMmap(srcAlloc, alloc_sz);

  portalExec_start();

#ifdef FPGA0_CLOCK_FREQ
  long req_freq = FPGA0_CLOCK_FREQ;
  long freq = 0;
  setClockFrequency(0, req_freq, &freq);
  fprintf(stderr, "Requested FCLK[0]=%ld actually %ld\n", req_freq, freq);
#endif

  /* Test 1: check that match is ok */
  for (int i = 0; i < alloc_sz/4; i++){
    srcBuffer[i] = i;
  }
    
  portalDCacheFlushInval(srcAlloc, alloc_sz, srcBuffer);
  fprintf(stderr, "Main::flush and invalidate complete\n");

  unsigned int ref_srcAlloc = dma->reference(srcAlloc);
  fprintf(stderr, "ref_srcAlloc=%d\n", ref_srcAlloc);

  bool orig_test = true;

  int running_offset = 0;

  int numTests = 256;
  headerArray = new protocol_binary_request_header[numTests];
  keyArray = new char*[numTests];
  keylenArray = new int[numTests];

  int keylen;
  //std::cout << "keylen = ";
  //std::cin >> keylen;

  srand (time(NULL));
  //for ( keylen = 1; keylen <= 32; keylen++)
  //for ( int j = 0; j < 32; j++ ){
  for ( int i = 0; i < numTests; i++ ){
    //int i = (keylen-1)*32+j;
    keylen = rand()%256 + 1;
    keylenArray[i] = keylen;
    int vallen = 0;
    memset(headerArray+i, 0, sizeof(protocol_binary_request_header));
    headerArray[i].request.magic = PROTOCOL_BINARY_REQ;
    headerArray[i].request.opcode = PROTOCOL_BINARY_CMD_GET;
    headerArray[i].request.keylen = keylen;
    headerArray[i].request.bodylen = keylen + vallen;

    
    keyArray[i] = new char[keylen];
    for ( int j = 0; j < keylen; j++ ){
      keyArray[i][j] = rand();
    }
    
    memcpy((char*)srcBuffer + running_offset, headerArray+i, sizeof(protocol_binary_request_header));
    running_offset+=sizeof(protocol_binary_request_header);
    memcpy((char*)srcBuffer + running_offset, keyArray[i], keylen);
    running_offset+=keylen;
  }

  device->startRead(ref_srcAlloc, running_offset);
  
  while (true){sleep(1);}
}

#endif // _TESTMEMREAD_H_
