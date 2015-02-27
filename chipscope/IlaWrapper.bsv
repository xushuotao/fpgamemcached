
interface DebugDMA;
   method Action setAddr (Bit#(32) i);
   method Action setBytes (Bit#(64) i);
   method Action setData (Bit#(64) i);
endinterface

interface DebugIfc;
   interface DebugDMA ila_dma_0;
   interface DebugDMA ila_dma_1;
endinterface

module mkChipscopeEmpty(DebugIfc);
   //Empty
   
  /* 
   interface DebugDMA ila_dma_0;
      method Action setAddr (Bit#(32) i);
      method Action setBytes (Bit#(64) i);
      method Action setData (Bit#(64) i);
   endinterface
   
   interface DebugDMA ila_dma_1;
      method Action setAddr (Bit#(32) i);
      method Action setBytes (Bit#(64) i);
      method Action setData (Bit#(64) i);
   endinterface*/
endmodule

import "BVI" ila_dma_viv =
module mkChipscopeDebug(DebugIfc);
   default_clock clk0;
   default_reset rst0;

   input_clock clk0(v_clk0) <- exposeCurrentClock;
   input_reset rst0(v_rst0) <- exposeCurrentReset;


   interface DebugDMA ila_dma_0;
      method setAddr (v_debug0_0) enable((*inhigh*)en0_0);
      method setBytes (v_debug0_1) enable((*inhigh*)en0_1);
      method setData (v_debug0_2) enable((*inhigh*)en0_2);
   endinterface
   
   interface DebugDMA ila_dma_1;
      method setAddr (v_debug1_0) enable((*inhigh*)en1_0);
      method setBytes (v_debug1_1) enable((*inhigh*)en1_1);
      method setData (v_debug1_2) enable((*inhigh*)en1_2);
   endinterface

   schedule
   (
    ila_dma_0_setAddr, ila_dma_0_setBytes, ila_dma_0_setData,
    ila_dma_1_setAddr, ila_dma_1_setBytes, ila_dma_1_setData
    )
   CF
   (
    ila_dma_0_setAddr, ila_dma_0_setBytes, ila_dma_0_setData,
    ila_dma_1_setAddr, ila_dma_1_setBytes, ila_dma_1_setData
    );
endmodule
