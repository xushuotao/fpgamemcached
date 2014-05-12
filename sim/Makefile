SRC_BSV = ../bsv
SRC_CPP = ../host

S2H = ServerRequest
H2S = ServerIndication
BSVFILES = $(SRC_BSV)/MemcachedServer.bsv \
	$(SRC_BSV)/hardware_controller/dram_sim/DDR3Sim.bsv \
	$(SRC_BSV)/hardware_controller/dram_sim/unaligned_naive/DRAMController.bsv \
	Top.bsv
CPPFILES = $(SRC_CPP)/MemcachedClient.cpp $(SRC_CPP)/testapp.cpp 
Dma = 
PINS = Std


XBSVDIR=../xbsv
BOARD=bluesim
TOP=$(XBSVDIR)/bsv/BsimTop
MKTOP=mkBsimTop


build:
	$(XBSVDIR)/genxpsprojfrombsv -B$(BOARD) -p $(BOARD) -x $(MKTOP) \
	$(foreach s2h, $(S2H), -s2h $(s2h)) \
	$(foreach h2s, $(H2S), -h2s $(h2s)) \
	$(foreach f, $(CPPFILES), -s $f) \
	-t $(TOP).bsv $(XBSVFLAGS) $(BSVFILES)

