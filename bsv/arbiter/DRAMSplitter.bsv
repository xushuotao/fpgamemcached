import ClientServer::*;
import GetPut::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import MyArbiter::*;
import DRAMCommon::*;
import DRAMController::*;

interface DRAMSplitterIfc;
   interface Vector#(2, DRAMServer) dramServers;
   interface DRAMClient dramClient;
endinterface

typedef 30 LogMaxAddr;

module mkDRAMSplitter(DRAMSplitterIfc);
   
   Integer addrSeg = valueOf(TExp#(TSub#(LogMaxAddr,TLog#(2))));
   
   Arbiter_IFC#(2) arbiter <- mkArbiter(False);

   Vector#(2, FIFOF#(DRAMReq)) reqs<- replicateM(mkFIFOF);
   Vector#(2, FIFO#(Bit#(512))) resps<- replicateM(mkFIFO);
   
   
   FIFO#(DRAMReq) cmdQ <- mkFIFO;
   FIFO#(Bit#(512)) dataQ <- mkFIFO;
   
   FIFO#(Bit#(TLog#(2))) tagQ <- mkSizedFIFO(32);
   
   
   
   for (Integer i = 0; i < 2; i = i + 1) begin
      rule doReqs_0 if (reqs[i].notEmpty);
         arbiter.clients[i].request;
      endrule
      
      rule doReqs_1 if (arbiter.grant_id == fromInteger(i));
         let req <- toGet(reqs[i]).get();
         if ( req.addr < fromInteger(addrSeg) ) begin
            req.addr = req.addr + fromInteger(addrSeg*i);
            cmdQ.enq(req);
            if (req.rnw) begin
               tagQ.enq(fromInteger(i));
            end
         end
         else begin
            $display("Segmentation Fault");
         end
      endrule
      
      rule doResp if ( tagQ.first() == fromInteger(i));
         let data = dataQ.first;
         resps[i].enq(data);
         tagQ.deq();
         dataQ.deq();
      endrule
   end



   Vector#(2, DRAMServer) ds;
   for (Integer i = 0; i < 2; i = i + 1)
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
