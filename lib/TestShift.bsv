import Shifter::*;
import Vector::*;
module mkTest(Empty);
   ByteSftIfc#(Bit#(1024)) barrelShifter <- mkRightShifter();
   //ByteSftIfc#(Bit#(1024)) barrelShifter <- mkLeftShifter();
   
   Reg#(Bit#(64)) cnt <- mkReg(0);
   
   Vector#(128, Bit#(8)) dataV = genWith(fromInteger);
   rule doReq;
      if (cnt < 128 ) begin
         barrelShifter.rotateByteBy(pack(dataV), truncate(cnt));
      end
      cnt <= cnt + 1;
   endrule
   
   Reg#(Bit#(64)) cntResp <- mkReg(0);
   
   rule doResp;
      let v <- barrelShifter.getVal;
      cntResp <= cntResp + 1;
      $display("got val: %h", v);
      if ( rotateRByte(pack(dataV), cntResp) != v) begin
         $display("fail");
         $finish();
      end
   endrule
endmodule
