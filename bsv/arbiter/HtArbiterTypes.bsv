
typedef struct{
   Bit#(64) addr;
   Bit#(7) numBytes;
   } DRAMReadReq deriving(Bits,Eq);

typedef struct{
   Bit#(64) addr;
   Bit#(7) numBytes;
   Bit#(512) data;
   } DRAMWriteReq deriving(Bits,Eq);

