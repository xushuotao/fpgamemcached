import FIFO::*;
import BRAM::*;
import ControllerTypes::*;
import ProtocolHeader::*;

interface KVStoreCompletionBuffer;
   interface Put#(Tuple3#(Bit#(8), Bit#(32), TagT)) writeRequest;
   interface Put#(Bit#(128)) inPipe;
   interface Put#(TagT) readRequest;
   interface Get#(Tuple2#(Bit#(8), Bit#(32))) readResponse;
   interface Get#(Bit#(256)) outPipe;
   //interface Get#(TagT) tagAck;
endinterface

module mkKVStoreCompletionBuffer(KVStoreCompletionBuffer);
   
   BRAM_Configure cfg = defaultValue;
   BRAM2Port#(TagT, Tuple2#(Bit#(8), Bit#(32))) statusLUT <- mkBRAM2Server(cfg);
   BRAM2Port#(Bit#(10), Bit#(256)) keyBuf <- mkBRAM2Server(cfg);
   
   FIFO#(Tuple3#(Bit#(8), Bit#(32), TagT)) wrReqQ <- mkFIFO;
   FIFO#(Bit#(128)) inQ <- mkFIFO;
   
   Reg#(Bit#(8)) keyCnt_Wr <- mkReg(0);
   
   FIFO#(Bit#(256)) keyTokenQ <- mkFIFO();
   
   FIFO#(Bit#(4)) tokenMaxQ <- mkFIFO();
   Reg#(Bit#(3)) keyTokenCnt <- mkReg(0);
   Reg#(Bit#(128)) readcache <- mkReg(0);
   rule doDes;
      let tokenMax = tokenMaxQ.first();
      let token <- toGet(inQ).get();
      Bool lastToken = False;
      if (extend(keyTokenCnt) + 1 == tokenMax) begin
         keyTokenCnt <= 0;
         tokenMaxQ.deq();
         lastToken = True;
      end
      else begin
         keyTokenCnt <= keyTokenCnt + 1;
      end
      
      if (keyTokenCnt[0] == 1) begin
         keyTokenQ.enq({token, readcache});
      end
      else begin
         if ( lastToken )
            keyToken.enq({0, token});
         else
            readcache <= token;
      end
   endrule
   
   rule doWrReq;
      let v = wrReqQ.first();
      Bit#(9) keylen = extend(tpl_1(v));
      let opaque = tpl_2(v);
      let tag = tpl_3(v);
      
      //let keyToken <- toGet(inQ).get();
      let keyToken <- toGet(keyToken).get();
      $display("%m, keyCnt_wr = %d, keylen = %d, tag = %d", keyCnt_Wr, keylen, tag);
      statusLUT.portA.request.put(BRAMRequest{write: True,
                                              responseOnWrite: False,
                                              address:tag,
                                              datain: tuple2(truncate(keylen), opaque)});
      keyBuf.portA.request.put(BRAMRequest{write: True,
                                           responseOnWrite: False,
                                           address:(extend(tag)<<3) + extend(keyCnt_Wr>>5),
                                           datain: keyToken});
      
      if ( extend(keyCnt_Wr) + 32 < keylen ) begin
         keyCnt_Wr <= keyCnt_Wr + 32;
      end
      else begin
         wrReqQ.deq();
         keyCnt_Wr <= 0;
      end
   endrule
   
   FIFO#(TagT) rdReqQ <- mkFIFO();
   FIFO#(Bit#(8)) keylenQ <- mkFIFO();
   FIFO#(Tuple2#(Bit#(8), Bit#(32))) readResponseQ <- mkFIFO;
   //FIFO#(TagT) tagAckQ <- mkFIFO();
   Reg#(Bit#(8)) keyCnt_Rd <- mkReg(0);
   rule doPreRdReq;
      let v <- statusLUT.portB.response.get();
      let keylen = tpl_1(v);
      let opaque = tpl_2(v);
      readResponseQ.enq(tuple2(keylen, opaque));
      keylenQ.enq(keylen);
   endrule
      
   rule doRdReq;
      let tag = rdReqQ.first();
      Bit#(9) keylen = extend(keylenQ.first());
      
      keyBuf.portB.request.put(BRAMRequest{write: False,
                                           responseOnWrite: False,
                                           address:(extend(tag)<<3) + extend(keyCnt_Rd>>5),
                                           datain: ?});

      if ( extend(keyCnt_Rd) + 32 < keylen ) begin
         keyCnt_Rd <= keyCnt_Rd + 32;
      end
      else begin
         rdReqQ.deq();
         keylenQ.deq();
         keyCnt_Rd <= 0;
         //tagAckQ.enq(tag);
      end
   endrule

   
   interface Put writeRequest;// = toPut(wrReqQ);
      method Action put(Bit#(8) v);
         wrReqQ.enq(v);
         let keylen = tpl_1(v);
         Bit#(3) tokenCnt = truncateLSB(keylen);
         Bit#(5) residual = truncate(keylen);
         Bit#(4) tokenMax = extend(tokenCnt);
         if ( residual != 0 )
            tokenMax = tokenMax + 1;
         tokenMaxQ.(tokenMax);
      endmethod
   endinterface
   
   interface Put inPipe = toPut(inQ);
   
   interface Put readRequest;
      method Action put (TagT v);
         $display("%m: completion buffer got read req tag = %d", v);
         rdReqQ.enq(v);
         statusLUT.portB.request.put(BRAMRequest{write: False,
                                                 responseOnWrite: False,
                                                 address: v,
                                                 datain: ?});

       endmethod
    endinterface

   interface Get readResponse = toGet(readResponseQ);
   interface Get outPipe = keyBuf.portB.response;
endmodule
   
