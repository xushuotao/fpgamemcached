import java.util.*;
import edu.mit.bluecache.*;


public class RequestThread extends Thread{
    private int threadId;

    private BluecacheClient client;

    private int [] keylenArray;// = new int[numTests];
    private int [] vallenArray;// = new int[numTests];
    private byte[][] keyArray;// = new byte[numTests][];
    private byte[][] valArray;// = new byte[numTests][];
    private boolean[] successArray;// = new boolean[numTests];

    private boolean doSet;
    private int numTests;

    public RequestThread(BluecacheClient client, int threadId,
                         int [] keylenArray,
                         int [] vallenArray,
                         byte[][] keyArray,
                         byte[][] valArray,
                         boolean[] successArray,
                         int numTests
                         ){
        this.threadId = threadId;
        this.client = client;
        
        this.doSet = true;
        this.keylenArray = keylenArray;
        this.vallenArray = vallenArray;
        this.keyArray = keyArray;
        this.valArray = valArray;
        this.successArray = successArray;

        this.numTests = numTests;
    }

    public void setParameters(boolean doSet){
        this.doSet = doSet;
    }

    public void run(){
        int pageSz = 8192;
        Random r = new Random();
        if ( doSet ) {
            // keylenArray = new int[numTests];
            // vallenArray = new int[numTests];
            // keyArray = new byte[numTests][];
            // valArray = new byte[numTests][];
            // successArray = new boolean[numTests];
            int fails = 0;
            
            for ( int i = 0; i < numTests; i++ ){
                int keylen = r.nextInt(255) + 1;
                //int keylen = 64;
                //int vallen = r.nextInt(8*pageSz-keylen-8)+1;//rand()%255+1;
                int vallen = pageSz-keylen-8;//rand()%255+1;
                //int vallen = 6*pageSz-keylen-8;//rand()%255+1;
    
                keylenArray[i] = keylen;
                vallenArray[i] = vallen;

                keyArray[i] = new byte[keylen];
                r.nextBytes(keyArray[i]);
    
                valArray[i] = new byte[vallen];
                r.nextBytes(valArray[i]);
    
                //successArray[i] = client.set(new String(keyArray[i]), new String(valArray[i]));
                //System.out.format("Client %d sends request for set\n", client.clientId());
                successArray[i] = client.set(keyArray[i], valArray[i]);
                //System.out.format("Client %d receives response for set\n", client.clientId());
                if ( !successArray[i] ) fails++;

            }
            //System.out.format("Client %d, set fails = %d\n", threadId, fails);
        } else {
            //System.out.println(keyArray.length);
            int fails = 0;
            double diff = 0;
            int maxsize = keyArray.length;
            for ( int i = 0; i < numTests; i++ ){
                //byte[] retval = client.get(new String(keyArray[i]));
                //System.out.format("Java:: Client %d sends request for get\n", client.clientId());
                int index = r.nextInt(maxsize);
                //long time_start = System.nanoTime();
                byte[] retval = client.get(keyArray[index]);
                //long time_end = System.nanoTime();
                //diff+=(time_end - time_start)/1e3;
                // try{
                //     Thread.sleep(100);
                // } catch (Exception e){
                //     e.printStackTrace(System.out);
                // }
                if ( retval == null ) fails++;
                if ( successArray[index] ) {
                    if ( Arrays.equals(retval, valArray[index])) {
                        //System.out.format("Client %d, get %d succeeds\n", threadId, i);
                        //System.exit(0);
                    } else {
                        System.out.format("Client %d, get %d fails\n", threadId, index);
                        // for ( int j = 0; j < keyArray.length; j++){
                        //     System.out.format("Retval[%d] = %x, keyArray[%d] = %x, match = %b\n", j, retval[j], j, keyArray[i][j], retval[j]==keyArray[i][j]);
                        // }
                    }
                }
            }


            //            System.out.format("Client %d, get fails = %d, avg_latency = %fus\n", threadId, fails, diff/numTests);
        }
    }
}

