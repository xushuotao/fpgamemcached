import ReorderBuffer::*;

module mkTest(Empty);
   let buff <- mkReorderBuffer;
   Bit#(21) byteMax = 16;

   Reg#(Bit#(8)) reqCnt <- mkReg(0);   
   rule sendReq;
      if ( reqCnt < 1 ) begin
         buff.enqReq(0, byteMax);
         reqCnt <= reqCnt + 1;
      end
      else begin
         //reqCnt <= reqCnt + 1;
      end
   endrule
      
   Reg#(Bit#(21)) byteCnt <- mkReg(0);
   rule sendDta;
      if ( byteCnt < byteMax) begin
         byteCnt <= byteCnt + 16;
         buff.inPipe.put(tuple2(byteCnt, True));
      end      
   endrule 
   
   Reg#(Bit#(8)) reqCnt_deq <- mkReg(0);
   rule reqDeq;
      if ( reqCnt_deq < 1 ) begin
         buff.deqReq(0, byteMax);
         reCnt_deq <= reqCnt_deq + 1;
      end
   endrule
   
   rule reqDta;
      let v <- buff.outPipe.get();
      $display("%h, %b", tpl_1(v), tpl_2(v));
   endrule
endmodule
