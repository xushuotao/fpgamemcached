source "board.tcl"
source "$connectaldir/scripts/connectal-synth-ip.tcl"

connectal_synth_ip mig_7series 2.0 ddr3_v2_0 [list CONFIG.XML_INPUT_FILE "/home/shuotao/fpgamemcached/xilinx/ddr3_v2_0/vc707-ddr3-800mhz.prj" CONFIG.RESET_BOARD_INTERFACE {Custom} CONFIG.MIG_DONT_TOUCH_PARAM {Custom} CONFIG.BOARD_MIG_PARAM {Custom}]
