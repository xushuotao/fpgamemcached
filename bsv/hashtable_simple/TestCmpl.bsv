import CompletionBuf::*;

module mkTest(Empty);
   CompletionBuf#(16, Bit#(32)) cmplBuf <- mkCompletionBuf;
   
   Reg#(Bit#(32)) reqCnt <- mkReg(0);
   rule doIns;
      if (reqCnt < 32) begin
         Bit#(32) value = extend(reqCnt[3:0]);
         if (!cmplBuf.search(value)) begin
            cmplBuf.insert(value);
            $display("Insert at %t", $time);
            reqCnt <= reqCnt + 1;
         end
      end
   endrule
   
   Reg#(Bit#(32)) respCnt <- mkReg(0);
   rule doDel if (reqCnt >= 16);
      if (respCnt < 32) begin
         respCnt <= respCnt + 1;
         cmplBuf.delete();
         $display("Del at %t", $time);
      end
      else 
         $finish();
   endrule
      
endmodule
