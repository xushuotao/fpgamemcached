SRC_BSV = ../bsv

S2H = ServerRequest
H2S = ServerIndication
BSVFILES = $(SRC_BSV)/packet/Packet.bsv \
	$(SRC_BSV)/MemcachedServer.bsv \
	$(SRC_BSV)/Proc.bsv \
	$(SRC_BSV)/DMAHelper.bsv \
	$(SRC_BSV)/ProtocolHeader.bsv \
	$(SRC_BSV)/hash/JenkinsHash.bsv \
	$(SRC_BSV)/time/Time.bsv \
	$(SRC_BSV)/hashtable/Hashtable.bsv \
	$(SRC_BSV)/valuestr/Valuestr.bsv \
	../fpga_dma/Top.bsv
CPPFILES = main.cpp
NUMBER_OF_MASTERS = 1

XBSV_DIR=~/tools/xbsv/

CONNECTALFLAGS =	--verilog /afs/csail.mit.edu/group/csg/tools_lx86/bluespec/current/lib/board_support/bluenoc/xilinx/VC707/verilog/ddr3_v2_0/ddr3_v2_0/user_design/rtl \
		--constraint $(XBSV_DIR)/xilinx/constraints/vc707_ddr3_sx.xdc \
		--clib rt \
		-D IMPORT_HOSTIF

ifeq ($(BOARD), bluesim)
BSVFILES += 	$(SRC_BSV)/hardware_controller/dram_sim/DDR3Sim.bsv \
		$(SRC_BSV)/hardware_controller/dram_sim/raw_64/DRAMController.bsv
else
BSVFILES +=	$(SRC_BSV)/hardware_controller/dram/raw_64/DRAMController.bsv
CONNECTALFLAGS += 	-D PinType=DDR3_Pins_VC707
endif

include ~/tools/xbsv/Makefile.connectal

