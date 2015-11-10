
CONNECTALDIR?=/home/chamdoo/bluedbm/tools/connectal
DTOP?=/home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT/vc707
export V=0
ifeq ($(V),0)
Q=@
else
Q=
endif

CFLAGS_COMMON = -O -g -I$(DTOP)/jni -I$(CONNECTALDIR) -I$(CONNECTALDIR)/cpp -I$(CONNECTALDIR)/lib/cpp -I/home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT -I/home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT -I/home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT -I/home/chamdoo/bluedbm/tools/connectal/cpp  -DIMPORT_HOSTIF -DPinType=Top_Pins -DDataBusWidth=128 -DDebug -DNumberOfMasters=1 -DPinType=Empty -DMainClockPeriod=8 -DDerivedClockPeriod=8 -Dproject_dir=$(DTOP) -DXILINX -DVirtex7 -DPCIE -DPcieHostTypeIF -DPhysAddrWidth=40 -DBOARD_vc707 -I/usr/lib/jvm/java-1.7.0-openjdk-amd64/include/ -I/usr/lib/jvm/java-1.7.0-openjdk-amd64/include/linux
CFLAGS = $(CFLAGS_COMMON)
CFLAGS2 = 

PORTAL_CPP_FILES = $(addprefix $(CONNECTALDIR)/cpp/, portal.c portalSocket.c poller.cpp sock_utils.c timer.c)
include $(DTOP)/jni/Makefile.generated_files
SOURCES = $(addprefix $(DTOP)/jni/,  $(GENERATED_CPP)) /home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT/TestBluecache.cpp /home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT/BluecacheClient.cpp /home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT/bluecachedaemon.cpp /home/chamdoo/bluedbm/tools/connectal/cpp/dmaManager.c $(PORTAL_CPP_FILES)
SOURCES2 = $(addprefix $(DTOP)/jni/,  $(GENERATED_CPP))  $(PORTAL_CPP_FILES)
LDLIBS :=  -lrt  -pthread 

BSIM_EXE_CXX_FILES = BsimDma.cxx BsimCtrl.cxx TlpReplay.cxx
BSIM_EXE_CXX = $(addprefix $(CONNECTALDIR)/cpp/, $(BSIM_EXE_CXX_FILES))

ubuntu.exe: $(SOURCES)
	$(Q)g++ $(CFLAGS) -o ubuntu.exe $(SOURCES) $(LDLIBS)

connectal.so: $(SOURCES)
	$(Q)g++ -shared -fpic $(CFLAGS) -o connectal.so  $(SOURCES) $(LDLIBS)

ubuntu.exe2: $(SOURCES2)
	$(Q)g++ $(CFLAGS) $(CFLAGS2) -o ubuntu.exe2 $(SOURCES2) $(LDLIBS)

bsim_exe: $(SOURCES)
	$(Q)g++ $(CFLAGS_COMMON) -o bsim_exe -DBSIM $(SOURCES) $(BSIM_EXE_CXX) $(LDLIBS)

bsim_exe2: $(SOURCES2)
	$(Q)g++ $(CFLAGS_COMMON) $(CFLAGS2) -o bsim_exe2 -DBSIM $(SOURCES2) $(BSIM_EXE_CXX) $(LDLIBS)
