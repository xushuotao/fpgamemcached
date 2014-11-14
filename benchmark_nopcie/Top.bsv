// bsv libraries
import Vector::*;
import FIFO::*;
import Connectable::*;

// portz libraries
import Directory::*;
import CtrlMux::*;
import Portal::*;
import Leds::*;
import MemTypes::*;
import MemPortal::*;
import HostInterface::*;


// generated by tool
import SimpleIndicationProxy::*;
import SimpleRequestWrapper::*;

// defined by user
import Simple::*;

import DRAMController::*;

`ifdef BSIM
import DDR3Sim::*;
`else
import Clocks          :: *;
import DefaultValue    :: *;
import XilinxVC707DDR3::*;
import Xilinx       :: *;
import XilinxCells ::*;
`endif

typedef enum {SimpleIndication, SimpleRequest} IfcNames deriving (Eq,Bits);

module mkPortalTop#(HostType host)(StdPortalTop#(PhysAddrWidth));
   
   `ifdef BSIM
   let ddr3_ctrl_user <- mkDDR3Simulator;
   `else
   Clock sys_clk = host.tsys_clk_200mhz;
   Reset pci_sys_reset_n <- mkAsyncResetFromCR(1, sys_clk); 
   
   ClockGenerator7Params clk_params = defaultValue();
   clk_params.clkin1_period     = 5.000;       // 200 MHz reference
   clk_params.clkin_buffer      = False;       // necessary buffer is instanced above
   clk_params.reset_stages      = 0;           // no sync on reset so input clock has pll as only load
   clk_params.clkfbout_mult_f   = 5.000;       // 1000 MHz VCO
   clk_params.clkout0_divide_f  = 10;          // unused clock 
   //clk_params.clkout0_divide_f  = 8;//10;          // unused clock 
   clk_params.clkout1_divide    = 5;           // ddr3 reference clock (200 MHz)

   ClockGenerator7 clk_gen <- mkClockGenerator7(clk_params, clocked_by sys_clk, reset_by pci_sys_reset_n);
   Clock ddr_clk = clk_gen.clkout0;
   Reset rst_n <- mkAsyncReset( 1, pci_sys_reset_n, ddr_clk );
   Reset ddr3ref_rst_n <- mkAsyncReset( 1, rst_n, clk_gen.clkout1 );
   //Reset ddr3ref_rst_n <- mkAsyncReset( 1, pci_sys_reset_n, clk_gen.clkout1 );

   DDR3_Configure ddr3_cfg = defaultValue;
   ddr3_cfg.reads_in_flight = 2;   // adjust as needed
   //ddr3_cfg.reads_in_flight = 24;   // adjust as needed
   //ddr3_cfg.fast_train_sim_only = False; // adjust if simulating
   //Clock ddr_buf <- mkClockBUFG(clocked_by clk_gen.clkout1);
   Clock ddr_buf = clk_gen.clkout1;
   DDR3_Controller_VC707 ddr3_ctrl <- mkDDR3Controller_VC707(ddr3_cfg, ddr_buf, clocked_by ddr_buf, reset_by ddr3ref_rst_n);
   
   Clock ddr3clk = ddr3_ctrl.user.clock;
   Reset ddr3rstn = ddr3_ctrl.user.reset_n;
   `endif
   
   DRAMControllerIfc dramController <- mkDRAMController();
   
   `ifdef BSIM
   let ddr_cli_200Mhz <- mkDDR3ClientSync(dramController.ddr3_cli, clockOf(dramController), resetOf(dramController), clockOf(ddr3_ctrl_user), resetOf(ddr3_ctrl_user));
   mkConnection(ddr_cli_200Mhz, ddr3_ctrl_user);
   `else
   let ddr_cli_200Mhz <- mkDDR3ClientSync(dramController.ddr3_cli, clockOf(dramController), resetOf(dramController), ddr3clk, ddr3rstn);
   mkConnection(ddr_cli_200Mhz, ddr3_ctrl.user);
   `endif
   
   

   // instantiate user portals
   SimpleIndicationProxy simpleIndicationProxy <- mkSimpleIndicationProxy(SimpleIndication);
   SimpleRequest simpleRequest <- mkSimpleRequest(simpleIndicationProxy.ifc, dramController);
   SimpleRequestWrapper simpleRequestWrapper <- mkSimpleRequestWrapper(SimpleRequest,simpleRequest);
   
   Vector#(2,StdPortal) portals;
   portals[0] = simpleRequestWrapper.portalIfc;
   portals[1] = simpleIndicationProxy.portalIfc;
   
   // instantiate system directory
   StdDirectory dir <- mkStdDirectory(portals);
   let ctrl_mux <- mkSlaveMux(dir,portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = nil;
   interface leds = default_leds;

endmodule : mkPortalTop


