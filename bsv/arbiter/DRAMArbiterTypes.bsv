
typedef struct{
   Bool rnw;
   Bit#(64) addr;
   Bit#(7) numBytes;
   Bit#(512) data;
   } DRAMReq deriving(Bits,Eq);
