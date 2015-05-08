import ControllerTypes::*;
import ClientServer::*;
import Connectable::*;

import FIFOF::*;
import FIFO::*;
import GetPut::*;
import Vector::*;
import MyArbiter::*;



interface TagServer;
   interface Server#(Bit#(32), TagT) reqTag;
   interface Put#(TagT) retTag;
endinterface

interface TagClient;
   interface Client#(Bit#(32), TagT) reqTag;
   interface Get#(TagT) retTag;
endinterface


module mkTagAlloc(TagServer);
   FIFO#(Bit#(32)) reqQ <- mkFIFO;
   FIFO#(TagT) respQ <- mkFIFO;
   
   FIFO#(TagT) freeTagQ <- mkSizedFIFO(valueOf(NumTags));
   
   Reg#(TagT) newTag <- mkReg(0);
   Reg#(Bool) initialized <- mkReg(False);
   
   Reg#(Bit#(32)) tagCnt <- mkReg(0);
   rule doAllocTag;
      let numTags = reqQ.first();
      if ( tagCnt + 1 == numTags ) begin
         reqQ.deq();
         tagCnt <= 0;
      end
      else begin
         tagCnt <= tagCnt + 1;
      end
            
      TagT nextTag = ?;
      if ( !initialized ) begin
         nextTag = newTag;
         newTag <= newTag + 1;
         if ( newTag  == -1 )
            initialized <= True;
      end
      else
         nextTag <- toGet(freeTagQ).get;
      
      $display("Next tag is %d", nextTag);
      
      respQ.enq(nextTag);
   
   endrule
   
   interface Server reqTag;
      interface Put request = toPut(reqQ);
      interface Get response = toGet(respQ);
   endinterface
      
   interface Put retTag = toPut(freeTagQ);
   
endmodule


interface TagAllocArbiterIFC#(numeric type numServers);
   interface Vector#(numServers, TagServer) servers;
   interface TagClient client;
endinterface

module mkTagAllocArbiter(TagAllocArbiterIFC#(numServers));
   Vector#(numServers, FIFOF#(Bit#(32))) reqQs <- replicateM(mkFIFOF);
   FIFO#(Tuple2#(Bit#(TLog#(numServers)), Bit#(32))) reqIdQ <- mkFIFO();
   Vector#(numServers, FIFOF#(TagT)) respQs <- replicateM(mkFIFOF);
   
   Vector#(numServers, FIFOF#(TagT)) retTagQs <- replicateM(mkFIFOF);
   
   FIFO#(Bit#(32)) reqQ <- mkFIFO;
   FIFOF#(TagT) respQ <- mkFIFOF();
   FIFO#(TagT) usedTagQ <- mkFIFO();
   
   Arbiter_IFC#(numServers) arbiter <- mkArbiter(False);

   for (Integer i = 0; i < valueOf(numServers); i = i + 1) begin
      rule doReqs_0 if (reqQs[i].notEmpty());//;(reqTagQs[i].notFull && respQ.notEmpty());
         arbiter.clients[i].request;
      endrule
      
      rule doReqs_1 if (arbiter.grant_id == fromInteger(i));
         let v <- toGet(reqQs[i]).get();
         reqQ.enq(v);
         reqIdQ.enq(tuple2(fromInteger(i), v));
      endrule
      
      Reg#(Bit#(32)) tagCnt <- mkReg(0);
      rule doResp_1 if ( tpl_1(reqIdQ.first) == fromInteger(i));
         if ( tagCnt + 1 == tpl_2(reqIdQ.first) ) begin
            tagCnt <= 0;
            reqIdQ.deq();
         end
         else begin
            tagCnt <= tagCnt + 1;
         end
         let tag <- toGet(respQ).get();
         respQs[i].enq(tag);
      endrule
   end
   
   Arbiter_IFC#(numServers) arbiter_1 <- mkArbiter(False);

   for (Integer i = 0; i < valueOf(numServers); i = i + 1) begin
      rule doReqs_0_1 if (retTagQs[i].notEmpty);
         arbiter_1.clients[i].request;
      endrule
      
      rule doReqs_1_1 if (arbiter_1.grant_id == fromInteger(i));
         let usedTag <- toGet(retTagQs[i]).get();
         usedTagQ.enq(usedTag);
      endrule
   end
   
   
   Vector#(numServers, TagServer) ts;
   for (Integer i = 0; i < valueOf(numServers); i = i + 1)
      ts[i] = (interface TagServer;
                  interface Server reqTag;
                     interface Put request = toPut(reqQs[i]);
                     interface Get response = toGet(respQs[i]);
                  endinterface
                  interface Put retTag = toPut(retTagQs[i]);
               endinterface);
   
   interface servers = ts;
   
   interface TagClient client;
      interface Client reqTag;
         interface Get request = toGet(reqQ);
         interface Put response = toPut(respQ);
      endinterface
      interface Get retTag = toGet(usedTagQ);
   endinterface

endmodule


instance Connectable#(TagClient, TagServer);
   module mkConnection#(TagClient cli, TagServer ser)(Empty);
      mkConnection(cli.reqTag, ser.reqTag);
      mkConnection(cli.retTag, ser.retTag);
   endmodule
endinstance
         
instance Connectable#(TagServer, TagClient);
   module mkConnection#(TagServer ser, TagClient cli)(Empty);
      mkConnection(cli.reqTag, ser.reqTag);
      mkConnection(cli.retTag, ser.retTag);
   endmodule
endinstance
