import FIFOF::*;
import Vector::*;
import GetPut::*;
import Pipe::*;

import MyArbiter::*;

interface PipeOutSwitch#(numeric type n, type t);
   interface Vector#(n, PipeIn#(t)) inPipes;
   interface PipeOut#(t) outPipe;
endinterface

module mkPipeOutSwitch#(Bool fixed)(PipeOutSwitch#(n, t)) provisos (Bits#(t, ts));
   Vector#(n, FIFOF#(t)) reqQs <- replicateM(mkFIFOF);
   FIFOF#(t) respQ <- mkFIFOF;
   
   Arbiter_IFC#(n) arbiter <- mkArbiter(fixed);
   
   for (Integer i = 0; i < valueOf(n); i=i+1) begin
      rule doArbReq if (reqQs[i].notEmpty);
         arbiter.clients[i].request();
      endrule
      
      rule doArbResp if (arbiter.clients[i].grant);
         let v <- toGet(reqQs[i]).get;
         respQ.enq(v);
      endrule
   end
   
   interface Vector inPipes  = map(toPipeIn,reqQs);
   interface PipeOut outPipe = toPipeOut(respQ);
endmodule
