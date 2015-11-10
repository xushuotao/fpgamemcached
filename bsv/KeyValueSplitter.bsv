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
   interface Put#(Bit#(128)) keyValInPipe;
   interface Put#(Bit#(128)) keyInPipe;
   interface Get#(Bit#(128)) outPipe;
endinterface

(*synthesize*)
module mkKeyValueSplitter(KeyValueSplitter);
   FIFO#(Tuple2#(Bit#(8), Bit#(32))) reqQ <- mkSizedFIFO(numStages);
   FIFO#(Bool) respQ <- mkSizedFIFO(numStages);
   
   FIFO#(Bit#(128)) kvQ <- mkFIFO;
   FIFO#(Bit#(128)) keyQ <- mkFIFO;
   FIFO#(Bit#(128)) valQ <- mkFIFO;
      
   ByteAlignIfc#(Bit#(128), Bool) valAlign <- mkByteAlignCombinational;
   
   Reg#(Bit#(32)) byteCnt <- mkReg(0);
   Reg#(Bool) matchReg <- mkReg(True);
   
   function Bit#(8) expand(Bit#(1) v);
      Bit#(8) retval = 0;
      if ( v == 1) 
         retval = -1;
      return retval;
   endfunction

   Reg#(Bit#(32)) reqCnt <- mkReg(0);
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
         $display("%m:: reqCnt = %d, keyValFromBluecache = %h, keyvalFromRequest = %h, matchReg = %d", reqCnt, keyValToken, keyTokenSrc, matchReg);
         if ( byteCnt + 16 < extend(keylen) ) begin
            matchReg <= matchReg && (keyValToken == keyTokenSrc);
         end
         else if ( byteCnt + 16 >= extend(keylen) ) begin
            Bit#(16) bytemask = (1 << (keylen -  truncate(byteCnt)) )  - 1;
            Vector#(16, Bit#(8)) mask = map(expand, unpack(bytemask));
            let cmpToken = keyValToken & pack(mask);
            Bool retval = matchReg && (cmpToken == keyTokenSrc);
            respQ.enq(retval);
            matchReg <= True;
            $display("%m:: reqCnt = %d, retval = %d", reqCnt, retval);
            valAlign.align(truncate(keylen), extend(bodylen)-extend(keylen), retval);
            if ( byteCnt + 16 > extend(keylen))
               valAlign.inPipe.put(keyValToken);
         end
      end
   
      if ( byteCnt + 16 < extend(bodylen) ) begin
         byteCnt <= byteCnt + 16;
      end
      else begin
         reqCnt <= reqCnt + 1;
         byteCnt <= 0;
         reqQ.deq();
      end
   endrule
   
   rule filterVal;

      let d <- valAlign.outPipe.get();
      //$display(fshow(d));
      if ( tpl_3(d) )
         valQ.enq(tpl_1(d));
   endrule
   
   interface Server server = toServer(reqQ, respQ);
   
   interface Put keyValInPipe = toPut(kvQ);
   interface Put keyInPipe = toPut(keyQ);
   interface Get outPipe = toGet(valQ);
         
endmodule
