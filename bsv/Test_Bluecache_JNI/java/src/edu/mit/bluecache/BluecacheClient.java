//package Bluecache;
package edu.mit.bluecache;

import java.util.concurrent.*;
import java.nio.charset.*;

public class BluecacheClient {
    static {
        System.loadLibrary("connectal");
    }

    private native int initBluecache();
    private native boolean sendSet(byte[] key, byte[] val, int id);
    private native byte[] sendGet(byte[] key, int id);
    private native boolean sendDelete(byte[] key, int id);
    private native double getGetAvgLatency();
    
    private static Semaphore mutex = new Semaphore(1);
    private int threadid;
    public BluecacheClient(){
        try {
            mutex.acquire();
            try {
                // do something
                threadid = initBluecache();
            } finally {
                mutex.release();
            }
        } catch (InterruptedException ie) {
            ie.printStackTrace(System.out);
        }
    }

    public int clientId(){
        return threadid;
    }
    
    public byte[] get(String key){
        //System.out.println("you suck");
        //System.out.println(key.getBytes(StandardCharsets.US_ASCII));
        return sendGet(key.getBytes(StandardCharsets.US_ASCII), threadid);
    }
    public boolean set(String key, byte[] val){
        return sendSet(key.getBytes(StandardCharsets.US_ASCII), val, threadid);
    }
    public boolean delete(String key){
        return sendDelete(key.getBytes(StandardCharsets.US_ASCII), threadid);
    }

    public byte[] get(byte[] key){
        return sendGet(key, threadid);
    }
    public boolean set(byte[] key, byte[] val){
        return sendSet(key, val, threadid);
    }
    public boolean delete(byte[] key){
        return sendDelete(key, threadid);
    }
    
    public double avgGetLatency(){
        return getGetAvgLatency();
    }

}
