SRC_BSV = ../../

S2H = SimpleRequest
H2S = SimpleIndication

BSVFILES = Simple.bsv \
	../../time/Time.bsv \
	$(SRC_BSV)/arbiter/MyArbiter.bsv \
	$(SRC_BSV)/arbiter/DRAMArbiter.bsv \
	../ValFlashCtrl.bsv \
	../../valuestr/ValDRAMCtrl.bsv \
	Top.bsv \
	../../../xilinx/aurora_8b10b_fmc1/AuroraImportFmc1.bsv \
	../../../controller/src/common/FlashBusModel.bsv \
	../../../controller/src/model_virtex/FlashCtrlModel.bsv \
	../../../controller/src/hw_virtex/FlashCtrlVirtex.bsv \
	../../../lib/AuroraCommon.bsv

CPPFILES = testsimple.cpp
NUMBER_OF_MASTERS = 0

CONNECTALDIR=~/tools/xbsv/

CONNECTALFLAGS = --verilog /afs/csail.mit.edu/group/csg/tools_lx86/bluespec/current/lib/board_support/bluenoc/xilinx/VC707/verilog/ddr3_v2_0/ddr3_v2_0/user_design/rtl \
		--clib rt \
		-D IMPORT_HOSTIF \
		-D PinType=Top_Pins \
		--bscflags " -steps-max-intervals 200000 "

ifeq ($(BOARD), bluesim)
BSVFILES += 	$(SRC_BSV)/hardware_controller/dram_sim/DDR3Sim.bsv \
		$(SRC_BSV)/hardware_controller/dram_sim/any_64/DRAMController.bsv
else
BSVFILES +=	$(SRC_BSV)/hardware_controller/dram/any_64/DRAMController.bsv
endif

include $(CONNECTALDIR)/Makefile.connectal

