
CONNECTALDIR?=~/tools/connectal/
INTERFACES = MemreadRequest MemreadIndication
BSVFILES = Memread.bsv Top.bsv ../ProtocolHeader.bsv ../../lib/Align.bsv
CPPFILES=testmemread.cpp testmemread.h

#DATA_BUS_WIDTH=128
#NUMBER_OF_MASTERS=1
CONNECTALFLAGS = -D DataBusWidth=128 -D Debug --bscflags " -D DataBusWidth=128 -D Debug"

include $(CONNECTALDIR)/Makefile.connectal

