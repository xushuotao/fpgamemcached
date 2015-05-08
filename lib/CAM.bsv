import FIFO::*;
import GetPut::*;
import ClientServer::*;
import ClientServerHelper::*;
import Vector::*;
import Ehr::*;

interface CAM#(numeric type n, type idx_t, type dta_t);
   interface Put#(Tuple2#(idx_t,dta_t)) writePort;
   interface Server#(idx_t, Maybe#(dta_t)) readPort;
endinterface

module mkSnapCAM(CAM#(n, idx_t, dta_t)) provisos(Eq#(idx_t),  Add#(TExp#(TLog#(n)), 0, n), Bits#(idx_t, idxSz), Bits#(dta_t, dtaSz));
   Vector#(n, Reg#(Bool)) valids <- replicateM(mkReg(False));
   Vector#(n, Reg#(idx_t)) contents <- replicateM(mkRegU);
   //Vector#(n, Reg#(TLog#(n)) data_idx <- replicate
   Vector#(n, Reg#(dta_t)) data <- replicateM(mkRegU);
   FIFO#(Bit#(TLog#(n))) freeidxQ <- mkSizedFIFO(valueOf(n));
   
   Reg#(Bool) init <- mkReg(False);
   Reg#(Bit#(TLog#(n))) cnt <- mkReg(0);

   FIFO#(idx_t) rdReqQ <- mkFIFO;
   FIFO#(Maybe#(Bit#(TLog#(n)))) immQ <- mkFIFO;
   FIFO#(Maybe#(dta_t)) respQ <- mkFIFO;   

   rule doInit if (!init);
      if ( cnt + 1 == 0 ) begin
         init <= True;
      end
      
      cnt <= cnt + 1;
      freeidxQ.enq(cnt);
   endrule
   
   rule doReadReq if (init);
      let v <- toGet(rdReqQ).get();
      Maybe#(Bit#(TLog#(n))) ret = tagged Invalid;
      for(Integer i = 0; i < valueOf(n); i = i + 1) begin
         if( v == contents[i] && valids[i] ) begin
            ret = tagged Valid fromInteger(i);
            valids[i] <= False;
         end
      end
      immQ.enq(ret);
   endrule
   
   rule doReadResp;
      let v <- toGet(immQ).get();
      if ( isValid(v) ) begin
         let idx = fromMaybe(?, v);
         freeidxQ.enq(idx);
         respQ.enq(tagged Valid data[idx]);
      end
      else begin
         respQ.enq(tagged Invalid);
      end
   endrule
   
   FIFO#(Tuple2#(idx_t, dta_t)) wrReqQ <- mkFIFO();
   rule doWriteReq if (init);
      let v <- toGet(wrReqQ).get();
      let idx <- toGet(freeidxQ).get();
      valids[idx] <= True;
      contents[idx] <= tpl_1(v);
      //immQ_wr.enq(tuple2(enqP[1]%nb, tpl_2(v)));
      data[idx] <= tpl_2(v);
   endrule
      
   
   interface Put writePort = toPut(wrReqQ);
   
   interface Server readPort;
      interface Put request = toPut(rdReqQ);
   
      interface Get response = toGet(respQ);
   endinterface

   
endmodule

//write is nonblocking: when cam is full, the oldest item is overwritten
module mkNonBlkCAM(CAM#(n, idx_t, dta_t)) provisos(Eq#(idx_t), Add#(n, 1, n1), Log#(n1, sz), Add#(sz, 1, sz1),Bits#(idx_t, idxSz), Bits#(dta_t, dtaSz));
   Integer ni = valueOf(n);
   
   Bit#(sz1) nb = fromInteger(ni);
   Bit#(sz1) n2 = 2*nb;
   Vector#(n, Reg#(Bool)) valids <- replicateM(mkReg(False));
   Vector#(n, Reg#(idx_t)) contents <- replicateM(mkRegU);
   //Vector#(n, Reg#(TLog#(n)) data_idx <- replicate
   Vector#(n, Reg#(dta_t)) data <- replicateM(mkRegU);

   Ehr#(2,Bit#(sz1)) enqP <- mkEhr(0);
   Reg#(Bit#(sz1)) deqP <- mkReg(0);
   
   
   Bit#(sz1) cnt0 = enqP[0] >= deqP? enqP[0] - deqP: (enqP[0]%nb + nb) - deqP%nb;
   Bit#(sz1) cnt1 = enqP[1] >= deqP? enqP[1] - deqP: (enqP[1]%nb + nb) - deqP%nb;
   
   FIFO#(Maybe#(Bit#(sz1))) immQ <- mkFIFO;
   FIFO#(Maybe#(dta_t)) respQ <- mkFIFO;   
   
   rule delEntry if ( cnt0 > nb );
      deqP <= (deqP + 1)%n2;
   endrule
   
   rule doRead;
      let v <- toGet(immQ).get();
      if ( isValid(v) ) begin
         respQ.enq(tagged Valid data[fromMaybe(?, v)]);
      end
      else begin
         respQ.enq(tagged Invalid);
      end
   endrule

   FIFO#(Tuple2#(Bit#(sz1), dta_t)) immQ_wr <- mkFIFO;
   
   rule doWrite;
      let v <- toGet(immQ_wr).get();
      data[tpl_1(v)] <= tpl_2(v);
   endrule
      

   interface Put writePort;
      method Action put(Tuple2#(idx_t, dta_t) v);
         valids[enqP[1]%nb] <= True;
         contents[enqP[1]%nb] <= tpl_1(v);
         //data[enqP[1]%nb] <= tpl_2(v);
         immQ_wr.enq(tuple2(enqP[1]%nb, tpl_2(v)));
         enqP[1] <= (enqP[1] + 1) % n2;
      endmethod
   endinterface
   
   interface Server readPort;
      interface Put request;
         method Action put(idx_t v);
            //Maybe#(dta_t) ret = tagged Invalid;
            Maybe#(Bit#(sz1)) ret = tagged Invalid;
            for(Bit#(sz1) i = 0; i < nb; i = i + 1)
               begin
                  let ptr = (deqP + i)%nb;
                  if( v == contents[ptr] && valids[ptr] && i < cnt1) begin
                     ret = tagged Valid ptr;
                     valids[ptr] <= False;
                  end
               end
            immQ.enq(ret);
         endmethod
      endinterface
   
      interface Get response = toGet(respQ);
   endinterface
endmodule
