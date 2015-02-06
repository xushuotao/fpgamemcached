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
   FIFO#(Bit#(64)) keyBuf <- mkBypassFIFO;
   
   //Reg#(StateKeyWriter) state <- mkReg(Idle);
   //FIFO#(StateKeyWriter) nextStateQ <- mkFIFO();
      
   rule writeKeys_1;
      $display("put keytokens in to depacket inpipe");
      let v <- toGet(keyBuf).get();
      depacketEng_key.inPipe.put(v);
   endrule
 
   Reg#(Bit#(8)) keyCnt <- mkReg(0);
   FIFO#(PhyAddr) addrQ <- mkFIFO();
   //FIFO#(Bit#(8)) keyMaxQ <- mkFIFO();
   FIFO#(Tuple3#(Bit#(8),StateKeyWriter, Bit#(16))) keyMaxQ <- mkFIFO();
   
   /*rule doSplit (state == Idle);
      let v <- toGet(nextStateQ).get();
      state <= v;
   endrule*/
   
   rule doWrite (tpl_2(keyMaxQ.first()) == DoWrite);//(state == DoWrite);
      let keyMax = tpl_1(keyMaxQ.first());
      let baseAddr = addrQ.first();
      let wrAddr = baseAddr + extend({keyCnt, 6'b0});
      if ( keyCnt + 1 < keyMax) begin
         keyCnt <= keyCnt + 1;
      end
      else begin
         keyMaxQ.deq;
         addrQ.deq;
         keyCnt <= 0;
         //state <= Idle;
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
      $display("KeyWriter write keys, reqCnt = %d, wrAddr = %d, wrVal = %h, bytes = %d", tpl_3(keyMaxQ.first()), wrAddr, v, fromInteger(valueOf(LineBytes)));
      dramEP.request.put(HtDRAMReq{rnw: False,
                                   addr:wrAddr, 
                                   data:zeroExtend(v),
                                   numBytes:fromInteger(valueOf(LineBytes))});
      //end
   endrule

   rule doBypass (tpl_2(keyMaxQ.first()) == ByPass);//(state == ByPass);
      let keyMax = tpl_1(keyMaxQ.first());
      if ( keyCnt + 1 < keyMax) begin
         keyCnt <= keyCnt + 1;
      end
      else begin
         keyMaxQ.deq;
         keyCnt <= 0;
         //state <= Idle;
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
   
      depacketEng_key.start(extend(numKeytokens));
      
      StateKeyWriter nextState = ?;
      
      if (args.byPass) begin
         //nextStateQ.enq(ByPass);
         //state <= ByPass;
         nextState = ByPass;
         dramEP.start(args.hv, args.idx, 0);
      end
      else begin
         if (args.cmpMask != 0) begin
            //nextStateQ.enq(ByPass);
            //state <= ByPass;
            nextState = ByPass;
            dramEP.start(args.hv, args.idx, 0);
         end
         else begin
            addrQ.enq(args.keyAddr);
            dramEP.start(args.hv, args.idx, extend(args.keyNreq));
            //state <= DoWrite;
            nextState = DoWrite;
            //nextStateQ.enq(DoWrite);
         end
      end

      keyMaxQ.enq(tuple3(args.keyNreq, nextState, reqCnt));
   endmethod
  
   interface Put inPipe = toPut(keyBuf);

endmodule
