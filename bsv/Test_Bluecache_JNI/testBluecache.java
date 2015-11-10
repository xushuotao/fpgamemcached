//import BluecacheClient;

public TestBluecache {
    public static void main(String [] args){
        BluecacheClient client;
        client.set("Murali", "suck");
        byte[] result = client.get("Murali");
        if ( result != null)
            System.out.println(new String(result));
    }
}
