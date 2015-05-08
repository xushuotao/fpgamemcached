import FIFO::*;
import GetPut::*;
import Vector::*;
import Shifter::*;

typedef TAdd#(TLog#(TDiv#(inSz,8)),1) ByteSz#(numeric type inSz);

interface ByteSer;
   interface Put#(Tuple3#(Bit#(512), Bit#(6), Bit#(7))) inPipe;
   interface Get#(Bit#(128)) outPipe;
endinterface

(*synthesize*)
module mkByteSer(ByteSer);
   
   FIFO#(Tuple3#(Bit#(512), Bit#(2), Bit#(3))) inQ <- mkSizedFIFO(5);
   FIFO#(Bit#(128)) outQ <- mkFIFO();
   Reg#(Bit#(2)) wordCnt <- mkReg(0);
   rule doSer;
      let v = inQ.first;
      let d = tpl_1(v);
      let offset = tpl_2(v);
      let wordMax = tpl_3(v);
      Vector#(4, Bit#(128)) dataV = unpack(d);
      if ( extend(wordCnt) + 1 < wordMax ) begin
         wordCnt <= wordCnt + 1;
      end
      else begin
         wordCnt <= 0;
         inQ.deq();
      end
      outQ.enq(dataV[offset+wordCnt]);
   endrule
   
   interface Put inPipe;
      method Action put(Tuple3#(Bit#(512), Bit#(6), Bit#(7)) v);
         let d = tpl_1(v);
         let offset = tpl_2(v);
         let nBytes = tpl_3(v) + extend(offset[3:0]);
         Bit#(3) nWords = truncate(nBytes >> 4);
         Bit#(4) remainder = truncate(nBytes);
         if ( remainder != 0)
            nWords = nWords + 1;
         //$display("%m: d = %h, wordOffset = %d, nWords = %d", d, offset >>4, nWords);
         inQ.enq(tuple3(d, truncate(offset>>4), nWords));
      endmethod
   endinterface
   interface Get outPipe = toGet(outQ);
endmodule

interface ByteDes;
   interface Put#(Tuple2#(Bit#(6), Bit#(7))) request;
   interface Put#(Bit#(128)) inPipe;
   interface Get#(Tuple2#(Bit#(512),Bit#(7))) outPipe;
endinterface

(*synthesize*)
module mkByteDes(ByteDes);
   
   Reg#(Bit#(384)) cache <- mkRegU();
   Reg#(Bit#(2)) wordCnt <- mkReg(0);
   FIFO#(Tuple3#(Bit#(6), Bit#(3), Bit#(7))) reqQ <- mkFIFO();
   FIFO#(Bit#(128)) inQ <- mkFIFO;
   FIFO#(Tuple3#(Bit#(512), Bit#(4), Bit#(7))) immQ <- mkFIFO;
   FIFO#(Tuple2#(Bit#(512), Bit#(7))) outQ <- mkFIFO;
   rule doDes;
      let d <- toGet(inQ).get();
      
      let v = reqQ.first;
      let offset = tpl_1(v);
      let wordMax = tpl_2(v);
      let nBytes = tpl_3(v);
      
      Bit#(512) newData = {d,cache};
      //$display("%m:: wordCnt = %d, wordMax = %d, offset = %d, newData = %h", wordCnt, wordMax, offset, newData);
      if ( extend(wordCnt) + 1 < wordMax ) begin
         wordCnt <= wordCnt + 1;
      end
      else begin
         immQ.enq(tuple3(newData>>{3-wordCnt,7'b0}, offset[3:0], nBytes));
         wordCnt <= 0;
         reqQ.deq();
      end
      
      cache <= truncateLSB(newData);
      //outQ.enq(dataV[offset+wordCnt]);
   endrule
   
   rule doAlign;
      let d <- toGet(immQ).get();
      let data = tpl_1(d);
      let sft = tpl_2(d);
      outQ.enq(tuple2(rotateRByte(data,sft), tpl_3(d)));
   endrule
   
    interface Put request;
      method Action put(Tuple2#(Bit#(6), Bit#(7)) v);
         let offset = tpl_1(v);
         let nBytes = tpl_2(v) + extend(offset[3:0]);
         Bit#(3) nWords = truncate(nBytes >> 4);
         Bit#(4) remainder = truncate(nBytes);
         if ( remainder != 0)
            nWords = nWords + 1;
         //$display("%m: byteOffset = %d, nBytes = %d, nWords = %d", offset, tpl_2(v), nWords);
         reqQ.enq(tuple3(offset, nWords, tpl_2(v)));
      endmethod
    endinterface
   interface Put inPipe = toPut(inQ);
   interface Get outPipe = toGet(outQ);
endmodule
   


/*interface ByteSer#(numeric type inSz, numeric type outSz);
   interface Put#(Tuple3#(Bit#(inSz), Bit#(),  Bit#(ByteSz#(inSz)))) inPipe;
   interface Get#(Bit#(outSz)) outPipe;
endinterface

module mkByteSer(ByteSerIfc#(numeric type inSz, numeric type outSz));

   FIFO#(Tuple2#(Bit#(inSz), Bit#(ByteSz#(inSz)))) inQ <- mkFIFO;
   FIFO#(Bit#(outSz)) outQ <- mkFIFO;
   
   Reg#(Bit#(32)) byteCnt <- mkReg(0);
   
   Reg#(Bit#(inSz)) inBuf <- mkRegU();
   
   Reg#(Int#(ByteSz#(inSz))) byteCnt_inBuf <- mkReg(0);
   Reg#(Int#(ByteSz#(inSz))) byteCnt_outBuf <- mkReg(valueOf(TDiv#(outSz,8)));
   
   rule doSer;
      if ( byteCnt_inBuf < byteCnt_outBuf) begin
      end
   endrule
   
   
   interface Put request;
   interface Put inPipe = toPut(inQ);
   interface Get outPipe = toGet(outQ);
endmodule*/
