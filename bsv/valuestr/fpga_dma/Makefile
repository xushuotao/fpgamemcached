SRC_BSV = ~/fpgamemcached/bsv
SRC_CPP = ../host

S2H = SimpleRequest
H2S = SimpleIndication
BSVFILES = 	~/fpgamemcached/chipscope/ChipscopeWrapper.bsv \
		../../time/Time.bsv ../Valuestr.bsv Simple.bsv Top.bsv
CPPFILES = testsimple.cpp


XBSV_DIR=~/tools/xbsv/

XBSVFLAGS =	--verilog /afs/csail.mit.edu/group/csg/tools_lx86/bluespec/current/lib/board_support/bluenoc/xilinx/VC707/verilog/ddr3_v2_0/ddr3_v2_0/user_design/rtl \
		--constraint $(SRC_BSV)/hardware_controller/dram/vc707_ddr3_sx.xdc \
		--clib rt \
		--xci ~/workspace/chipscope/ila_0/ila_0.xci \
		-v \
		-D IMPORT_HOSTIF

ifeq ($(BOARD), bluesim)
BSVFILES += 	$(SRC_BSV)/hardware_controller/dram_sim/DDR3Sim.bsv \
		$(SRC_BSV)/hardware_controller/dram_sim/raw_64/DRAMController.bsv
else
BSVFILES +=	$(SRC_BSV)/hardware_controller/dram/raw_64/DRAMController.bsv
XBSVFLAGS += 	-D PinType=DDR3_Pins_VC707
endif


include ~/tools/xbsv/Makefile.xbsv

