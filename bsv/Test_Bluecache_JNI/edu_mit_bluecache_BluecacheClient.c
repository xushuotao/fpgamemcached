#include <jni.h>
#include "edu_mit_bluecache_BluecacheClient.h"
#include "bluecachedaemon.h"

//sem_t* mutex;
int threadCnt = 0;


JNIEXPORT jint JNICALL Java_edu_mit_bluecache_BluecacheClient_initBluecache(JNIEnv *env, jobject obj){
  if ( threadCnt == 0 )
    initBluecacheProxy();
  threadCnt++;
  return initMainThread();
}

int reqCnt = 0;
JNIEXPORT jboolean JNICALL Java_edu_mit_bluecache_BluecacheClient_sendSet(JNIEnv *env, jobject obj, jbyteArray key, jbyteArray val, jint threadId){
  int keylen = env->GetArrayLength(key);
  /* unsigned char* keybuf = new unsigned char[keylen]; */
  /* env->GetByteArrayRegion(key, 0, keylen, reinterpret_cast<jbyte*>(keybuf)); */
  jbyte *keybuf = env->GetByteArrayElements(key,0);  

  int vallen = env->GetArrayLength(val);
  /* unsigned char* valbuf = new unsigned char[vallen]; */
  /* env->GetByteArrayRegion(val, 0, vallen, reinterpret_cast<jbyte*>(valbuf)); */
  jbyte *valbuf = env->GetByteArrayElements(val,0);

  bool retval;
  //fprintf(stderr,"JNI:: sendSet request to main thread, threadId = %d, reqCnt = %d\n", threadId, reqCnt++);
  sendSet((unsigned char*)keybuf, (unsigned char*)valbuf, keylen, vallen, threadId, &retval);

  env->ReleaseByteArrayElements(key, keybuf, JNI_ABORT);
  env->ReleaseByteArrayElements(val, valbuf, JNI_ABORT);
  /* delete(keybuf); */
  /* delete(valbuf); */

  //sem_wait(&(mutex[threadId]));
  return retval;
}

JNIEXPORT jbyteArray JNICALL Java_edu_mit_bluecache_BluecacheClient_sendGet(JNIEnv *env, jobject obj, jbyteArray key, jint threadId){ 
  int keylen = env->GetArrayLength(key);
  /* unsigned char* keybuf = new unsigned char[keylen]; */
  /* env->GetByteArrayRegion(key, 0, keylen, reinterpret_cast<jbyte*>(keybuf)); */
  jbyte *keybuf = env->GetByteArrayElements(key,0);
  if ( keybuf == NULL ) {
    fprintf(stderr,"getbytearray fails\n");
    return NULL;
  }
  
  unsigned char* valbuf = NULL;
  size_t vallen = 0;
  //fprintf(stderr,"JNIWrapper:: sendGet request to main thread, clientId = %d\n", threadId);
  /* jclass threadClass = env->FindClass("java/lang/Thread"); */
  /* jmethodID yieldFunctionID = env->GetStaticMethodID(threadClass, "yield", "()V"); */

  /* env->CallStaticVoidMethod(threadClass, yieldFunctionID); */
  sendGet((unsigned char*)keybuf, keylen, threadId, &valbuf, &vallen);
  
  //delete(keybuf);
  //env->ReleaseByteArrayElements(key, keybuf, JNI_ABORT);
  //fprintf(stderr, "Main:: sendGet responds, vallen = %d\n", vallen);
  if ( valbuf != NULL ) {
    jbyteArray array = env->NewByteArray(vallen);
    env->SetByteArrayRegion(array, 0, vallen, reinterpret_cast<jbyte*>(valbuf));
    delete valbuf;
    return array;
  }
  else 
    return NULL;
}

JNIEXPORT jboolean JNICALL Java_edu_mit_bluecache_BluecacheClient_sendDelete(JNIEnv *env, jobject obj, jbyteArray key, jint threadId){
  int keylen = env->GetArrayLength(key);
  unsigned char* keybuf = new unsigned char[keylen];
  env->GetByteArrayRegion(key, 0, keylen, reinterpret_cast<jbyte*>(keybuf));

  //sendDelete(keybuf, keylen, 0);
  bool retval;
  sendDelete(keybuf, keylen, threadId, &retval);
  delete(keybuf);
  //sem_wait(&(mutex[threadId]));
  return retval;

}

JNIEXPORT jdouble JNICALL Java_edu_mit_bluecache_BluecacheClient_getGetAvgLatency(JNIEnv *env, jobject obj){
  fprintf(stderr, "Average Get Latency = %lf, average send Latency = %lf, average wait Latency = %lf\n", avgLatency, avgSendLatency, avgLatency-avgSendLatency);
  fprintf(stderr, "Type 0 flush = %d\n", flush_type_0);
  fprintf(stderr, "Type 1 flush = %d\n", flush_type_1);
  return avgLatency;
}


