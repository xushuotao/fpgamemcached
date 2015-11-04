SRC_BSV=/home/shuotao/fpgamemcached/bsv/
CONNECTALDIR?=~/tools/connectal_bluedbm/
INTERFACES = BluecacheRequest BluecacheIndication
BSVFILES = Bluecache.bsv Top.bsv
CPPFILES=TestBluecache.cpp BluecacheClient.cpp bluecachedaemon.cpp

BSVDIR= $(SRC_BSV):$(SRC_BSV)/time:$(SRC_BSV)/hash:$(SRC_BSV)/hashtable_simple:$(SRC_BSV)/valuestr:$(SRC_BSV)/flashstr:$(SRC_BSV)/arbiter:$(SRC_BSV)/../xilinx/aurora_8b10b_fmc1:$(SRC_BSV)/../controller/src:$(SRC_BSV)/../controller/src/common:$(SRC_BSV)/../controller/src/model_virtex:$(SRC_BSV)/../controller/src/hw_virtex:$(SRC_BSV)/../lib:$(SRC_BSV)/hardware_controller/dram_sim:$(SRC_BSV)/hardware_controller/dram/any_64

#DATA_BUS_WIDTH=128
#NUMBER_OF_MASTERS=1
CONNECTALFLAGS = --cflags " -I/usr/lib/jvm/java-1.7.0-openjdk-amd64/include/ -I/usr/lib/jvm/java-1.7.0-openjdk-amd64/include/linux" -D IMPORT_HOSTIF -D PinType=Top_Pins -D DataBusWidth=128 -D Debug --clib rt --bscflags " -p +:$(BSVDIR) -u -steps-max-intervals 200000 -D DataBusWidth=128 -D Debug"


ifeq ($(BOARD), vc707)
CONNECTALFLAGS += --verilog /afs/csail.mit.edu/group/csg/tools_lx86/bluespec/current/lib/board_support/bluenoc/xilinx/VC707/verilog/ddr3_v2_0/ddr3_v2_0/user_design/rtl \
		--constraint ~/fpgamemcached/xilinx/constraints/clocks.xdc \
		--constraint ~/fpgamemcached/xilinx/constraints/vc707_ddr3_sx.xdc

CONNECTALFLAGS += \
		--verilog ../../xilinx/aurora_8b10b_fmc1/ \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1.xci \
	--constraint ../../xilinx/aurora_8b10b_fmc1/aurora_8b10b_fmc1_exdes.xdc 

AURORA_INTRA = $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1_stub.v
prebuild:: $(AURORA_INTRA)

$(AURORA_INTRA): ../../core-scripts/synth-aurora-intra.tcl
	(cd $(BOARD); vivado -mode batch -source ../../../core-scripts/synth-aurora-intra.tcl)

endif


include $(CONNECTALDIR)/Makefile.connectal

