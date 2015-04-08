
S2H = SimpleRequest
H2S = SimpleIndication
DRAMDIR = ../../hardware_controller/dram_sim
BSVFILES =   	Top.bsv Simple.bsv ../../time/Time.bsv ../ValDRAMCtrlPipeL.bsv  \
		../../arbiter/DRAMArbiter.bsv \
		../../../lib/Shifter.bsv \
		$(DRAMDIR)/DDR3Sim.bsv $(DRAMDIR)/any_64/DRAMController.bsv
CPPFILES = testsimple.cpp
NUMBER_OF_MASTERS = 0

CONNECTALDIR=/home/shuotao/fpgamemcached/xbsv

include ~/tools/xbsv/Makefile.connectal

