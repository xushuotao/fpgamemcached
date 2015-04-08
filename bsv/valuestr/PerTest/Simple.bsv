
// Copyright (c) 2013 Nokia, Inc.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import FIFO::*;

import Vector::*;
import DDR3Sim::*;
import DRAMController::*;
import Connectable::*;
import Time::*;
import ValDRAMCtrl::*;

interface SimpleIndication;
   method Action done( Bit#(64) v);
endinterface


interface SimpleRequest;
   method Action start(Bit#(32) nReqs);
endinterface


module mkSimpleRequest#(SimpleIndication indication)(SimpleRequest);
   
   
   let ddr3_ctrl_user <- mkDDR3Simulator();
   
   
   let dramController <- mkDRAMController();
   
   //let ddr3_cli_200Mhz <- mkDDR3ClientSync(dramController.ddr3_cli, clockOf(dramController), resetOf(dramController), clockOf(ddr3_ctrl_user), resetOf(ddr3_ctrl_user));
   
   mkConnection(dramController.ddr3_cli, ddr3_ctrl_user);
   
   let clock <- mkLogicClock();
   
   let valCtrl <- mkValDRAMCtrl;
   let valstr = valCtrl.user;
   
   mkConnection(valCtrl.dramClient, dramController);
   
   FIFO#(Bit#(32)) cntMaxQ <- mkFIFO;
   Reg#(Bit#(32)) cnt <- mkReg(0);
   
   Reg#(Bit#(32)) cycleCnt <- mkReg(0);
   Reg#(Bool) started <- mkReg(False);
   rule doReq;
      let cntMax = cntMaxQ.first();
      if ( cnt < cntMax ) begin
         valstr.readReq(extend(cnt), 64);
         cnt <= cnt + 1;
      end
      else begin
         cnt <= 0;
         cntMaxQ.deq();
      end
   endrule
   
   rule increCycle (started);
      cycleCnt <= cycleCnt + 1;
   endrule
   
   FIFO#(Bit#(32)) respMaxQ <- mkFIFO();
   Reg#(Bit#(32)) respCnt <- mkReg(0);
   
   rule doResp;
      let respMax = respMaxQ.first;
      if ( respCnt < respMax ) begin
         respCnt <= respCnt + 1;
         let d <- valstr.readVal();
         $display("(%t)Get Val[%d] = %h", $time, respCnt, d);
      end
      else begin
         indication.done(extend(cycleCnt));
         respCnt <= 0;
         respMaxQ.deq();
      end
   endrule
   
   method Action start(Bit#(32) nReqs);
      cycleCnt <= 0;
      started <= True;
      cntMaxQ.enq(nReqs);
      respMaxQ.enq(nReqs*8);
   endmethod

endmodule
