import DRAMArbiterTypes::*;
import DRAMArbiter::*;

import Time::*;
import Connectable::*;
import GetPut::*;
import Vector::*;
import Shifter::*;

typedef struct{
   Bit#(30) hv;
   Bit#(2) idx;
   Bit#(32) nBytes;
   Time_t timestamp;
   } ValHeader deriving (Bits, Eq);

/* constants definitions */
typedef TExp#(20) MaxValSz;
typedef Bit#(TAdd#(TLog#(MaxValSz),1)) ValSizeT;

typedef SizeOf#(ValHeader) ValHeaderSz;

typedef TDiv#(ValHeaderSz, 512) HeaderBurstSz;


typedef enum {ProcHeader, Proc} ValAcc_State deriving (Bits, Eq);

typedef struct {
   Bit#(64) addr;
   Bit#(64) nBytes;
   } BurstReq deriving (Bits, Eq);


typedef struct {
   Bit#(64) currAddr;
   Bit#(32) numBytes;
   //Bit#(6) initOffset;
   //Bit#(7) initNbytes;
   //Bit#(32) numBursts;
   Bool rnw;
   Bit#(30) hv;
   Bit#(2) idx;
   
   Bit#(6) byteOffset;
  // Bit#(4) regOffset;
   
  // Bit#(5) initNWords;
   //Bit#(32) totalNWords;
   
   } CmdType deriving (Bits, Eq);

typedef struct {
   Bit#(32) numBytes;
   Bit#(32) nBursts;
   //Bit#(7)  initOffset;
   //Bit#(7) initNbytes;
   Bit#(6) byteOffset;
   //Bit#(4) regOffset;
   
   //Bit#(5) initNWords;
   //Bit#(32) totalNWords;
   
   } RespHandleType deriving (Bits, Eq); 

/*typedef struct {
   Bit#(64) addr;
   Bit#(7) numBytes;
   Bool rnw;
   } DRAMReqType_Pre deriving (Bits, Eq);


typedef struct {
   Bit#(64) addr;
   Bit#(512) data;
   Bit#(6) shiftval;
   Bit#(7) numBytes;
   Bool rnw;
   } DRAMReqType_Imm deriving (Bits, Eq);

instance Connectable#(Get#(DRAMReqType_Imm), Put#(DRAMReq));
   module mkConnection#(Get#(DRAMReqType_Imm) cli, Put#(DRAMReq) ser)(Empty);
      rule proc;
         let req <- cli.get();
         let rnw = req.rnw;
         let addr = req.addr;
         Vector#(64, Bit#(8)) raw_data = unpack(req.data);
         Bit#(512) data = pack(reverse(rotateBy(reverse(raw_data), unpack(req.shiftval))));
         //Bit#(512) data = rotateRByte(req.data, req.shiftval);
         let numBytes = req.numBytes;
         if ( !req.rnw ) begin
            //$display("DRAMReq_Imm: rnw = %b, addr = %d, data = %h, shiftval = %d, nBytes = %d", req.rnw, req.addr, req.data, req.shiftval, req.numBytes);
            //$display("DRAMReq: rnw = %b, addr = %d, data = %h, nBytes = %d", rnw, addr, data, numBytes);
         end
         ser.put(DRAMReq{rnw: rnw, addr:addr, data: data, numBytes:numBytes});
      endrule
   endmodule
endinstance
*/