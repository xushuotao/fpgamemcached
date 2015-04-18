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

//write is nonblocking: when cam is full, the oldest item is overwritten
module mkNonBlkCAM(CAM#(n, idx_t, dta_t)) provisos(Eq#(idx_t), Log#(n,lgn), Add#(lgn,1, sz), Add#(sz, 1, sz1), Bits#(idx_t, idxSz), Bits#(dta_t, dtaSz));
   Integer ni = valueOf(n);
   
   Bit#(sz1) nb = fromInteger(ni);
   Bit#(sz1) n2 = 2*nb;
   Vector#(n, Reg#(idx_t)) idx <- replicateM(mkRegU);
   Vector#(n, Reg#(dta_t)) data <- replicateM(mkRegU);

   Ehr#(2,Bit#(sz1)) enqP <- mkEhr(0);
   Reg#(Bit#(sz1)) deqP <- mkReg(0);
   
   
   Bit#(sz1) cnt0 = enqP[0] >= deqP? enqP[0] - deqP: (enqP[0]%nb + nb) - deqP%nb;
   Bit#(sz1) cnt1 = enqP[1] >= deqP? enqP[1] - deqP: (enqP[1]%nb + nb) - deqP%nb;
   
   FIFO#(Maybe#(dta_t)) respQ <- mkFIFO;   
   
   rule delEntry if ( cnt0 > nb );
      deqP <= (deqP + 1)%n2;
   endrule

   interface Put writePort;
      method Action put(Tuple2#(idx_t, dta_t) v);
         idx[enqP[1]%nb] <= tpl_1(v);
         data[enqP[1]%nb] <= tpl_2(v);
         enqP[1] <= (enqP[1] + 1) % n2;
      endmethod
   endinterface
   
   interface Server readPort;
      interface Put request;
         method Action put(idx_t v);
            Maybe#(dta_t) ret = tagged Invalid;
            for(Bit#(sz1) i = 0; i < nb; i = i + 1)
               begin
                  let ptr = (deqP + i)%nb;
                  if( v == idx[ptr] && i < cnt1)
                     ret = tagged Valid data[ptr];
               end
            respQ.enq(ret);
         endmethod
      endinterface
   
      interface Get response = toGet(respQ);
   endinterface
endmodule
