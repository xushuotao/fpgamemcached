import FIFO::*;
import FIFOF::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;
import MyArbiter::*;

import DRAMCommon::*;



typedef struct{
   Bool rnw;
   Bool ack;
   Bit#(64) addr;
   Bit#(7) numBytes;
   Bit#(512) data;
   Bool initlock;
   Bool lock;
   Bool ignoreLock;
   } DRAM_ACK_Req deriving(Bits,Eq);

typedef Server#(DRAM_ACK_Req, Bit#(512)) ValDRAMServer;
typedef Client#(DRAM_ACK_Req, Bit#(512)) ValDRAMClient;
   

interface ValDRAMArbiterIfc;
   interface Vector#(2, ValDRAMServer) dramServers;
   interface DRAM_LOCK_Client dramClient;
   interface Get#(Bool) ack;
endinterface


module mkValDRAMArbiter(ValDRAMArbiterIfc);
   
   Arbiter_IFC#(2) arbiter <- mkArbiter(False);
   
   Vector#(2, FIFOF#(DRAM_ACK_Req)) reqs<- replicateM(mkFIFOF);
   Vector#(2, FIFO#(Bit#(512))) resps<- replicateM(mkFIFO);
   //Vector#(2, FIFO#(Bit#(512))) resps<- replicateM(mkSizedFIFO(32));
   
   FIFO#(DRAM_LOCK_Req) cmdQ <- mkFIFO;
   //FIFO#(Bit#(512)) dataQ <- mkFIFO;
   FIFO#(Bit#(512)) dataQ <- mkSizedFIFO(32);
   
   FIFO#(Bit#(TLog#(2))) tagQ <- mkSizedFIFO(32);
   
   FIFO#(Bool) ackQ <- mkSizedFIFO(32);
   
   Reg#(Bit#(32)) reqCnt <- mkReg(0);
   
   for (Integer i = 0; i < valueOf(2); i = i + 1) begin
      rule doReqs_0 if (reqs[i].notEmpty);
         arbiter.clients[i].request;
      endrule
      
      rule doReqs_1 if (arbiter.grant_id == fromInteger(i));

         let req <- toGet(reqs[i]).get();
            cmdQ.enq(DRAM_LOCK_Req{rnw: req.rnw, addr: req.addr, numBytes: req.numBytes, data: req.data, initlock: req.initlock, lock: req.lock, ignoreLock: req.ignoreLock});
            if (req.rnw) begin
               tagQ.enq(fromInteger(i));
         end
         
         if ( i == 0 ) begin
            if (!req.rnw && req.ack) begin
               $display("Value store header updated reqCnt = %d", reqCnt);
               reqCnt <= reqCnt + 1;
               ackQ.enq(True);
            end
         end
      endrule
      
      rule doResp if ( tagQ.first() == fromInteger(i));
         let data = dataQ.first;
         resps[i].enq(data);
         tagQ.deq();
         dataQ.deq();
      endrule
   end
   
   
   Vector#(2, ValDRAMServer) ds;
   for (Integer i = 0; i < 2; i = i + 1)
      ds[i] = (interface ValDRAMServer;
                  interface Put request = toPut(reqs[i]);
                  interface Get response = toGet(resps[i]);
               endinterface);
   
   interface dramServers = ds;
   
   interface ValDRAMClient dramClient;
      interface Get request = toGet(cmdQ);
      interface Put response = toPut(dataQ);
   endinterface
   
   interface Get ack = toGet(ackQ);
      
endmodule
