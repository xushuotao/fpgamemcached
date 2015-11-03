#sudo chmod agu+rw /dev/fpga*
#./vc707/bin/ubuntu.exe 2>&1 | tee LOG
java -Djava.library.path=. TestBluecache
