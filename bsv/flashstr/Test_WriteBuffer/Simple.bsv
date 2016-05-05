
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
import GetPut::*;

import ControllerTypes::*;
import ValDRAMCtrlTypes::*;
import ValFlashCtrlTypes::*;

import SerDes::*;
import WriteBuffer::*;

interface SimpleIndication;
   method Action getVal(Bit#(64) v, Bit#(32) tag);
   method Action wrAck(Bit#(64) v);
endinterface


interface SimpleRequest;
   method Action readReq(Bit#(64) startAddr, Bit#(64) nBytes, Bit#(32) reqId);
   
   method Action writeReq(Bit#(64) nBytes);
   method Action writeVal(Bit#(64) wrVal);

endinterface


module mkSimpleRequest#(SimpleIndication indication)(SimpleRequest);
   
   
   let ddr3_ctrl_user <- mkDDR3Simulator();
   
   
   let dramController <- mkDRAMController();
   
   //let ddr3_cli_200Mhz <- mkDDR3ClientSync(dramController.ddr3_cli, clockOf(dramController), resetOf(dramController), clockOf(ddr3_ctrl_user), resetOf(ddr3_ctrl_user));
   
   mkConnection(dramController.ddr3_cli, ddr3_ctrl_user);
   
   let wrBuf <- mkFlashWriteBuffer;
   
   mkConnection(wrBuf.dramClient, dramController);

   
   FIFO#(Tuple2#(Bit#(64), Bit#(64))) rdRqQ <- mkFIFO;
   FIFO#(Tuple2#(Bit#(64), Bit#(64))) wrRqQ <- mkFIFO;
   FIFO#(Bit#(64)) wrValQ <- mkSizedFIFO(64);
   
   /*rule drRdRq;
      let v = rdRqQ.first;
      rdRqQ.deq;
      valstr.readReq(tpl_1(v), tpl_2(v));
   endrule
  
   rule drWrRq;
      let v = wrRqQ.first;
      wrRqQ.deq;
      valstr.writeReq(tpl_1(v), tpl_2(v));
   endrule
   
   rule drWrVal;
      let v = wrValQ.first;
      wrValQ.deq;
      valstr.writeVal(v);
   endrule*/
   
   rule drRdResp;
      let v <- wrBuf.readUser.readVal.get();
      let data = tpl_1(v);
      let tag = tpl_2(v);
      $display("%h, %d",data, tag);
      indication.getVal(data, extend(tag));
   endrule
  
   Reg#(Bit#(29)) reqAddr <- mkReg(0);
   Reg#(Bit#(29)) resAddr <- mkReg(0);
   Reg#(Bit#(29)) maxAddr <- mkRegU();
   Reg#(Bool) dumpBool <- mkReg(False);
   rule dump_req if (dumpBool && reqAddr < maxAddr);

      dramController.readReq(zeroExtend(reqAddr),64);
      reqAddr <= reqAddr + 64;

   endrule
   
   FIFO#(Bit#(32)) numBytesQ <- mkFIFO();
   DeserializerIfc#(64, 512, Bit#(0)) des <- mkDeserializer();
   FIFO#(Bit#(64)) wDataWord <- mkFIFO;
      
   mkConnection(toGet(wDataWord), des.demarshall);
   Reg#(Bit#(32)) byteCnt_des <- mkReg(0);
   rule driveDesCmd;
      let numBytes = numBytesQ.first();
      if ( byteCnt_des + 64 >= numBytes) begin
         numBytesQ.deq();
         byteCnt_des <= 0;
         Bit#(4) numWords = truncate((numBytes - byteCnt_des) >> 3);
         Bit#(3) remainder = truncate(numBytes - byteCnt_des);
         if ( remainder != 0)
            numWords = numWords + 1;
         des.request(numWords, ?);
      end
      else begin
         byteCnt_des <= byteCnt_des + 64;
         des.request(8, ?);
      end
   endrule
   
   rule doConn;
      let v <- des.getVal;
      //$display("wrBuf writeWord %h", v);
      wrBuf.writeUser.writeWord.put(tpl_1(v));
   endrule

   rule doWrAck;
      let v <- wrBuf.writeUser.writeAck.get;
      indication.wrAck(extend(pack(v)));
   endrule
   
   method Action readReq(Bit#(64) startAddr, Bit#(64) nBytes, Bit#(32) reqId);
      //rdRqQ.enq(tuple2(startAddr, nBytes));
      wrBuf.readUser.readReq.put(FlashReadReqT{addr: unpack(truncate(startAddr)), numBytes: truncate(nBytes), reqId: truncate(reqId)});
   endmethod
   
   method Action writeReq(Bit#(64) nBytes);
      //wrRqQ.enq(tuple2(startAddr, nBytes));
      wrBuf.writeUser.writeReq.put(truncate(nBytes));
      numBytesQ.enq(truncate(nBytes));
   endmethod
   
   method Action writeVal(Bit#(64) wrVal);
      //wrValQ.enq(wrVal);
      wDataWord.enq(wrVal);
   endmethod

endmodule
