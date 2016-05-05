
S2H = SimpleRequest
H2S = SimpleIndication
DRAMDIR = ../../hardware_controller/dram_sim
BSVFILES =   	Top.bsv Simple.bsv ../../time/Time.bsv ../ValDRAMCtrlPipeL.bsv  \
		../../Proc_128.bsv \
		../../flashstr/ValFlashCtrl.bsv \
		../../../controller/src/common/FlashBusModel.bsv \
		../../../xilinx/aurora_8b10b_fmc1/AuroraImportFmc1.bsv \
		../../hashtable_simple/Hashtable.bsv \
		../../arbiter/DRAMArbiter.bsv \
		../../../lib/Shifter.bsv \
		$(DRAMDIR)/DDR3Sim.bsv $(DRAMDIR)/../dram/any_64/DRAMController.bsv
CPPFILES = testsimple.cpp
NUMBER_OF_MASTERS = 0

CONNECTALDIR=/home/shuotao/fpgamemcached/xbsv

include ~/tools/xbsv/Makefile.connectal

