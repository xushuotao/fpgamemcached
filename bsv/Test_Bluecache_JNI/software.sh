rm vc707/jni/connectal.so;
rm *.class;
javac -cp .:BluecacheClient.jar TestBluecache.java;
cd vc707/;
make connectal.so;
cp bin/connectal.so ../libconnectal.so;
cd ..;
