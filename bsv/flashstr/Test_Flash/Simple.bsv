
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
import GetPut::*;
import Vector::*;
import ClientServer::*;
import Connectable::*;


import DRAMController::*;
import Clocks :: *;
import Xilinx       :: *;
`ifndef BSIM
import XilinxCells ::*;
`endif

import AuroraImportFmc1::*;

import ControllerTypes::*;
import AuroraCommon::*;

import ValFlashCtrlTypes::*;
import ValFlashCtrl::*;

typedef enum{Idle, InitBuf, Flush, Read} State deriving (Eq, Bits);


interface SimpleIndication;
   method Action finish(Bit#(64) lowDta, Bit#(64) highDta, Bit#(32) reqId);
endinterface

interface SimpleRequest;
   method Action start(Bit#(64) addr, Bit#(32) numBytes, Bit#(32) reqId);
endinterface

interface SimpleIfc;
   interface SimpleRequest request;

   interface Aurora_Pins#(4) aurora_fmc1;
   interface Aurora_Clock_Pins aurora_clk_fmc1;
   
   //interface Vector#(AuroraExtQuad, Aurora_Pins#(1)) aurora_ext;
   //interface Aurora_Clock_Pins aurora_quad119;
   //interface Aurora_Clock_Pins aurora_quad117;
endinterface 


module mkSimpleRequest#(SimpleIndication indication, DRAMControllerIfc dram, Clock clk250, Reset rst250)(SimpleIfc);
   FIFO#(Tuple3#(Bit#(64), Bit#(32), TagT)) reqQ <- mkFIFO;
   
   let valFlashCtrl <- mkValFlashCtrl(clk250);
      
   mkConnection(valFlashCtrl.dramClient, dram);
   
   Reg#(State) state <- mkReg(Idle);
   
   Reg#(Bit#(64)) byteCnt <- mkReg(0);
   
   function Bit#(512) doParaIncr(Bit#(512) v);
      Vector#(8, Bit#(64)) dataV = unpack(v);
      
      for (Integer i = 0; i < 8; i = i + 1) begin
         dataV[i] = dataV[i] + 8;
      end
      
      return pack(dataV);
   endfunction

   Vector#(8, Bit#(64)) dataInit = newVector;
   for (Integer i = 0; i < 8; i = i + 1)
      dataInit[i] = fromInteger(i);
   
   Reg#(Bit#(512)) dataReg <- mkReg(pack(dataInit));
   rule doBufInit if (state == InitBuf);
      dram.write(byteCnt, dataReg, 64);
      dataReg <= doParaIncr(dataReg);
      
      if (byteCnt + 64 >= fromInteger(valueOf(SuperPageSz))) begin
         byteCnt <= 0;
         state <= Flush;
      end
      else begin
         byteCnt <= byteCnt + 64;
      end
   endrule
   
   rule doFlush if (state == Flush);
      let v = reqQ.first();
      let addr = tpl_1(v);
      
      valFlashCtrl.flushServer.request.put(FlushReqT{bufId: 0, segId: truncate(addr >> valueOf(TLog#(SuperPageSz)))});
      state <= Read;
   endrule
   
   rule doRead if (state == Read);
      let d <- toGet(reqQ).get();
      let addr = tpl_1(d);
      let numBytes = tpl_2(d);
      let reqId = tpl_3(d);
      
      let dummy <- valFlashCtrl.flushServer.response.get();
      valFlashCtrl.readServer.request.put(FlashReadReqT{addr: unpack(truncate(addr)), numBytes: truncate(numBytes), reqId: reqId});
   endrule
   
   rule doReadResp;
      let d <- valFlashCtrl.readServer.response.get();
      let data = tpl_1(d);
      let reqId = tpl_2(d);
      indication.finish(truncate(data), truncateLSB(data), extend(reqId));
   endrule
  
   interface SimpleRequest request;
      method Action start(Bit#(64) addr, Bit#(32) numBytes, Bit#(32) reqId);
         reqQ.enq(tuple3(addr, numBytes, truncate(reqId)));
         state <= InitBuf;
      endmethod
   endinterface
   
   interface Aurora_Pins aurora_fmc1 = valFlashCtrl.aurora_fmc1;
   interface Aurora_Clock_Pins aurora_clk_fmc1 = valFlashCtrl.aurora_clk_fmc1;
   //interface Aurora_Clock_Pins aurora_quad117 = remote_access.aurora_quad117;
endmodule
