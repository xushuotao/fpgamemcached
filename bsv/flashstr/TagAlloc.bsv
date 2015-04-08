import ControllerTypes::*;
import ClientServer::*;
import Connectable::*;

import FIFOF::*;
import FIFO::*;
import GetPut::*;
import Vector::*;
import MyArbiter::*;



interface TagServer;
   interface Get#(TagT) reqTag;
   interface Put#(TagT) retTag;
endinterface

interface TagClient;
   interface Put#(TagT) reqTag;
   interface Get#(TagT) retTag;
endinterface


module mkTagAlloc(TagServer);
   FIFO#(TagT) freeTagQ <- mkSizedFIFO(valueOf(NumTags));
   
   Reg#(TagT) newTag <- mkReg(0);
   Reg#(Bool) initialized <- mkReg(False);
   
   interface Get reqTag;
      method ActionValue#(TagT) get;
         TagT nextTag = ?;
         if ( !initialized ) begin
            nextTag = newTag;
            newTag <= newTag + 1;
            if ( newTag + 1 == -1 )
               initialized <= True;
         end
         else
            nextTag <- toGet(freeTagQ).get;
      
         $display("Next tag is %d", nextTag);
   
         return nextTag;
      endmethod
   endinterface
      
   interface Put retTag = toPut(freeTagQ);
   
endmodule


interface TagAllocArbiterIFC#(numeric type numServers);
   interface Vector#(numServers, TagServer) servers;
   interface TagClient client;
endinterface

module mkTagAllocArbiter(TagAllocArbiterIFC#(numServers));
   Vector#(numServers, FIFOF#(TagT)) reqTagQs <- replicateM(mkFIFOF);
   Vector#(numServers, FIFOF#(TagT)) retTagQs <- replicateM(mkFIFOF);
   
   FIFOF#(TagT) newTagQ <- mkFIFOF();
   FIFO#(TagT) usedTagQ <- mkFIFO();
   
   Arbiter_IFC#(numServers) arbiter <- mkArbiter(False);

   for (Integer i = 0; i < valueOf(numServers); i = i + 1) begin
      rule doReqs_0 if (reqTagQs[i].notFull && newTagQ.notEmpty());
         arbiter.clients[i].request;
      endrule
      
      rule doReqs_1 if (arbiter.grant_id == fromInteger(i));
         let newTag <- toGet(newTagQ).get();
         reqTagQs[i].enq(newTag);
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
                  interface reqTag = toGet(reqTagQs[i]);
                  interface retTag = toPut(retTagQs[i]);
               endinterface);
   
   interface servers = ts;
   
   interface TagClient client;
      interface Get retTag = toGet(usedTagQ);
      interface Put reqTag = toPut(newTagQ);
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
