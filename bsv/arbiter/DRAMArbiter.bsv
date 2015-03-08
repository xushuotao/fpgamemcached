package DRAMArbiter;

import FIFO::*;
import FIFOF::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;
//import Arbiter::*;
import MyArbiter::*;

import DRAMArbiterTypes::*;
import DRAMController::*;

typedef Server#(DRAMReq, Bit#(512)) DRAMServer;
typedef Client#(DRAMReq, Bit#(512)) DRAMClient;

interface DRAMArbiterIfc#(numeric type numServers);
   interface Vector#(numServers, DRAMServer) dramServers;
   interface DRAMClient dramClient;
endinterface
      
module mkDRAMArbiter(DRAMArbiterIfc#(numServers));
   
   Arbiter_IFC#(numServers) arbiter <- mkArbiter(False);
   /*Arbiter_IFC#(numServers) arbiter1 <- mkStickyArbiter;
   
   Arbiter_IFC#(numServers) arbiter;
   if (!sticky)
      arbiter = arbiter0;
   else
      arbiter = arbiter1;*/
   
   Vector#(numServers, FIFOF#(DRAMReq)) reqs<- replicateM(mkFIFOF);
   Vector#(numServers, FIFO#(Bit#(512))) resps<- replicateM(mkFIFO);
   
   FIFO#(DRAMReq) cmdQ <- mkFIFO;
   FIFO#(Bit#(512)) dataQ <- mkFIFO;
   
   FIFO#(Bit#(TLog#(numServers))) tagQ <- mkSizedFIFO(32);
   
   Reg#(Bit#(5)) currRespIdx <- mkReg(0);
   
   
   for (Integer i = 0; i < valueOf(numServers); i = i + 1) begin
      rule doReqs_0 if (reqs[i].notEmpty);
         //$display("DRAMClient[%d] request for grant", i);
         arbiter.clients[i].request;
      endrule
      
      rule doReqs_1 if (arbiter.grant_id == fromInteger(i));
         //         let grantid = arbiter.grant_id;
         //       if ( grantid == fromInteger(i)) begin
         let req <- toGet(reqs[i]).get();
         //$display("DRAMClient[%d] get grants on arbiter, readReq = %b", grandid, req.rnw);
         cmdQ.enq(req);
         if (req.rnw) begin
            tagQ.enq(fromInteger(i));
         end
         //     end
      endrule
      
      rule doResp if ( tagQ.first() == fromInteger(i));
         let data = dataQ.first;
         //let returnTag = tagQ.first();
         //if ( returnTag == fromInteger(i)) begin
         //$display("DRAMClient[%d] get back on readReq, data = %h", returnTag, data);
         resps[i].enq(data);
         //resps[0].enq(data);
         tagQ.deq();
         dataQ.deq();
        // end
      endrule
   end
   
   /*rule doReqs_1;
      let grandid = arbiter.grant_id;
      let req <- toGet(reqs[grandid]).get();
      //$display("DRAMClient[%d] get grants on arbiter, readReq = %b", grandid, req.rnw);
      cmdQ.enq(req);
      if (req.rnw) begin
         tagQ.enq(grandid);
      end
   endrule

   rule doResp;
      let data = dataQ.first;
      let returnTag = tagQ.first();
      //$display("DRAMClient[%d] get back on readReq, data = %h", returnTag, data);
      resps[returnTag].enq(data);
      //resps[0].enq(data);
      tagQ.deq();
      dataQ.deq();
   endrule*/
   
      
   
   Vector#(numServers, DRAMServer) ds;
   for (Integer i = 0; i < valueOf(numServers); i = i + 1)
      ds[i] = (interface DRAMServer;
                  interface Put request = toPut(reqs[i]);
                  interface Get response = toGet(resps[i]);
               endinterface);
   
   interface dramServers = ds;
   
   interface DRAMClient dramClient;
      interface Get request = toGet(cmdQ);
      interface Put response = toPut(dataQ);
   endinterface
      
endmodule
           
instance Connectable#(DRAMClient, DRAMControllerIfc);
   module mkConnection#(DRAMClient dramClient, DRAMControllerIfc dram)(Empty);
      rule doCmd;
         let req <- dramClient.request.get();
         if (req.rnw) 
            dram.readReq(req.addr, req.numBytes);
         else
            dram.write(req.addr, req.data, req.numBytes);
      endrule
   
      rule doData;
         //$display("DRAM Arbiter got read value from DRAMController at %t",$time);
         let v <- dram.read;
         dramClient.response.put(v);
      endrule
   endmodule
endinstance

endpackage
