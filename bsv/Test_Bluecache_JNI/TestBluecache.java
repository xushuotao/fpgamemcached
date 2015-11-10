import java.util.*;
import edu.mit.bluecache.*;


public class TestBluecache {


    public static void main(String [] args){

        Vector<RequestThread> threads = new Vector<RequestThread>();
        Vector<BluecacheClient> clients = new Vector<BluecacheClient>();

        Scanner in = new Scanner(System.in);

        System.out.format("Enter number of concurrent request threads: ");
        int threadcount = in.nextInt();
        System.out.format("Enter number of sets per threads: ");
        int numTests = in.nextInt();
        System.out.format("Enter number of gets per threads: ");
        int numGets = in.nextInt();

        
        int [][] keylenArray = new int[threadcount][];
        int [][] vallenArray = new int[threadcount][];
        byte[][][] keyArray = new byte[threadcount][][];
        byte[][][] valArray = new byte[threadcount][][];
        boolean[][] successArray = new boolean[threadcount][];

        for ( int i = 0; i < threadcount; i++ ){
            keylenArray[i] = new int[numTests];
            vallenArray[i] = new int[numTests];
            keyArray[i] = new byte[numTests][];
            valArray[i] = new byte[numTests][];
            successArray[i] = new boolean[numTests];

            BluecacheClient client = new BluecacheClient();
            RequestThread clientThread = new RequestThread(client, i,
                                                           keylenArray[i],
                                                           vallenArray[i],
                                                           keyArray[i],
                                                           valArray[i],
                                                           successArray[i],
                                                           numTests);
            threads.add(clientThread);
            clients.add(client);
        }
        
        long start_time = System.nanoTime();
        for (RequestThread thread: threads) {
            thread.start();
        }
        for (RequestThread thread: threads) {
            try {
                thread.join();
            } catch (Exception e) {
                e.printStackTrace(System.out);
            }
        }
        long end_time = System.nanoTime();
        double diff = (end_time - start_time)/1e3;

        System.out.format("Bluecache number of sets = %d, performed within %f\n", numTests*threadcount, diff);
        System.out.format("Bluecache Statistics: Sets %f MRPS\n", (double)(numTests*threadcount)/diff);
        //clients.get(0).avgGetLatency();

        try {
            Thread.sleep(1000);
        } catch (Exception ex){
            ex.printStackTrace(System.out);
        }


        Vector<RequestThread> getthreads = new Vector<RequestThread>();
        for ( int i = 0; i < threadcount; i++ ){
            RequestThread clientThread = new RequestThread(clients.get(i), i,
                                                           keylenArray[i],
                                                           vallenArray[i],
                                                           keyArray[i],
                                                           valArray[i],
                                                           successArray[i],
                                                           numGets);
            getthreads.add(clientThread);
        }


        for (RequestThread thread: getthreads) {
            thread.setParameters(false);
        }

        start_time = System.nanoTime();
        for (RequestThread thread: getthreads) {
            thread.start();
        }
        for (RequestThread thread: getthreads) {
            try {
                thread.join();
            } catch (Exception e) {
                e.printStackTrace(System.out);
            }
        }
        end_time = System.nanoTime();
        diff = (end_time - start_time)/1e3;
        System.out.format("Bluecache number of gets = %d, performed within %f\n", numGets*threadcount, diff);
        System.out.format("Bluecache Statistics: Gets %f MRPS\n", (double)(numGets*threadcount)/diff);

        //System.out.format("Average c Get latency = %f\n", clients.get(0).avgGetLatency());
    }
}
