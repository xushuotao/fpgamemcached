SRC_BSV=/home/shuotao/bluecache/bsv/
CONNECTALDIR?=~/tools/connectal_bluedbm/
INTERFACES = BluecacheRequest BluecacheIndication
BSVFILES = Bluecache.bsv Top.bsv
CPPFILES=testbluecache.cpp testbluecache.h

BSVDIR= $(SRC_BSV):$(SRC_BSV)/time:$(SRC_BSV)/hash:$(SRC_BSV)/hashtable_simple:$(SRC_BSV)/valuestr:$(SRC_BSV)/flashstr:$(SRC_BSV)/arbiter:$(SRC_BSV)/router:$(SRC_BSV)/../xilinx/aurora_8b10b_fmc1:$(SRC_BSV)/../xilinx/aurora_64b66b:$(SRC_BSV)/../controller/src:$(SRC_BSV)/../controller/src/common:$(SRC_BSV)/../controller/src/model_virtex:$(SRC_BSV)/../controller/src/hw_virtex:$(SRC_BSV)/../lib:$(SRC_BSV)/hardware_controller/dram_sim:$(SRC_BSV)/hardware_controller/dram/any_64

#DATA_BUS_WIDTH=128
#NUMBER_OF_MASTERS=1
CONNECTALFLAGS = --cflags " -I/usr/lib/jvm/java-1.7.0-openjdk-amd64/include/ -I/usr/lib/jvm/java-1.7.0-openjdk-amd64/include/linux" -D IMPORT_HOSTIF -D PinType=Top_Pins -D DataBusWidth=128 -D Debug --clib rt --bscflags " -p +:$(BSVDIR) -u +RTS -K10G -RTS -suppress-warnings G0024: -steps-max-intervals 200000 -D DataBusWidth=128 -D Debug -D NodeCountLog=2 -D RequestRouteType=4"

# -parallel-sim-link 16  


ifeq ($(BOARD), vc707)
CONNECTALFLAGS += --verilog /afs/csail.mit.edu/group/csg/tools_lx86/bluespec/current/lib/board_support/bluenoc/xilinx/VC707/verilog/ddr3_v2_0/ddr3_v2_0/user_design/rtl \
		--constraint ~/fpgamemcached/xilinx/constraints/clocks.xdc \
		--constraint ~/fpgamemcached/xilinx/constraints/vc707_ddr3_sx.xdc

CONNECTALFLAGS += \
		--verilog ../../xilinx/aurora_8b10b_fmc1/ \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1.xci \
	--constraint ../../xilinx/aurora_8b10b_fmc1/aurora_8b10b_fmc1_exdes.xdc \
	--verilog ../../xilinx/aurora_64b66b/ \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y24/aurora_64b66b_X1Y24.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y25/aurora_64b66b_X1Y25.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y26/aurora_64b66b_X1Y26.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y27/aurora_64b66b_X1Y27.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1.xci \
	-C ../../xilinx/aurora_64b66b/aurora_64b66b_exdes_119.xdc \

AURORA_INTRA = $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1_stub.v
prebuild:: $(AURORA_INTRA) $(AURORA_INTRA)

$(AURORA_INTRA): ../../core-scripts/synth-aurora-intra.tcl
	(cd $(BOARD); vivado -mode batch -source ../../../core-scripts/synth-aurora-intra.tcl)

$(AURORA_EXTRA): ../../core-scripts/synth-aurora-ext.tcl
	(cd $(BOARD); vivado -mode batch -source ../../../core-scripts/synth-aurora-ext.tcl)
	find $(CONNECTALDIR)/out/$(BOARD)/ -name "aurora_64b66b_X1Y??_wrapper.v" -exec sed -i "s/GT0_txdiffctrl_in[ \t]\+([4'b10]\+),/GT0_txdiffctrl_in (4'b1100),/g" '{}' \;
else
CONNECTALFLAGS += \
	--bsimsource ../../xilinx/aurora_64b66b/bdpi.cpp
endif



include $(CONNECTALDIR)/Makefile.connectal

