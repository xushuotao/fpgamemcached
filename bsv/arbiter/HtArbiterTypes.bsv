
interface ToHtArbiterIfc;
   method Bool isIssuing();
   method Bit#(32) currHv();
endinterface

interface ToPrevModuleIfc;
   method Action enq(Bit#(32) v);
endinterface

typedef struct{
   Bool rnw;
   Bit#(64) addr;
   Bit#(512) data;
   Bit#(7) numBytes;
   } HtDRAMReq deriving(Bits,Eq);
