import CAM::*;

import ClientServer::*;
import GetPut::*;

module mkTest(Empty);
   
   CAM#(16, Bit#(32), Bit#(32)) cam <- mkSnapCAM;
   Reg#(Bit#(32)) reqCnt <- mkReg(0);
   Reg#(Bool) flag <- mkReg(True);
   rule doWrite if (reqCnt < 32);
      reqCnt <= reqCnt + 1;
      $display("%t, inputValue addr = %h, data = %h", $time, reqCnt, ~reqCnt);
      //flag <= !flag;
      cam.writePort.put(tuple2(reqCnt, ~reqCnt));
   endrule
   
   Reg#(Bit#(32)) reqCnt2 <- mkReg(0);
   Reg#(Bit#(32)) req <- mkReg(0);
   rule doRead if (reqCnt2 < 32 && reqCnt > 1);
      reqCnt2 <= reqCnt2 + 1;
      //if ( reqCnt2 == 0) begin
      $display("%t, query addr = %h", $time, req);
      cam.readPort.request.put(req);
      req <= req + 1;
      /*if ( req == 0 ) begin
         req <= 3;
      end
      else begin
         req <= req - 1;
      end*/
      //end
   endrule
   
   rule doReadResp;
      let v <- cam.readPort.response.get();
      
      if ( isValid(v) )
         $display("%t, Got value = %h", $time, fromMaybe(?, v));
      else
         $display("%t, Not exist", $time);
   endrule
endmodule
