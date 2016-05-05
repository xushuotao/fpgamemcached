import FIFO::*;
import BRAM::*;
import ControllerTypes::*;
import ProtocolHeader::*;

interface KVStoreCompletionBuffer;
   interface Put#(Tuple3#(Bit#(8), Bit#(32), TagT)) writeRequest;
   interface Put#(Bit#(128)) inPipe;
   interface Put#(Tuple2#(TagT, Bool)) readRequest;
   interface Get#(Tuple2#(Bit#(8), Bit#(32))) readResponse;
   interface Get#(Bit#(128)) outPipe;
   //interface Get#(TagT) tagAck;
endinterface

(*synthesize*)
module mkKVStoreCompletionBuffer(KVStoreCompletionBuffer);
   
   BRAM_Configure cfg = defaultValue;
   BRAM2Port#(TagT, Tuple2#(Bit#(8), Bit#(32))) statusLUT <- mkBRAM2Server(cfg);
   BRAM2Port#(Bit#(11), Bit#(128)) keyBuf <- mkBRAM2Server(cfg);
   
   FIFO#(Tuple3#(Bit#(8), Bit#(32), TagT)) wrReqQ <- mkFIFO;
   FIFO#(Bit#(128)) inQ <- mkFIFO;
   
   Reg#(Bit#(8)) keyCnt_Wr <- mkReg(0);
   rule doWrReq;
      let v = wrReqQ.first();
      Bit#(9) keylen = extend(tpl_1(v));
      let opaque = tpl_2(v);
      let tag = tpl_3(v);
      

      $display("%m, keyCnt_wr = %d, keylen = %d, tag = %d", keyCnt_Wr, keylen, tag);
      statusLUT.portA.request.put(BRAMRequest{write: True,
                                              responseOnWrite: False,
                                              address:tag,
                                              datain: tuple2(truncate(keylen), opaque)});
      Bit#(128) keyToken = ?;
      if ( keylen > 0 ) begin
         keyToken <- toGet(inQ).get();
         keyBuf.portA.request.put(BRAMRequest{write: True,
                                              responseOnWrite: False,
                                              address:(extend(tag)<<4) + extend(keyCnt_Wr>>4),
                                              datain: keyToken});
      end
      
      if ( extend(keyCnt_Wr) + 16 < keylen ) begin
         keyCnt_Wr <= keyCnt_Wr + 16;
      end
      else begin
         wrReqQ.deq();
         keyCnt_Wr <= 0;
      end
   endrule
   
   FIFO#(Tuple2#(TagT,Bool)) rdReqQ <- mkFIFO();
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

      let v = rdReqQ.first();
      let tag = tpl_1(v);
      let bypass = tpl_2(v);
      Bit#(9) keylen = extend(keylenQ.first());
      $display("%m: completion buffer got read req tag = %d, keyCnt_Rd = %d, keylen = %d, bypass = %d", tag, keyCnt_Rd, keylen, bypass);
      if ( keylen > 0 && (!bypass) )
         keyBuf.portB.request.put(BRAMRequest{write: False,
                                              responseOnWrite: False,
                                              address:(extend(tag)<<4) + extend(keyCnt_Rd>>4),
                                              datain: ?});

      if ( extend(keyCnt_Rd) + 16 < keylen && (!bypass)) begin
         keyCnt_Rd <= keyCnt_Rd + 16;
      end
      else begin
         rdReqQ.deq();
         keylenQ.deq();
         keyCnt_Rd <= 0;
         //tagAckQ.enq(tag);
      end
   endrule

   
   interface Put writeRequest = toPut(wrReqQ);
   interface Put inPipe = toPut(inQ);
   
   interface Put readRequest;
      method Action put (Tuple2#(TagT, Bool) v);
         let tag = tpl_1(v);
         $display("%m: completion buffer got read req tag = %d, bypass = %d", tag, tpl_2(v));
         rdReqQ.enq(v);
         statusLUT.portB.request.put(BRAMRequest{write: False,
                                                 responseOnWrite: False,
                                                 address: tag,
                                                 datain: ?});

       endmethod
    endinterface

   interface Get readResponse = toGet(readResponseQ);
   interface Get outPipe = keyBuf.portB.response;
endmodule
   
