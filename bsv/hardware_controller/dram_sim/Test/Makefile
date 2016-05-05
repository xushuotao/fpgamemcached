
S2H = SimpleRequest
H2S = SimpleIndication
DRAMDIR = ..
BSVFILES = Top.bsv Simple.bsv ~/fpgamemcached/lib/Shifter.bsv\
	$(DRAMDIR)/DDR3Sim.bsv $(DRAMDIR)/any_64/DRAMController.bsv
CPPFILES = testsimple.cpp
NUMBER_OF_MASTERS = 0

CONNECTALDIR=/home/shuotao/fpgamemcached/xbsv

include ~/tools/xbsv/Makefile.connectal
