SRC_BSV=/home/shuotao/fpgamemcached/bsv/

S2H = SimpleRequest
H2S = SimpleIndication
DRAMDIR = ../../hardware_controller/dram_sim
BSVFILES = Top.bsv Simple.bsv
CPPFILES = testsimple.cpp

BSVDIR= $(SRC_BSV):$(SRC_BSV)/time:$(SRC_BSV)/hash:$(SRC_BSV)/hashtable_simple:$(SRC_BSV)/valuestr:$(SRC_BSV)/flashstr:$(SRC_BSV)/arbiter:$(SRC_BSV)/../xilinx/aurora_8b10b_fmc1:$(SRC_BSV)/../controller/src:$(SRC_BSV)/../controller/src/common:$(SRC_BSV)/../controller/src/model_virtex:$(SRC_BSV)/../controller/src/hw_virtex:$(SRC_BSV)/../lib:$(SRC_BSV)/hardware_controller/dram_sim:$(SRC_BSV)/hardware_controller/dram/any_64

NUMBER_OF_MASTERS = 0

CONNECTALFLAGS = --bscflags " -p +:$(BSVDIR)"


CONNECTALDIR=/home/shuotao/fpgamemcached/xbsv

include ~/tools/xbsv/Makefile.connectal

