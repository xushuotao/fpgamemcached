

##    run: run the program
##         pass parameters to software via 'make RUN_ARGS= run'
#RUN_ARGS=

export DTOP=/home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT/vc707
CONNECTALDIR=/home/chamdoo/bluedbm/tools/connectal
BSVPATH = /home/chamdoo/bluedbm/tools/connectal/generated/altera:/home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT:/home/chamdoo/bluedbm/tools/connectal/lib/bsv:/home/chamdoo/bluedbm/tools/connectal/bsv:/home/chamdoo/bluedbm/tools/connectal/generated/xilinx

BOARD=vc707
MKTOP=mkPcieTop
OS=ubuntu
DUT=mkpcietop

export INTERFACES = BluecacheRequest BluecacheIndication MemServerRequest MMURequest MemServerIndication MMUIndication
BSVFILES = /home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT/Bluecache.bsv /home/chamdoo/fpgamemcached/bsv/Test_Bluecache_MULTICLIENT/Top.bsv /home/chamdoo/bluedbm/tools/connectal/bsv/ConnectalMemory.bsv /home/chamdoo/bluedbm/tools/connectal/bsv/DisplayInd.bsv

BSCFLAGS_PROJECT =  -p +:/home/shuotao/fpgamemcached/bsv/:/home/shuotao/fpgamemcached/bsv//time:/home/shuotao/fpgamemcached/bsv//hash:/home/shuotao/fpgamemcached/bsv//hashtable_simple:/home/shuotao/fpgamemcached/bsv//valuestr:/home/shuotao/fpgamemcached/bsv//flashstr:/home/shuotao/fpgamemcached/bsv//arbiter:/home/shuotao/fpgamemcached/bsv//../xilinx/aurora_8b10b_fmc1:/home/shuotao/fpgamemcached/bsv//../controller/src:/home/shuotao/fpgamemcached/bsv//../controller/src/common:/home/shuotao/fpgamemcached/bsv//../controller/src/model_virtex:/home/shuotao/fpgamemcached/bsv//../controller/src/hw_virtex:/home/shuotao/fpgamemcached/bsv//../lib:/home/shuotao/fpgamemcached/bsv//hardware_controller/dram_sim:/home/shuotao/fpgamemcached/bsv//hardware_controller/dram/any_64 -u -steps-max-intervals 200000 -D DataBusWidth=128 -D Debug +RTS -K46777216 -RTS
BSIM_CXX_PROJECT = 
XELABFLAGS = 
XSIMFLAGS  = -R
TOPBSVFILE = $(CONNECTALDIR)/bsv/PcieTop.bsv
BSVDEFINES =  -D IMPORT_HOSTIF -D PinType=Top_Pins -D DataBusWidth=128 -D Debug -D NumberOfMasters=1 -D PinType=Empty -D MainClockPeriod=8 -D DerivedClockPeriod=8 -D project_dir=$(DTOP) -D XILINX -D Virtex7 -D PCIE -D PcieHostTypeIF -D PhysAddrWidth=40 -D BOARD_vc707
QTUSED = 
export BSVDEFINES_LIST = IMPORT_HOSTIF PinType=Top_Pins DataBusWidth=128 Debug NumberOfMasters=1 PinType=Empty MainClockPeriod=8 DerivedClockPeriod=8 project_dir=$(DTOP) XILINX Virtex7 PCIE PcieHostTypeIF PhysAddrWidth=40 BOARD_vc707
export DUT_NAME = mkPcieTop




IMPORT_HOSTIF=""
PinType="Top_Pins"
DataBusWidth="128"
Debug=""
NumberOfMasters="1"
PinType="Empty"
MainClockPeriod="8"
DerivedClockPeriod="8"
project_dir="$(DTOP)"
XILINX=""
Virtex7=""
PCIE=""
PcieHostTypeIF=""
PhysAddrWidth="40"
BOARD_vc707=""


include $(CONNECTALDIR)/scripts/Makefile.connectal.build


FPGAMAKE=$(CONNECTALDIR)/../fpgamake/fpgamake
fpgamake.mk: $(vfile) Makefile prepare_bin_target
	$(Q)mkdir -p hw
	$(Q)$(FPGAMAKE) $(FPGAMAKE_VERBOSE) -o fpgamake.mk --board=vc707 --part=xc7vx485tffg1761-2 -s mkPcieEndpointX7 -s mkPcieHost --floorplan= --constraint=/home/chamdoo/fpgamemcached/xilinx/constraints/clocks.xdc --constraint=/home/chamdoo/fpgamemcached/xilinx/constraints/vc707_ddr3_sx.xdc --constraint=/home/chamdoo/fpgamemcached/xilinx/aurora_8b10b_fmc1/aurora_8b10b_fmc1_exdes.xdc --constraint=/home/chamdoo/bluedbm/tools/connectal/constraints/xilinx/vc707.xdc --xci=/home/chamdoo/bluedbm/tools/connectal/out/vc707/aurora_8b10b_fmc1/aurora_8b10b_fmc1.xci --xci=/home/chamdoo/bluedbm/tools/connectal/out/vc707/pcie_7x_0/pcie_7x_0.xci   -t $(MKTOP)  -b hw/mkTop.bit verilog $(CONNECTALDIR)/verilog /afs/csail.mit.edu/group/csg/tools_lx86/bluespec/current/lib/board_support/bluenoc/xilinx/VC707/verilog/ddr3_v2_0/ddr3_v2_0/user_design/rtl /home/chamdoo/fpgamemcached/xilinx/aurora_8b10b_fmc1 /home/chamdoo/bluedbm/tools/connectal/verilog

hw/mkTop.bit: fpgamake.mk prepare_bin_target
	$(Q)make -f fpgamake.mk
ifeq ($(XILINX),"")
	$(Q)cp -f Impl/*/*.rpt bin
else ifeq ($(ALTERA),"")
	$(Q)echo "copy report files"
endif

