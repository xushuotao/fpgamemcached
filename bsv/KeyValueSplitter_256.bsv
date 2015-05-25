import ClientServer::*;
import GetPut::*;
import ClientServerHelper::*;
import MemcachedTypes::*;
import Align::*;
import ParameterTypes::*;

import FIFO::*;
import SpecialFIFOs::*;
import Vector::*;

interface KeyValueSplitter;
   interface Server#(Tuple2#(Bit#(8), Bit#(32)), Bool) server;
   interface Put#(Bit#(256)) keyValInPipe;
   interface Put#(Bit#(256)) keyInPipe;
   interface Get#(Bit#(128)) outPipe;
endinterface

(*synthesize*)
module mkKeyValueSplitter(KeyValueSplitter);
   FIFO#(Tuple2#(Bit#(8), Bit#(32))) reqQ <- mkSizedFIFO(numStages);
   FIFO#(Bool) respQ <- mkSizedFIFO(numStages);
   
   FIFO#(Bit#(256)) kvQ <- mkFIFO;
   FIFO#(Bit#(256)) keyQ <- mkFIFO;
   FIFO#(Bit#(128)) valQ <- mkFIFO;
      
   ByteAlignIfc#(Bit#(256), Bool) valAlign <- mkByteAlignCombinational;
   
   Reg#(Bit#(32)) byteCnt <- mkReg(0);
   Reg#(Bool) matchReg <- mkReg(True);
   
   function Bit#(8) expand(Bit#(1) v);
      Bit#(8) retval = 0;
      if ( v == 1) 
         retval = -1;
      return retval;
   endfunction

   Reg#(Bit#(32)) reqCnt <- mkReg(0);
   
   FIFO#(Bit#(32)) valMaxQ <- mkFIFO();
   rule doReq;
      let req = reqQ.first();
      let keylen = tpl_1(req);
      let bodylen = tpl_2(req);

      let keyValToken <- toGet(kvQ).get();
      $display("%m:: reqcnt = %d, byteCnt = %d, keylen = %d, bodylen = %d, keyToken = %h", reqCnt, byteCnt, keylen, bodylen, keyValToken);
      if ( byteCnt >= extend(keylen) ) begin
         valAlign.inPipe.put(keyValToken);
      end
      else begin
         let keyTokenSrc <- toGet(keyQ).get();
         if ( byteCnt + 32 < extend(keylen) ) begin
            matchReg <= matchReg && (keyValToken == keyTokenSrc);
         end
         else if ( byteCnt + 32 >= extend(keylen) ) begin
            Bit#(32) bytemask = (1 << (keylen -  truncate(byteCnt)) )  - 1;
            Vector#(32, Bit#(8)) mask = map(expand, unpack(bytemask));
            let cmpToken = keyValToken & pack(mask);
            Bool retval = matchReg && (cmpToken == keyTokenSrc);
            respQ.enq(retval);
            matchReg <= True;
            $display("%m:: reqCnt = %d, retval = %d", reqCnt, retval);
            valAlign.align(truncate(keylen), extend(bodylen)-extend(keylen), retval);
            valMaxQ.enq(extend(bodylen)-extend(keylen));
            if ( byteCnt + 32 > extend(keylen))
               valAlign.inPipe.put(keyValToken);
         end
      end
   
      if ( byteCnt + 32 < extend(bodylen) ) begin
         byteCnt <= byteCnt + 32;
      end
      else begin
         reqCnt <= reqCnt + 1;
         byteCnt <= 0;
         reqQ.deq();
      end
   endrule
   
   FIFO#(Tuple#(Bit#(256), Bit#(6), Bool)) valDta <- mkFIFO();
   mkConnction(toPut(valDta), valAlign.outPipe);
   
   Reg#(Bit#(32)) valTokenCnt <- mkReg(0);
   rule filterVal;
      let nBytes = valMaxQ.first();
      Bit#(5) residual= truncate(nBytes);
      let tokenMax = nBytes >> 5;
      if (residual!=0) tokenMax = tokenMax + 1;
      
      Bool laskToken = False;
      if ( valTokenCnt + 1 == tokenMax ) begin
         lastToken = True;
         valMaxQ.deq();
         valTokenCnt <= 0;
      end
      else begin
         valTokenCnt <= valTokenCnt + 1;
      end
         
      let d = valDta.first();
      let data = tpl_1(d);
      let success = tpl_3(d);
      Vector#(2, Bit#(128)) dtaV = pack(data);
      if ( success ) begin
         valQ.enq(dtaV[valTokenCnt[0]]);
      end
      
      if ( valTokenCnt[1] == 1 || lastToken)begin
         valDta.deq();
      end
   endrule
   
   interface Server server = toServer(reqQ, respQ);
   
   interface Put keyValInPipe = toPut(kvQ);
   interface Put keyInPipe = toPut(keyQ);
   interface Get outPipe = toGet(valQ);
         
endmodule
