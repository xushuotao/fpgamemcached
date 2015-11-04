#include "BluecacheClient.h"
#include "bluecachedaemon.h"
#include <iostream>
#include <time.h>
#include <stdlib.h>
#include <stdio.h>

int num_Sets;
int num_Gets;
//int pageSz = 8192;

int ** keylenArray;
int ** vallenArray;
char*** keyArray;
char*** valArray;
bool** successArray;

BluecacheClient* clients;
void *set_request(void *ptr){

  //BluecacheClient* client = (BluecacheClient*)ptr;
  
  BluecacheClient client = clients[*(int*)ptr];
  int clientId = client.clientId();
  //fprintf(stderr, "Set Thread client = %d\n", clientId);
  srand(time(NULL));
  keylenArray[clientId] = new int[num_Sets];
  vallenArray[clientId] = new int[num_Sets];
  keyArray[clientId] = new char*[num_Sets];
  valArray[clientId] = new char*[num_Sets];
  successArray[clientId] = new bool[num_Sets];
  
  for ( int i = 0; i < num_Sets; i++ ){
    //int keylen = rand()%255 + 1;
    int keylen = 64;
    //int vallen = r.nextInt(8*pageSz-keylen-8)+1;//rand()%255+1;
    int vallen = pageSz-keylen-8;//rand()%255+1;
    //int vallen = 6*pageSz-keylen-8;//rand()%255+1;
    
    keylenArray[clientId][i] = keylen;
    vallenArray[clientId][i] = vallen;

    keyArray[clientId][i] = new char[keylen];

    for ( int j = 0; j < keylen; j++ ){
      keyArray[clientId][i][j] = rand();
    }
    
    valArray[clientId][i] = new char[vallen];
    for ( int j = 0; j < keylen; j++ ){
      valArray[clientId][i][j] = rand();
    }
    //fprintf(stderr, "YOU SUCK\n");
    successArray[clientId][i] = client.set(keyArray[clientId][i], valArray[clientId][i], keylenArray[clientId][i], vallenArray[clientId][i]);
    //if ( !successArray[i] ) fails++;
  }
}

void *get_request(void *ptr){
  //BluecacheClient* client = (BluecacheClient*)ptr;
  BluecacheClient client = clients[*(int*)ptr];
  int clientId = client.clientId();
  for ( int i = 0; i < num_Gets; i++ ){
    int j = rand()%num_Sets;
    size_t vallen;
    
    char* val = client.get(keyArray[clientId][j], keylenArray[clientId][j], &vallen);

    if ( successArray[clientId][j] ){
      if ( vallen != vallenArray[clientId][j] ){
        fprintf(stderr, "Client %d, get value len is not equal, FPGAvallen = %d, Hostvallen = %d\n", clientId, vallen, vallenArray[clientId][j]);
        continue;
      }
      if ( memcmp(val, valArray[clientId][j], vallen) > 0 ){
        fprintf(stderr, "Client %d, get value data is not equal\n", clientId);
        for(int k = 0; k < vallenArray[clientId][j]; k++){
          fprintf(stderr, "Main:: valrecv[%d] = %x, valArray[%d] = %x, match = %d\n", k, val[k], k, valArray[clientId][j][k], val[k]==valArray[clientId][j][k]); 
        }
      }
    }
    //if ( !successArray[i] ) fails++;
  }
}

int main(int argc, const char **argv){
  initBluecacheProxy();
  timespec start, now;
  int threadcount;
  std::cout << "Enter number of concurrent clients: ";
  std::cin >> threadcount;

  std::cout << "Enter number of set requests per threads: ";
  std::cin >> num_Sets;
  std::cout << "Enter number of get requests per threads: ";
  std::cin >> num_Gets;

  keylenArray = new int*[threadcount];
  vallenArray = new int*[threadcount];
  keyArray = new char**[threadcount];
  valArray = new char**[threadcount];
  successArray = new bool*[threadcount];

  clients = new BluecacheClient[threadcount];
  pthread_t* set_threads = new pthread_t[threadcount];
  int* threadids = new int[threadcount];
  clock_gettime(CLOCK_REALTIME, &start);
  for ( int i = 0; i < threadcount; i++ ){
    //fprintf(stderr,"creating threads i = %d\n", i);
    threadids[i] =i;
    pthread_create(set_threads+i, NULL, set_request, threadids+i);
  }

  for ( int i = 0; i < threadcount; i++ ){
    //fprintf(stderr,"joining threads i = %d\n", i);
    pthread_join(set_threads[i], NULL);
  }
  clock_gettime(CLOCK_REALTIME, &now);

  fprintf(stderr, "Main:: Set Test Successful, num_resps = %d\n", num_Sets*threadcount);
  fprintf(stderr, "Main:: Set Test Successful, %f MRPS\n", num_Sets*threadcount/(timespec_diff_sec(start, now)*1000000));
  sleep(1);


  pthread_t* get_threads = new pthread_t[threadcount];

  clock_gettime(CLOCK_REALTIME, &start);  
  for ( int i = 0; i < threadcount; i++ ){
    threadids[i] =i;
    pthread_create(get_threads+i, NULL, get_request, threadids+i);
  }

  for ( int i = 0; i < threadcount; i++ ){
    pthread_join(get_threads[i], NULL);
  }
  clock_gettime(CLOCK_REALTIME, & now);
  fprintf(stderr, "Main:: Get Test Successful, num_resps = %d\n", num_Gets*threadcount);
  fprintf(stderr, "Main:: Get Test Successful, %f MRPS\n", (num_Gets*threadcount)/(timespec_diff_sec(start, now)*1000000));
}
