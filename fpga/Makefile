#include ../config/Makefile.list

SRC_BSV = ../bsv
SRC_CPP = ../host

S2H = ServerRequest
H2S = ServerIndication
BSVFILES = $(SRC_BSV)/MemcachedServer.bsv \
	$(SRC_BSV)/ProtocolHeader.bsv \
	$(SRC_BSV)/hardware_controller/dram/raw_64/DRAMController.bsv \
	$(SRC_BSV)/hash/JenkinsHash.bsv \
	$(SRC_BSV)/time/Time.bsv \
	$(SRC_BSV)/hashtable/Hashtable.bsv \
	$(SRC_BSV)/valuestr/Valuestr.bsv \
	Top.bsv
CPPFILES = $(SRC_CPP)/MemcachedClient.cpp $(SRC_CPP)/testapp.cpp 

#BSVFILES = Interface.bsv Top.bsv
#CPPFILES=main.cpp rawWordManager.cpp
Dma = DmaF
PINS = Std

#include ../config/Makefile.flashemul

XBSVDIR=~/fpgamemcached/xbsv
BOARD=vc707
TOP=$(PINS)Pcie$(Dma)Top
MKTOP=mkPcieTop

XBSVFLAGS =	--verilog $(XBSVDIR)/xilinx/ddr3_v1_7 \
		--constraint $(XBSVDIR)/xilinx/constraints/vc707_ddr3.xdc \
		--clib rt

build:
	$(XBSVDIR)/genxpsprojfrombsv -B$(BOARD) -p $(BOARD) -x $(MKTOP) \
	$(foreach s2h, $(S2H), -s2h $(s2h)) \
	$(foreach h2s, $(H2S), -h2s $(h2s)) \
	$(foreach f, $(CPPFILES_ALL), -s $f) \
	-t $(TOP).bsv $(XBSVFLAGS) $(BSVFILES)

