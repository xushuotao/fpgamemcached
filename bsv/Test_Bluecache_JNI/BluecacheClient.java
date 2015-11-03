import java.util.concurrent.*;

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
        return sendGet(key.getBytes(), threadid);
    }
    public boolean set(String key, String val){
        return sendSet(key.getBytes(), val.getBytes(), threadid);
    }
    public boolean delete(String key){
        return sendDelete(key.getBytes(), threadid);
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
