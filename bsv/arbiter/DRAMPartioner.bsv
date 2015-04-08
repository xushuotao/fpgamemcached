import ClientServer::*;
import GetPut::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import MyArbiter::*;
import DRAMArbiterTypes::*;
import DRAMController::*;

interface DRAMSegmentIfc#(numeric type numServers);
   interface Vector#(numServers, DRAMServer) dramServers;
   interface Vector#(numServers, Put#(Bit#(64))) initialize;
   interface DRAMClient dramClient;
endinterface


//typedef 30 LogMaxAddr;

module mkDRAMSegments(DRAMSegmentIfc#(numServers));
   
   //Integer addrSeg = valueOf(TExp#(TSub#(LogMaxAddr,TLog#(2))));
   Vector#(TAdd#(numServers,1), Reg#(Bit#(64))) addrDelim <- replicateM(mkRegU());
   
   
   Arbiter_IFC#(numServers) arbiter <- mkArbiter(False);

   Vector#(numServers, FIFOF#(DRAMReq)) reqs<- replicateM(mkFIFOF);
   Vector#(numServers, FIFO#(Bit#(512))) resps<- replicateM(mkFIFO);
   
   
   FIFO#(DRAMReq) cmdQ <- mkFIFO;
   FIFO#(Bit#(512)) dataQ <- mkFIFO;
   
   FIFO#(Bit#(TLog#(numServers))) tagQ <- mkSizedFIFO(32);
      
   for (Integer i = 0; i < numServers; i = i + 1) begin
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



   Vector#(numServers, DRAMServer) ds;
   for (Integer i = 0; i < numServers; i = i + 1)
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
