#sudo chmod agu+rw /dev/fpga*
#./vc707/bin/ubuntu.exe 2>&1 | tee LOG
java -cp .:BluecacheClient.jar -Djava.library.path=. TestBluecache
#java -cp .:BluecacheClient.jar TestBluecache
