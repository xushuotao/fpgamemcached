import GetPut::*;
import ClientServer::*;
import Connectable::*;
import DRAMController::*;

typedef union tagged {
   Bit#(6) Mask;
   Bit#(7) NumBytes;
   } ByteOperand deriving (Bits, Eq); 

typedef struct{
   Bool rnw;
   Bit#(64) addr;
   Bit#(7) numBytes;
   Bit#(512) data;
   } DRAMReq deriving(Bits,Eq);

// typedef struct{
//    Bool rnw;
//    Bit#(64) addr;
//    Bit#(7) numBytes;
//    Bit#(512) data;
//    Bool lock;
//    } DRAMReq_LOCK deriving(Bits,Eq);

// typedef Server#(DRAMReq_LOCK, Bit#(512)) DRAMServer;
// typedef Client#(DRAMReq_LOCK, Bit#(512)) DRAMClient;


typedef struct{
   Bool rnw;
   Bit#(64) addr;
   Bit#(7) numBytes;
   Bit#(512) data;
    Bool initlock;
   Bool lock;
    Bool ignoreLock;
   Bool ackReq;
   } DRAM_LOCK_Req deriving(Bits,Eq);


typedef Server#(DRAM_LOCK_Req, Bit#(512)) DRAM_LOCK_Server;
typedef Client#(DRAM_LOCK_Req, Bit#(512)) DRAM_LOCK_Client;

typedef Server#(DRAMReq, Bit#(512)) DRAMServer;
typedef Client#(DRAMReq, Bit#(512)) DRAMClient;

instance Connectable#(DRAMClient, DRAMControllerIfc);
   module mkConnection#(DRAMClient dramClient, DRAMControllerIfc dram)(Empty);
      rule doCmd;
         let req <- dramClient.request.get();
         //$display("DRAMController Req rnw = %d, addr = %d, data = %h, numBytes = %d at %t", req.rnw, req.addr, req.data, req.numBytes,$time);
         if (req.rnw) 
            dram.readReq(req.addr, req.numBytes);
         else
            dram.write(req.addr, req.data, req.numBytes);
      endrule
   
      rule doData;
         //$display("DRAMController got read value from DRAMController at %t",$time);
         let v <- dram.read;
         dramClient.response.put(v);
      endrule
   endmodule
endinstance

instance Connectable#(DRAM_LOCK_Client, DRAMControllerIfc);
   module mkConnection#(DRAM_LOCK_Client dramClient, DRAMControllerIfc dram)(Empty);
      rule doCmd;
         let req <- dramClient.request.get();
         //$display("DRAMController Req rnw = %d, addr = %d, data = %h, numBytes = %d at %t", req.rnw, req.addr, req.data, req.numBytes,$time);
         if (req.rnw) 
            dram.readReq(req.addr, req.numBytes);
         else
            dram.write(req.addr, req.data, req.numBytes);
      endrule
   
      rule doData;
         //$display("DRAMController got read value from DRAMController at %t",$time);
         let v <- dram.read;
         dramClient.response.put(v);
      endrule
   endmodule
endinstance
