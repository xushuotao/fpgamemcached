
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

import ValuestrCommon::*;
import ValDRAMCtrl_128::*;

interface SimpleIndication;
   method Action getVal(Bit#(64) v1, Bit#(64) v0);
endinterface


interface SimpleRequest;
   method Action readReq(Bit#(64) startAddr, Bit#(64) nBytes);
   
   method Action writeReq(Bit#(64) startAddr, Bit#(64) nBytes);
   method Action writeVal(Bit#(64) wrVal);

endinterface


module mkSimpleRequest#(SimpleIndication indication)(SimpleRequest);
   
   
   let ddr3_ctrl_user <- mkDDR3Simulator();
   
   
   let dramController <- mkDRAMController();
   
      
   mkConnection(dramController.ddr3_cli, ddr3_ctrl_user);
   
   let clock <- mkLogicClock();
   
   let valctrl <- mkValDRAMCtrl;
   let valstr = valctrl.user;
   mkConnection(valctrl.dramClient, dramController);

   
   FIFO#(Tuple2#(Bit#(64), Bit#(64))) rdRqQ <- mkFIFO;
   FIFO#(Tuple2#(Bit#(64), Bit#(64))) wrRqQ <- mkFIFO;
   FIFO#(Bit#(64)) wrValQ <- mkSizedFIFO(64);
   
   rule drRdResp;
      let v <- valstr.readVal();
      $display("%h, %d",v, v);
      indication.getVal(truncateLSB(v), truncate(v));
   endrule
  
   Reg#(Bit#(29)) reqAddr <- mkReg(0);
   Reg#(Bit#(29)) resAddr <- mkReg(0);
   Reg#(Bit#(29)) maxAddr <- mkRegU();
   Reg#(Bool) dumpBool <- mkReg(False);
   
   Reg#(Bit#(64)) readCache <- mkReg(0);
   Reg#(Bool) even <- mkReg(True);

   FIFO#(Bit#(64)) nBytesQ <- mkFIFO();
   Reg#(Bit#(64)) byteCnt <- mkReg(0);
   method Action readReq(Bit#(64) startAddr, Bit#(64) nBytes);
      //rdRqQ.enq(tuple2(startAddr, nBytes));
      valstr.readReq(startAddr, nBytes);
   endmethod
   
   method Action writeReq(Bit#(64) startAddr, Bit#(64) nBytes);
      //wrRqQ.enq(tuple2(startAddr, nBytes));
      valstr.writeReq(ValstrWriteReqT{addr: startAddr, nBytes:truncate(nBytes), doEvict:False});
      nBytesQ.enq(nBytes);
   endmethod
   
   method Action writeVal(Bit#(64) wrVal);
      //wrValQ.enq(wrVal);
      let byteMax = nBytesQ.first();
      if (even) begin
         readCache <= wrVal;
         //$display("here0");
         if ( byteCnt + 8 >= byteMax) begin
            valstr.writeVal({0, wrVal});
         end
      end
      else begin 
         //$display("here1");
         valstr.writeVal({wrVal,readCache});
      end
   
      if ( byteCnt + 8 < byteMax)  begin
         byteCnt <= byteCnt + 8;
         even <= !even;
         //$display("even <= !even[%d]",even);
      end
      else begin
         even <= True;
         byteCnt <= 0;
         nBytesQ.deq();
      end
   endmethod

endmodule
