/* DO NOT EDIT THIS FILE - it is machine generated */
#include <jni.h>
/* Header for class BluecacheClient */

#ifndef _Included_BluecacheClient
#define _Included_BluecacheClient
#ifdef __cplusplus
extern "C" {
#endif
/*
 * Class:     BluecacheClient
 * Method:    initBluecache
 * Signature: ()I
 */
JNIEXPORT jint JNICALL Java_BluecacheClient_initBluecache
  (JNIEnv *, jobject);

/*
 * Class:     BluecacheClient
 * Method:    sendSet
 * Signature: ([B[BI)Z
 */
JNIEXPORT jboolean JNICALL Java_BluecacheClient_sendSet
  (JNIEnv *, jobject, jbyteArray, jbyteArray, jint);

/*
 * Class:     BluecacheClient
 * Method:    sendGet
 * Signature: ([BI)[B
 */
JNIEXPORT jbyteArray JNICALL Java_BluecacheClient_sendGet
  (JNIEnv *, jobject, jbyteArray, jint);

/*
 * Class:     BluecacheClient
 * Method:    sendDelete
 * Signature: ([BI)Z
 */
JNIEXPORT jboolean JNICALL Java_BluecacheClient_sendDelete
  (JNIEnv *, jobject, jbyteArray, jint);

/*
 * Class:     BluecacheClient
 * Method:    getGetAvgLatency
 * Signature: ()D
 */
JNIEXPORT jdouble JNICALL Java_BluecacheClient_getGetAvgLatency
  (JNIEnv *, jobject);

#ifdef __cplusplus
}
#endif
#endif