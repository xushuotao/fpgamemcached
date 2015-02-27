
interface DebugVal;
   method Action setAddr (Bit#(64) i);
   method Action setBytes (Bit#(64) i);
   method Action setData (Bit#(64) i);
endinterface

interface DebugDram;
   method Action setAddr (Bit#(64) i);
   method Action setWriteen (Bit#(64) i);
   method Action setDataIn (Bit#(512) i);
   method Action setDataOut (Bit#(512) i);
endinterface

interface DebugIfc;
   interface DebugVal ila_val_0;
   interface DebugVal ila_val_1;
   interface DebugDram ila_dram_0;
   interface DebugDram ila_dram_1;
endinterface

module mkChipscopeEmpty(DebugIfc);
   //Empty
endmodule

import "BVI" chipscope_debug_viv =  //TODO change for Vivado or ISE IP
module mkChipscopeDebug(DebugIfc);
   default_clock clk0;
   default_reset rst0;

   input_clock clk0(v_clk0) <- exposeCurrentClock;
   input_reset rst0(v_rst0) <- exposeCurrentReset;


   interface DebugVal ila_val_0;
      method setAddr (v_debug0_0) enable((*inhigh*)en0_0);
      method setBytes (v_debug0_1) enable((*inhigh*)en0_1);
      method setData (v_debug0_2) enable((*inhigh*)en0_2);
   endinterface
   
   interface DebugVal ila_val_1;
      method setAddr (v_debug1_0) enable((*inhigh*)en1_0);
      method setBytes (v_debug1_1) enable((*inhigh*)en1_1);
      method setData (v_debug1_2) enable((*inhigh*)en1_2);
   endinterface
 
   interface DebugDram ila_dram_0;
      method setAddr (v_debug2_0) enable((*inhigh*)en2_0);
      method setWriteen (v_debug2_1) enable((*inhigh*)en2_1);
      method setDataIn (v_debug2_2) enable((*inhigh*)en2_2);
      method setDataOut (v_debug2_3)enable((*inhigh*)en2_3);
   endinterface

   interface DebugDram ila_dram_1;
      method setAddr (v_debug3_0) enable((*inhigh*)en3_0);
      method setWriteen (v_debug3_1) enable((*inhigh*)en3_1);
      method setDataIn (v_debug3_2) enable((*inhigh*)en3_2);
      method setDataOut (v_debug3_3)enable((*inhigh*)en3_3);
   endinterface

   schedule
   (
    ila_val_0_setAddr, ila_val_0_setBytes, ila_val_0_setData,
    ila_val_1_setAddr, ila_val_1_setBytes, ila_val_1_setData,
    ila_dram_0_setAddr, ila_dram_0_setWriteen, ila_dram_0_setDataIn, ila_dram_0_setDataOut,
    ila_dram_1_setAddr, ila_dram_1_setWriteen, ila_dram_1_setDataIn, ila_dram_1_setDataOut
    )
   CF
   (
    ila_val_0_setAddr, ila_val_0_setBytes, ila_val_0_setData,
    ila_val_1_setAddr, ila_val_1_setBytes, ila_val_1_setData,
    ila_dram_0_setAddr, ila_dram_0_setWriteen, ila_dram_0_setDataIn, ila_dram_0_setDataOut,
    ila_dram_1_setAddr, ila_dram_1_setWriteen, ila_dram_1_setDataIn, ila_dram_1_setDataOut
    );
endmodule
    
