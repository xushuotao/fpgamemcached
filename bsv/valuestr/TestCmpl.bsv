import CompletionBuffer::*;

module mkTest(Empty);
   CompletionBufferIfc#(Bit#(64), 16) cmplBuf <- mkCompletionBuffer();
   Reg#(Bit#(64)) cnt <- mkReg(0);
   Reg#(Bit#(64)) delCnt <- mkReg(0);
   //(*descending_urgency = "doDel, doCmd"*)
   rule doCmd;
      if ( cnt < 32 ) begin
         $display("(%t) addCmd", $time);
         cmplBuf.updatePort.addCmd(cnt);
         cnt <= cnt + 1;
      end
   endrule

   Reg#(Bit#(64)) cycle <- mkReg(0);
   rule doDel;
      if ( cycle >= 32 ) begin
         $display("(%t) deleteCmd", $time);
         cmplBuf.updatePort.deleteCmd;
      end
      cycle <= cycle + 1;
   endrule
   
endmodule
