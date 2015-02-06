SRC_BSV = ../bsv

S2H = SimpleRequest
H2S = SimpleIndication
BSVFILES = MemEngineTG.bsv \
	../chipscope/IlaWrapper.bsv \
	Simple.bsv \
	$(SRC_BSV)/Proc.bsv \
	$(SRC_BSV)/DMAHelper.bsv \
	$(SRC_BSV)/ProtocolHeader.bsv \
	$(SRC_BSV)/hash/JenkinsHash.bsv \
	$(SRC_BSV)/time/Time.bsv \
	$(SRC_BSV)/arbiter/MyArbiter.bsv \
	$(SRC_BSV)/arbiter/DRAMArbiter.bsv \
	$(SRC_BSV)/arbiter/HtArbiter.bsv \
	$(SRC_BSV)/hashtable_optimized/Scoreboard.bsv \
	$(SRC_BSV)/hashtable_optimized/HeaderReader.bsv \
	$(SRC_BSV)/hashtable_optimized/KeyReader.bsv \
	$(SRC_BSV)/hashtable_optimized/HeaderWriter.bsv \
	$(SRC_BSV)/hashtable_optimized/KeyWriter.bsv \
	$(SRC_BSV)/hashtable_optimized/Hashtable.bsv \
	$(SRC_BSV)/valuestr/Valuestr.bsv \
	Top.bsv
CPPFILES = testsimple.cpp
NUMBER_OF_MASTERS = 0


XBSV_DIR=~/tools/xbsv/

CONNECTALFLAGS = --verilog /afs/csail.mit.edu/group/csg/tools_lx86/bluespec/current/lib/board_support/bluenoc/xilinx/VC707/verilog/ddr3_v2_0/ddr3_v2_0/user_design/rtl \
		--verilog /home/shuotao/fpgamemcached/chipscope/ila_dma_viv.v \
		--constraint $(XBSV_DIR)/xilinx/constraints/vc707_ddr3_sx.xdc \
		--clib rt \
		--xci ~/fpgamemcached/chipscope/ila_dma/ila_dma.xci \
		-D IMPORT_HOSTIF \
		-D PinType=Top_Pins

ifeq ($(BOARD), bluesim)
BSVFILES += 	$(SRC_BSV)/hardware_controller/dram_sim/DDR3Sim.bsv \
		$(SRC_BSV)/hardware_controller/dram_sim/raw_64/DRAMController.bsv
else
BSVFILES +=	$(SRC_BSV)/hardware_controller/dram/raw_64/DRAMController.bsv

endif

include ~/tools/xbsv/Makefile.connectal

