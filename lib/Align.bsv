import Shifter::*;

import FIFO::*;
import FIFOF::*;
import GetPut::*;

interface AlignIfc#(type element_type, type tag_type, numeric type lgWidth);
   method Action align(Bit#(lgWidth) offset, Bit#(32) numBytes, tag_type reqId);
   interface Put#(element_type) inPipe;
   interface Get#(Tuple3#(element_type, Bit#(TAdd#(lgWidth,1)), tag_type)) outPipe;
endinterface

interface DeAlignIfc#(type element_type, type tag_type, numeric type lgWidth);
   method Action deAlign(Bit#(lgWidth) offset, Bit#(32) numBytes, tag_type reqId);
   interface Put#(element_type) inPipe;
   interface Get#(Tuple3#(element_type, Bit#(TAdd#(lgWidth,1)), tag_type)) outPipe;
endinterface


typedef Bit#(TAdd#(SizeOf#(element_type),SizeOf#(element_type))) ShiftT#(type element_type);
typedef AlignIfc#(element_type, tag_type, ElementShiftSz#(element_type)) ByteAlignIfc#(type element_type, type tag_type);
typedef DeAlignIfc#(element_type, tag_type, ElementShiftSz#(element_type)) ByteDeAlignIfc#(type element_type, type tag_type);

module mkByteAlignPipeline(AlignIfc#(element_type, tag_type, lgWidth))
   provisos(Bits#(element_type, a__),
            Bitwise#(element_type),
            Add#(b__, lgWidth, 32),
            Add#(c__, lgWidth, TLog#(TDiv#(TAdd#(a__, a__), 8))),
            Bits#(tag_type, d__),
            Add#(e__, TAdd#(lgWidth, 1), 32)
            );
   FIFOF#(Tuple2#(Bit#(32), Bit#(32))) sftArgs <- mkFIFOF;
   FIFOF#(Tuple4#(tag_type, Bit#(lgWidth), Bit#(32), Bit#(32))) sftArgs_1 <- mkFIFOF;
   
   FIFO#(element_type) wordQ <- mkFIFO();
   
   Reg#(element_type) readCache <- mkRegU;
   Reg#(Bit#(32)) wordCnt_in <- mkReg(0);
   Reg#(Bit#(32)) wordMax_in <- mkReg(0);
     
   FIFO#(ShiftT#(element_type)) imm_dataQ <- mkFIFO();
   
   Reg#(Bool) leftOver <- mkReg(False);
   Reg#(Bool) nextLeftOver <- mkReg(False);
   rule doAlignData;
      if (wordCnt_in + 1 >= wordMax_in) begin
         if ( sftArgs.notEmpty() ) begin
            let v <- toGet(sftArgs).get();
            let nInWords = tpl_1(v);
            let nOutWords = tpl_2(v);
            
            wordCnt_in <= 0;
            wordMax_in <= nInWords;
            
            leftOver <= nextLeftOver;
            nextLeftOver <= (nOutWords >= nInWords);
            //$display("nextLeftOver = %d <= %d", nextLeftOver, (nOutWords >= nInWords));
         end
         else begin
            wordCnt_in <= 0;
            wordMax_in <= 0;
            leftOver <= nextLeftOver;
            nextLeftOver <= False;
         end
      end
      else begin
         wordCnt_in <= wordCnt_in + 1;
      end
      
      element_type word = ?;
      if ( wordMax_in > 0 ) begin
         word <- toGet(wordQ).get();
         readCache <= word;
      end
      
      if ( wordCnt_in == 0) begin
         if (leftOver) begin
            //$display("here");
            imm_dataQ.enq({0, pack(readCache)});
         end
      end 
      else begin
         imm_dataQ.enq({pack(word), pack(readCache)});
      end
      
      
      //$display("wordCnt_sft = %d, nInWords = %d, nOutWords = %d", wordCnt_sft, nInWords, nOutWords);
   endrule
   
   
   ByteSftIfc#(ShiftT#(element_type)) sfter <- mkPipelineRightShifter();
   FIFO#(Tuple2#(Bit#(TAdd#(lgWidth, 1)),tag_type)) immQ <- mkSizedFIFO(valueOf(ElementShiftSz#(ShiftT#(element_type))));
   
   Reg#(Bit#(32)) wordCnt_out <- mkReg(0);
   Reg#(Bit#(32)) byteCnt <- mkReg(0);
      
   rule doAlignData_1;
      let data <- toGet(imm_dataQ).get();
      let v = sftArgs_1.first();
      let reqId = tpl_1(v);
      let wordOffset = tpl_2(v);
      let nOutWords = tpl_3(v);
      let totalBytes = tpl_4(v);
      
      Bit#(TAdd#(lgWidth, 1)) byteIncr = ?;
      if (wordCnt_out + 1 >= nOutWords) begin
         wordCnt_out <= 0;
         sftArgs_1.deq();
         byteCnt <= 0;
         byteIncr = truncate(totalBytes - byteCnt);
         //$display("Done last word");
      end
      else begin
         wordCnt_out <= wordCnt_out + 1;
         byteCnt <= byteCnt + (1 << valueOf(lgWidth));
         byteIncr = 1 << valueOf(lgWidth);
      end
                    
      sfter.rotateByteBy(data, extend(wordOffset));
      immQ.enq(tuple2(byteIncr, reqId));
      
   endrule

   method Action align(Bit#(lgWidth) offset, Bit#(32) numBytes, tag_type reqId);
      Bit#(32) effectiveBytes = extend(offset) + numBytes;
      Bit#(32) nInWords = effectiveBytes >> valueOf(lgWidth);
      Bit#(lgWidth) remainder_in = truncate(effectiveBytes);
      if (remainder_in != 0) begin
         nInWords = nInWords + 1;
      end
   
      Bit#(32) nOutWords = numBytes >> valueOf(lgWidth);
      Bit#(lgWidth) remainder_out = truncate(numBytes);
      if (remainder_out != 0) begin
         nOutWords = nOutWords + 1;
      end

      sftArgs.enq(tuple2(nInWords, nOutWords));
      sftArgs_1.enq(tuple4(reqId, offset, nOutWords, numBytes));
   endmethod
   interface Put inPipe = toPut(wordQ);
   interface Get outPipe;
      method ActionValue#(Tuple3#(element_type, Bit#(TAdd#(lgWidth,1)), tag_type)) get;
         let data <- sfter.getVal;
         let v <- toGet(immQ).get();
         return tuple3(unpack(truncate(pack(data))), tpl_1(v), tpl_2(v));
      endmethod
   endinterface
endmodule

module mkByteDeAlignPipeline(DeAlignIfc#(element_type, tag_type, lgWidth))
   provisos(Bits#(element_type, a__),
            Bitwise#(element_type),
            Add#(b__, lgWidth, 32),
            Add#(c__, TAdd#(lgWidth,1), TLog#(TDiv#(TAdd#(a__, a__), 8))),
            Bits#(tag_type, d__),
            Add#(e__, TAdd#(lgWidth, 1), 32)
            //Log#(TDiv#(TAdd#(a__, a__), 8), lgWidth)
            );
   FIFOF#(Tuple6#(Bit#(lgWidth), Bit#(TAdd#(lgWidth,1)), Bit#(32), Bit#(32), Bit#(32), tag_type)) sftArgs <- mkFIFOF;
      
   FIFO#(element_type) wordQ <- mkFIFO();
   
   Reg#(element_type) readCache <- mkRegU;
   
   ByteSftIfc#(ShiftT#(element_type)) sfter <- mkPipelineRightShifter();
   FIFO#(Tuple2#(Bit#(TAdd#(lgWidth, 1)), tag_type)) immQ <- mkSizedFIFO(valueOf(ElementShiftSz#(ShiftT#(element_type))));

   Reg#(Bit#(32)) wordCnt <- mkReg(0);
   Reg#(Bit#(32)) byteCnt <- mkReg(0);
   rule doDeAlignData;
      let v = sftArgs.first();
      let offset = tpl_1(v);
      let leftOverBytes = tpl_2(v);
      let nInWords = tpl_3(v);
      let nOutWords = tpl_4(v);
      let totalBytes = tpl_5(v);
      let reqId = tpl_6(v);
      
      element_type word = ?;
      if ( wordCnt < nInWords ) begin
         word <- toGet(wordQ).get();
         readCache <= word;
      end
            
      // shift word
      if ( wordCnt == 0 ) begin
         sfter.rotateByteBy(extend(pack(word)), 0);
      end
      else begin
         //$display("shift data = %h, rotate = %d", {pack(word), pack(readCache)}, leftOverBytes);
         sfter.rotateByteBy({pack(word), pack(readCache)}, extend(leftOverBytes));
      end
      
      // caculate byteIncr
      Bit#(TAdd#(lgWidth,1)) byteIncr = ?;
      if ( wordCnt + 1 == nOutWords) begin
         byteIncr = truncate(totalBytes - byteCnt);
      end
      else if ( wordCnt == 0 ) begin
         byteIncr = (1<<valueOf(lgWidth)) - extend(offset);
      end
      else begin
         byteIncr = 1 << valueOf(lgWidth);
      end
      
      immQ.enq(tuple2(byteIncr, reqId));
      
      if ( wordCnt + 1 == nOutWords ) begin
         wordCnt <= 0;
         byteCnt <= 0;
         sftArgs.deq();
      end
      else begin
         wordCnt <= wordCnt + 1;
         byteCnt <= byteCnt + extend(byteIncr);
      end
   endrule
   
   method Action deAlign(Bit#(lgWidth) offset, Bit#(32) numBytes, tag_type reqId);
      Bit#(32) nInWords = numBytes >> valueOf(lgWidth);
      Bit#(lgWidth) remainder_out = truncate(numBytes);
      if (remainder_out != 0) begin
         nInWords = nInWords + 1;
      end
      
      Bit#(32) effectiveBytes = extend(offset) + numBytes;
      Bit#(32) nOutWords = effectiveBytes >> valueOf(lgWidth);
      Bit#(lgWidth) remainder_in = truncate(effectiveBytes);
      if (remainder_in != 0) begin
         nOutWords = nOutWords + 1;
      end
               
      sftArgs.enq(tuple6(offset, (1<<valueOf(lgWidth))-extend(offset), nInWords, nOutWords, numBytes, reqId));
      //sftArgs_1.enq(tuple3(reqId, offset, nOutWords));
   endmethod
   interface Put inPipe = toPut(wordQ);
   interface Get outPipe;
      method ActionValue#(Tuple3#(element_type, Bit#(TAdd#(lgWidth,1)), tag_type)) get;
         let data <- sfter.getVal;
         let v <- toGet(immQ).get();
         return tuple3(unpack(truncate(pack(data))), tpl_1(v), tpl_2(v));
      endmethod
   endinterface
endmodule
