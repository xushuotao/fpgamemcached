

##    run: run the program
##         pass parameters to software via 'make RUN_ARGS= run'
#RUN_ARGS=

export DTOP=/home/shuotao/fpgamemcached/fpga_dma/bluesim
CONNECTALDIR=/home/shuotao/tools/xbsv/scripts/../
BSVPATH = /home/shuotao/tools/xbsv/scripts/../generated/xilinx:/home/shuotao/fpgamemcached/bsv:/home/shuotao/fpgamemcached/bsv/hardware_controller/dram_sim/raw_64:/home/shuotao/tools/xbsv/scripts/../lib/bsv:/home/shuotao/tools/xbsv/scripts/../bsv:/home/shuotao/tools/xbsv/bsv:/home/shuotao/fpgamemcached/bsv/packet:/home/shuotao/fpgamemcached/bsv/hash:/home/shuotao/fpgamemcached/bsv/hashtable:/home/shuotao/fpgamemcached/bsv/hardware_controller/dram_sim:/home/shuotao/fpgamemcached/bsv/valuestr:/home/shuotao/fpgamemcached/fpga_dma:/home/shuotao/fpgamemcached/bsv/time

BOARD=bluesim
MKTOP=mkBsimTop
OS=android
DUT=mkbsimtop

export S2H = ServerRequest DmaDebugRequest MMUConfigRequest
export H2S = ServerIndication DmaDebugIndication MMUConfigIndication
BSVFILES = /home/shuotao/fpgamemcached/bsv/packet/Packet.bsv /home/shuotao/fpgamemcached/bsv/MemcachedServer.bsv /home/shuotao/fpgamemcached/bsv/Proc.bsv /home/shuotao/fpgamemcached/bsv/DMAHelper.bsv /home/shuotao/fpgamemcached/bsv/ProtocolHeader.bsv /home/shuotao/fpgamemcached/bsv/hash/JenkinsHash.bsv /home/shuotao/fpgamemcached/bsv/time/Time.bsv /home/shuotao/fpgamemcached/bsv/hashtable/Hashtable.bsv /home/shuotao/fpgamemcached/bsv/valuestr/Valuestr.bsv /home/shuotao/fpgamemcached/fpga_dma/Top.bsv /home/shuotao/fpgamemcached/bsv/hardware_controller/dram_sim/DDR3Sim.bsv /home/shuotao/fpgamemcached/bsv/hardware_controller/dram_sim/raw_64/DRAMController.bsv /home/shuotao/tools/xbsv/bsv/PortalMemory.bsv /home/shuotao/tools/xbsv/bsv/DisplayInd.bsv

BSCFLAGS_PROJECT = 
BSIM_CXX_PROJECT = 
XELABFLAGS = 
XSIMFLAGS  = -R
TOPBSVFILE = /home/shuotao/tools/xbsv/bsv/BsimTop.bsv
BSVDEFINES =  -D IMPORT_HOSTIF -D NumberOfMasters=1 -D project_dir=/home/shuotao/fpgamemcached/fpga_dma/bluesim -D BsimHostTypeIF -D PhysAddrWidth=40 -D BOARD_bluesim
QTUSED = 
export BSVDEFINES_LIST = IMPORT_HOSTIF NumberOfMasters=1 project_dir=/home/shuotao/fpgamemcached/fpga_dma/bluesim BsimHostTypeIF PhysAddrWidth=40 BOARD_bluesim
export DUT_NAME = mkBsimTop


IMPORT_HOSTIF=""
NumberOfMasters="1"
project_dir="/home/shuotao/fpgamemcached/fpga_dma/bluesim"
BsimHostTypeIF=""
PhysAddrWidth="40"
BOARD_bluesim=""

include $(CONNECTALDIR)/scripts/Makefile.connectal.build


FPGAMAKE=$(CONNECTALDIR)/../fpgamake/fpgamake
fpgamake.mk: $(vfile) Makefile prepare_bin_target
	$(Q)mkdir -p hw
	$(Q)$(FPGAMAKE) $(FPGAMAKE_VERBOSE) -o fpgamake.mk  --floorplan= --xdc=/home/shuotao/tools/xbsv/xilinx/constraints/vc707_ddr3_sx.xdc --xdc=/home/shuotao/tools/xbsv/xilinx/constraints/bluesim.xdc   -t $(MKTOP)  -b hw/mkTop.bit verilog $(CONNECTALDIR)/verilog /afs/csail.mit.edu/group/csg/tools_lx86/bluespec/current/lib/board_support/bluenoc/xilinx/VC707/verilog/ddr3_v2_0/ddr3_v2_0/user_design/rtl /home/shuotao/tools/xbsv/verilog

hw/mkTop.bit: fpgamake.mk prepare_bin_target
	$(Q)make -f fpgamake.mk
	$(Q)cp -f Impl/*/*.rpt bin

