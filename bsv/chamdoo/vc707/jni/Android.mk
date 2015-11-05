
include $(CLEAR_VARS)
DTOP?=/home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT/vc707
CONNECTALDIR?=/home/chamdoo/bluedbm/tools/connectal
LOCAL_ARM_MODE := arm
include $(DTOP)/jni/Makefile.generated_files
APP_SRC_FILES := $(addprefix $(DTOP)/jni/,  $(GENERATED_CPP)) /home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT/TestBluecache.cpp /home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT/BluecacheClient.cpp /home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT/bluecachedaemon.cpp /home/chamdoo/bluedbm/tools/connectal/cpp/dmaManager.c
PORTAL_SRC_FILES := $(addprefix $(CONNECTALDIR)/cpp/, portal.c portalSocket.c poller.cpp sock_utils.c timer.c)
LOCAL_SRC_FILES := $(APP_SRC_FILES) $(PORTAL_SRC_FILES)

LOCAL_PATH :=
LOCAL_MODULE := android.exe
LOCAL_MODULE_TAGS := optional
LOCAL_LDLIBS := -llog  -lrt 
LOCAL_CPPFLAGS := "-march=armv7-a"
LOCAL_CFLAGS := -DZYNQ -I$(DTOP)/jni -I$(CONNECTALDIR) -I$(CONNECTALDIR)/cpp -I$(CONNECTALDIR)/lib/cpp -I/home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT -I/home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT -I/home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT -I/home/chamdoo/bluedbm/tools/connectal/cpp  -DIMPORT_HOSTIF -DPinType=Top_Pins -DDataBusWidth=128 -DDebug -DNumberOfMasters=1 -DPinType=Empty -DMainClockPeriod=8 -DDerivedClockPeriod=8 -Dproject_dir=$(DTOP) -DXILINX -DVirtex7 -DPCIE -DPcieHostTypeIF -DPhysAddrWidth=40 -DBOARD_vc707 -I/usr/lib/jvm/java-1.7.0-openjdk-amd64/include/ -I/usr/lib/jvm/java-1.7.0-openjdk-amd64/include/linux
LOCAL_CXXFLAGS := -DZYNQ -I$(DTOP)/jni -I$(CONNECTALDIR) -I$(CONNECTALDIR)/cpp -I$(CONNECTALDIR)/lib/cpp -I/home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT -I/home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT -I/home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT -I/home/chamdoo/bluedbm/tools/connectal/cpp  -DIMPORT_HOSTIF -DPinType=Top_Pins -DDataBusWidth=128 -DDebug -DNumberOfMasters=1 -DPinType=Empty -DMainClockPeriod=8 -DDerivedClockPeriod=8 -Dproject_dir=$(DTOP) -DXILINX -DVirtex7 -DPCIE -DPcieHostTypeIF -DPhysAddrWidth=40 -DBOARD_vc707 -I/usr/lib/jvm/java-1.7.0-openjdk-amd64/include/ -I/usr/lib/jvm/java-1.7.0-openjdk-amd64/include/linux
LOCAL_CFLAGS2 := $(cdefines2)s

include $(BUILD_EXECUTABLE)
