SRC_BSV=/home/shuotao/fpgamemcached/bsv/
MIGDIR = /home/shuotao/fpgamemcached/xilinx/ddr3_v2_0
CONNECTALDIR?=~/tools/connectal_bluedbm/
INTERFACES = BluecacheRequest BluecacheIndication
BSVFILES = Bluecache.bsv Top.bsv
CPPFILES=testbluecache.cpp testbluecache.h

BSVDIR= $(SRC_BSV):$(SRC_BSV)/time:$(SRC_BSV)/hash:$(SRC_BSV)/hashtable_simple:$(SRC_BSV)/valuestr:$(SRC_BSV)/flashstr:$(SRC_BSV)/arbiter:$(SRC_BSV)/../xilinx/aurora_8b10b_fmc1:$(SRC_BSV)/../controller/src:$(SRC_BSV)/../controller/src/common:$(SRC_BSV)/../controller/src/model_virtex:$(SRC_BSV)/../controller/src/hw_virtex:$(SRC_BSV)/../lib:$(SRC_BSV)/hardware_controller/dram_test/any_64:$(MIGDIR)

#DATA_BUS_WIDTH=128
#NUMBER_OF_MASTERS=1
CONNECTALFLAGS = -D IMPORT_HOSTIF -D PinType=Top_Pins -D DataBusWidth=128 -D Debug --clib rt --bscflags " -p +:$(BSVDIR) -u -steps-max-intervals 200000 -D DataBusWidth=128 -D Debug"


ifeq ($(BOARD), vc707)
CONNECTALFLAGS += --constraint ~/fpgamemcached/xilinx/constraints/clocks.xdc \

CONNECTALFLAGS += \
		--verilog ../../xilinx/aurora_8b10b_fmc1/ \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1.xci \
	--constraint ../../xilinx/aurora_8b10b_fmc1/aurora_8b10b_fmc1_exdes.xdc

CONNECTALFLAGS +=	--verilog $(MIGDIR)/ddr3_wrapper.v \
			--xci $(CONNECTALDIR)/out/$(BOARD)/ddr3_v2_0/ddr3_v2_0.xci \
			--xci ~/workspace/chipscope/ila_ddr/ila_ddr.xci \
			--constraint $(MIGDIR)/ddr3_v2_0.xdc

AURORA_INTRA = $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1_stub.v

DDR3_V = $(CONNECTALDIR)/out/$(BOARD)/ddr3_v2_0/ddr3_v2_0_stub.v

prebuild:: $(AURORA_INTRA) $(DDR3_V)

$(AURORA_INTRA): ../../core-scripts/synth-aurora-intra.tcl
	(cd $(BOARD); vivado -mode batch -source ../../../core-scripts/synth-aurora-intra.tcl)

$(DDR3_V): $(MIGDIR)/synth-ip.tcl
	(cd $(BOARD); vivado -mode batch -source $(MIGDIR)/synth-ip.tcl)

endif


include $(CONNECTALDIR)/Makefile.connectal

