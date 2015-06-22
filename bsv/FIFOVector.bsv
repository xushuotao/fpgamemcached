import BRAM::*;
//import Ehr::*;
import GetPut::*;
import ClientServer::*;
import FIFO::*;
import Vector::*;


interface FIFOVector#(numeric type n, type t, numeric type depth);
   method Action enq(Bit#(TLog#(n)) tag, t data);
   interface Server#(Bit#(TLog#(n)), t) deqServer;
endinterface

module mkBRAMFIFOVector(FIFOVector#(n, t, depth))
   provisos(Bits#(t, tSz),
            Add#(depth, 1, depth1),
            Log#(depth1, sz),
            Add#(sz, 1, sz1),
            Log#(n, nlog),
            Log#(depth, depthlog));
   
   Integer depthi = valueOf(depth);
   Bit#(sz1) nb = fromInteger(depthi);
   Bit#(sz1) n2 = 2*nb;

   Vector#(n,Reg#(Bit#(sz1))) enqP <- replicateM(mkReg(0));
   Vector#(n,Reg#(Bit#(sz1))) deqP <- replicateM(mkReg(0));
   
   BRAM2Port#(Bit#(TAdd#(nlog, depthlog)), t) fifostore <- mkBRAM2Server(defaultValue);
   FIFO#(Bit#(TLog#(n))) deqReqQ <- mkFIFO();
   
   Vector#(n, Bit#(sz1)) cnt;
   //Vector#(n, Bit#(sz2)) cnt1;
   for (Integer i = 0; i < valueOf(n); i = i + 1) begin
      cnt[i] = enqP[i] >= deqP[i]? enqP[i] - deqP[i]:(enqP[i]%nb + nb) - deqP[i]%nb;
   end
   
   function Bool notFull(Bit#(nlog) tag);
      return cnt[tag] < nb;
   endfunction
   
   function Bool notEmpty(Bit#(nlog) tag);
      return cnt[tag] != 0;
   endfunction
   
   FIFO#(Bool) validQ <- mkFIFO();
   rule doDeq if (cnt[0] != 0);//( notEmpty(deqReqQ.first) );
      let idx <- toGet(deqReqQ).get;
      //let idx = deqReqQ.first;
      //if ( notEmpty(idx) ) begin
      fifostore.portB.request.put(BRAMRequest{write:False,
                                              responseOnWrite: False,
                                              address: (extend(tag) << valueOf(nlog)) + extend(depP[tag]%nb),
                                              data: ?});
      depP[tag] <= (depP[tag] + 1)%n2;
      //deqReq.deq();
         //validQ.enq(True);
      //end
      //else begin
         //validQ.enq(False);
      //end
   endrule

   
   
   method Action enq(Bit#(TLog#(n)) tag, t data) if (cnt[tag] < nb);
      enqP[tag] <= (enqP[tag] + 1)%n2;
      fifostore.portA.request.put(BRAMRequest{write:True,
                                              resposeOnWrite: False,
                                              address: (extend(tag) << valueOf(nlog)) + extend(enqP[tag]%nb),
                                              data: t});
   endmethod
   
   interface Server deqServer;
      interface Put request=toPut(deqReqQ);
      interface Get response=fifostore.portB.response;
   endinterface
      /*
         method ActionValue#(Maybe#(t)) get();
            let valid <- toGet(validQ).get();
            Maybe#(t) retval = tagged Invalid;
            if ( valid ) begin
               let v <- fifostore.portB.response.get();
               retval = tagged Valid v;
            end
            return retval;
         endmethod
      endinterface*/
endmodule
   
