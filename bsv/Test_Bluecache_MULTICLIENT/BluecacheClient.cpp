#include "BluecacheClient.h"

#include "bluecachedaemon.h"

#include <stdio.h>


BluecacheClient::BluecacheClient(){
  threadId = initMainThread();
}

BluecacheClient::~BluecacheClient(){
}

int BluecacheClient::clientId(){
  return threadId;
}
    
char* BluecacheClient::get(char* key, size_t keylen, size_t* vallen){
  unsigned char* retval = NULL;
  sendGet(key, keylen, threadId, &retval, vallen);
  return (char*)retval;
}

bool BluecacheClient::set(char* key, char* val, size_t keylen, size_t vallen){
  bool retval;
  sendSet(key, val, keylen, vallen, threadId, &retval);
  //fprintf(stderr, "Set returns from testbluecachecpp\n");
  return retval;
}
                                
bool BluecacheClient::del(char* key, size_t keylen){
  bool retval;
  sendDelete(key, keylen, threadId, &retval);
  return retval;
}
