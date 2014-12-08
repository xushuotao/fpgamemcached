import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import GetPut::*;
import Vector::*;

import Serializer::*;
import HtArbiterTypes::*;
import HtArbiter::*;
import HashtableTypes::*;

typedef enum {Idle, DoWrite, ByPass} StateKeyWriter deriving (Eq, Bits);

interface KeyWriterIfc;
   method Action start(KeyWrParas hdrRdParas);
   interface Put#(Bit#(64)) inPipe;
endinterface

module mkKeyWriter#(DRAMWriteIfc dramEP)(KeyWriterIfc);
   //DepacketIfc#(64, LineWidth, HeaderRemainderSz) depacketEng_key <- mkDepacketEngine();
   DeserializerIfc depacketEng_key <- mkDeserializer();
   FIFO#(Bit#(64)) keyBuf <- mkFIFO;
   
   Reg#(StateKeyWriter) state <- mkReg(Idle);
   FIFO#(StateKeyWriter) nextStateQ <- mkFIFO();
      
   rule writeKeys_1;
      $display("put keytokens in to depacket inpipe");
      let v <- toGet(keyBuf).get();
      depacketEng_key.inPipe.put(v);
   endrule
 
   Reg#(Bit#(8)) keyCnt <- mkReg(0);
   FIFO#(PhyAddr) addrQ <- mkFIFO();
   FIFO#(Bit#(8)) keyMaxQ <- mkFIFO();
   
   rule doSplit (state == Idle);
      let v <- toGet(nextStateQ).get();
      state <= v;
   endrule
   
   rule doWrite (state == DoWrite);
      let keyMax = keyMaxQ.first();
      let baseAddr = addrQ.first();
      let wrAddr = baseAddr + extend({keyCnt, 6'b0});
      if ( keyCnt + 1 < keyMax) begin
         keyCnt <= keyCnt + 1;
      end
      else begin
         keyMaxQ.deq;
         addrQ.deq;
         keyCnt <= 0;
         state <= Idle;
      end
      
      let v <- depacketEng_key.outPipe.get();
      /*if (keyCnt == 0) begin
         $display("wrAddr = %d, wrVal = %h, bytes = %d", wrAddr + fromInteger(valueOf(HeaderRemainderBytes)), v, fromInteger(valueOf(HeaderResidualBytes)));
         dramEP.request.put(HtDRAMReq{rnw: False,
                                      addr:wrAddr + fromInteger(valueOf(HeaderRemainderBytes)), 
                                      data:zeroExtend(v)>>fromInteger(valueOf(HeaderRemainderSz)),
                                      numBytes:fromInteger(valueOf(HeaderResidualBytes))});
         end
      else begin*/
      $display("wrAddr = %d, wrVal = %h, bytes = %d", wrAddr, v, fromInteger(valueOf(LineBytes)));
      dramEP.request.put(HtDRAMReq{rnw: False,
                                   addr:wrAddr, 
                                   data:zeroExtend(v),
                                   numBytes:fromInteger(valueOf(LineBytes))});
      //end
   endrule

   rule doBypass (state == ByPass);
      let keyMax = keyMaxQ.first();
      if ( keyCnt + 1 < keyMax) begin
         keyCnt <= keyCnt + 1;
      end
      else begin
         keyMaxQ.deq;
         keyCnt <= 0;
         state <= Idle;
      end
      let v <- depacketEng_key.outPipe.get();
      $display("KeyWriter Bypassing Keys, value = %h", v);
   endrule
   
   Reg#(Bit#(16)) reqCnt <- mkReg(0);
   
   method Action start(KeyWrParas args);
      Bit#(8) numKeytokens;
      //$display("Keywriter starts, cmpMask = %b, reqCnt = %d", args.cmpMask, reqCnt);
      $display("Keywriter starts: keyAddr = %d, keyNreq = %d, cmpMask = %b, idleMask = %b, reqCnt = %d", args.keyAddr, args.keyNreq, args.cmpMask, args.idleMask, reqCnt);
      reqCnt <= reqCnt + 1;
      if ( (args.keyLen & 7) == 0 ) begin
         numKeytokens = args.keyLen >> 3;
      end
      else begin
         numKeytokens = (args.keyLen >> 3) + 1;
      end
   
      depacketEng_key.start(numKeytokens);
   
      if (args.cmpMask != 0) begin
         nextStateQ.enq(ByPass);
         dramEP.start(args.hv, args.idx, 0);
      end
      else begin
         addrQ.enq(args.keyAddr);
         dramEP.start(args.hv, args.idx, extend(args.keyNreq));
         nextStateQ.enq(DoWrite);
      end

      keyMaxQ.enq(args.keyNreq);
   endmethod
  
   interface Put inPipe = toPut(keyBuf);

endmodule
