import Time::*;
//import ValuestrCommon::*;
import MemcachedTypes::*;


typedef enum {ProcHeader, Proc} ValAcc_State deriving (Bits, Eq);

typedef struct {
   Bit#(64) addr;
   Bit#(64) nBytes;
   } BurstReq deriving (Bits, Eq);


typedef struct {
   Bit#(64) currAddr;
   Bit#(32) numBytes;
   Bit#(6) byteOffset;

   Bool rnw;
   Bit#(30) hv;
   Bit#(2) idx;

   Bool doEvict;
   ValSizeT old_nBytes;
   
   } CmdType deriving (Bits, Eq);

typedef struct {
   Bit#(32) numBytes;
   Bit#(32) nBursts;
   Bit#(6) byteOffset;
   } RespHandleType deriving (Bits, Eq); 




