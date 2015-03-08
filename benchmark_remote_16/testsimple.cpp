
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <math.h>
#include <iostream>
#include <string.h>

#include "SimpleIndicationWrapper.h"
#include "SimpleRequestProxy.h"
#include "GeneratedTypes.h"

int numTests;

class SimpleIndication : public SimpleIndicationWrapper
{  
public:
  virtual void finish(uint64_t v, uint64_t v2, uint32_t hits, uint32_t hits2) {
    fprintf(stderr, "FPGA finishes Sets in %lld cycles, success rate %lf(%d/%d), %lf Mrps.\n", v, (double)hits/(double)numTests, hits, numTests,(double)numTests/((double)v / 125));
    fprintf(stderr, "FPGA finishes Gets in %lld cycles, success rate %lf(%d/%d), %lf Mrps.\n", v2, (double)hits2/(double)numTests, hits2, numTests, (double)numTests/((double)v2 / 125));
    sleep(1);
    exit(0);
  }
  SimpleIndication(unsigned int id) : SimpleIndicationWrapper(id){}
};

SimpleIndication *indication = 0;
SimpleRequestProxy *device = 0;


void init_memcached(int size1, int size2, int size3, int addr0, int addr1, int addr2, int addr3){
  /*  int size1 = 32;
  int size2 = 64;
  int size3 = 128;
  int addr0 = 1 << 25;
  int addr1 = 1 << 26;
  int addr2 = 1 << 27;
  int addr3 = 1 << 29;*/

  int numHLines = addr0/((16+256)*4);
  int lgHLines = (int)log2((double)numHLines);
  
  addr0 = (1 << lgHLines) * ((16+256)*4);
  int lgSz1 = (int)log2((double)size1);
  int lgSz2 = (int)log2((double)size2);
  int lgSz3 = (int)log2((double)size3);

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
  addr1 = addr0 + randMax1*size1;

  delta = addr2 - addr1;
  numSlots = delta/size2;
  lgNumSlots = (int)log2((double)numSlots);
  randMax1 = (1 << lgNumSlots) - 1;
  addr2 = addr1 + randMax2*size1;
  
  delta = addr3 - addr2;
  numSlots = delta/size3;
  lgNumSlots = (int)log2((double)numSlots);
  randMax1 = (1 << lgNumSlots) - 1;
  addr3 = addr2 + randMax3*size1;
  
  /*

  int lgAddr1 = (int)log2((double)addr1);
  int lgAddr2 = (int)log2((double)addr2);
  int lgAddr3 = (int)log2((double)addr3);

  if ( lgAddr2 <= lgAddr1 ) lgAddr2 = lgAddr1+1;
  if ( lgAddr3 <= lgAddr2 ) lgAddr3 = lgAddr2+1;
  */
  device->initTable(lgHLines);
  device->initValDelimit(randMax1, randMax2, randMax3, lgSz1, lgSz2, lgSz3);
  device->initAddrDelimit(addr1, addr2, addr3);
}

void setAuroraRouting2(int myid, int src, int dst, int port1, int port2) {
  if ( myid != src ) return;

  for ( int i = 0; i < 8; i ++ ) {
    if ( i % 2 == 0 ) { 
      device->setAuroraExtRoutingTable(dst,port1, i);
    } else {
      device->setAuroraExtRoutingTable(dst,port2, i);
    }
  }
}

void auroraifc_start(int myid) {
  device->setNetId(myid);
  
  //This is not strictly required
  for ( int i = 0; i < 8; i++ ) 
    device->setAuroraExtRoutingTable(myid,0,i);

  for ( int i = 0; i < 10; i++ ) {
    if ( myid > i ) {
      setAuroraRouting2(myid, myid, i, 2,3);
    } else {
      setAuroraRouting2(myid,myid, i, 0,1);
    }
  }
  /*  
  // This is set up such that all nodes can one day 
  // read the same routing file and apply it
  //setAuroraRouting2(myid, 0,1, 0,1);
  setAuroraRouting2(myid, 0,1, 0,0);
  setAuroraRouting2(myid, 0,2, 2,3);
  //setAuroraRouting2(myid, 0,3, 2,3);
  setAuroraRouting2(myid, 0,3, 3,3);
  
  setAuroraRouting2(myid, 1,0, 0,0);
  //setAuroraRouting2(myid, 1,0, 0,1);
  setAuroraRouting2(myid, 1,2, 0,1);
  setAuroraRouting2(myid, 1,3, 0,1);
  
  setAuroraRouting2(myid, 2,0, 0,3);
  setAuroraRouting2(myid, 2,1, 0,3);
  setAuroraRouting2(myid, 2,3, 0,3);
  
  setAuroraRouting2(myid, 3,0, 1,2);
  setAuroraRouting2(myid, 3,1, 1,2);
  setAuroraRouting2(myid, 3,2, 0,3);
  */  
  usleep(100);
}

int main(int argc, const char **argv)
{

  char hostname[32];
  gethostname(hostname,32);
  
  //FIXME "lightning" is evaluated to 0,
  // so when bdbm00 is returned to the cluster,
  // code needs to be modified
  if ( strstr(hostname, "bdbm") == NULL 
       && strstr(hostname, "umma") == NULL
       && strstr(hostname, "lightning") == NULL ) {
    
    fprintf(stderr, "ERROR: hostname should be bdbm[idx] or lightning\n");
    return 1;
  }

  int myid = atoi(hostname+strlen("bdbm"));

  indication = new SimpleIndication(IfcNames_SimpleIndication);
  device = new SimpleRequestProxy(IfcNames_SimpleRequest);

  portalExec_start();

  std::cout << "Input Node number: ";
  std::cin >> myid;
  
  init_memcached(32,64,128, 1 << 25, 1 << 26, 1 << 27, 1 << 29);
  printf( "initializing aurora with node id %d\n", myid ); fflush(stdout);
  auroraifc_start(myid);

  //int numTests;
  std::cout << "Input Number of Tests: ";
  std::cin >> numTests;
  //device->start(numTests);
  device->start(numTests, numTests*16);
  
  fprintf(stderr, "Main::about to go to sleep\n");
  while(true){sleep(2);}
}
