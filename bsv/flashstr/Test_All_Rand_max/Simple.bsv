
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
import FIFOF::*;
import MyArbiter::*;
import MemcachedTypes::*;

import Vector::*;
import ClientServer::*;
import DDR3Sim::*;
import DRAMController::*;
import Connectable::*;
import GetPut::*;

import AuroraImportFmc1::*;

import ControllerTypes::*;
import AuroraCommon::*;

import ValDRAMCtrlTypes::*;
import ValFlashCtrlTypes::*;
//import DRAMPartioner::*;
import SerDes::*;
import FlashValueStore::*;
import WriteBuffer::*;

import AuroraImportFmc1::*;

import ControllerTypes::*;
//import AuroraExtArbiter::*;
//import AuroraExtImport::*;
//import AuroraExtImport117::*;
import AuroraCommon::*;

import ControllerTypes::*;
import FlashCtrlVirtex::*;
import FlashCtrlModel::*;
import FlashServer::*;


interface SimpleIndication;
   method Action getVal(Bit#(64) v, Bit#(32) tag);
   method Action wrAck(Bit#(64) v);
endinterface


interface SimpleRequest;
   method Action readReq(Bit#(64) startAddr, Bit#(64) nBytes, Bit#(32) tag);
   
   method Action writeReq(Bit#(64) nBytes);
   method Action writeVal(Bit#(64) wrVal);

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
   GtxClockImportIfc gtx_clk_fmc1 <- mkGtxClockImport;
   `ifdef BSIM
   FlashCtrlVirtexIfc flashCtrl <- mkFlashCtrlModel(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
   `else
   FlashCtrlVirtexIfc flashCtrl <- mkFlashCtrlVirtex(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
   `endif

   
   //let flashValStr <- mkFlashValueStore(clk250);
   let flashValStr <- mkFlashValueStore();
   mkConnection(flashValStr.dramClient, dram);
   
   let flashServer <- mkFlashServer_dummy(flashCtrl.user);
   
   mkConnection(flashServer.writeServer, flashValStr.flashRawWrClient);
   mkConnection(flashServer.readServer, flashValStr.flashRawRdClient);


   
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
   Vector#(2, FIFOF#(Tuple2#(ValSizeT, TagT))) burstSzQs <- replicateM(mkFIFOF());
   Vector#(2, FIFOF#(Tuple2#(WordT, TagT))) rdRespQs <- replicateM(mkFIFOF);
   
   mkConnection(toPut(burstSzQs[0]), flashValStr.readServer.dramBurstSz);
   mkConnection(toPut(burstSzQs[1]), flashValStr.readServer.flashBurstSz);
   
   mkConnection(toPut(rdRespQs[0]), flashValStr.readServer.dramResp);
   mkConnection(toPut(rdRespQs[1]), flashValStr.readServer.flashResp);
   
   FIFO#(Tuple2#(WordT, TagT)) rdRespQ <- mkFIFO;
   
   Reg#(ValSizeT) byteCnt_resp <- mkReg(0); FIFO#(Tuple3#(Bit#(1), ValSizeT, TagT))
   nextBurst <- mkFIFO();

   Arbiter_IFC#(2) arbiter <- mkArbiter(False);
   
   for (Integer i = 0; i < 2; i = i + 1) begin
      rule arbitReq ( burstSzQs[i].notEmpty );
         //$display("valuestr, req for burst i = %d", i);
         arbiter.clients[i].request;
      endrule
      
      rule arbitResp if ( arbiter.grant_id == fromInteger(i));
         let v <- toGet(burstSzQs[i]).get;
         nextBurst.enq(tuple3(fromInteger(i), tpl_1(v), tpl_2(v)));
      endrule
   end
   
   FIFO#(Tuple2#(ValSizeT, TagT)) nextRespIdQ <- mkFIFO();
   rule doBurst;
      let v = nextBurst.first();
      let sel = tpl_1(v);
      let nBytes = tpl_2(v);
      let reqId = tpl_3(v);
      
      if ( sel == 1 ) begin
         $display("Dequeueing from flash, reqId = %d, byteCnt_resp = %d, nBytes = %d", reqId, byteCnt_resp, nBytes);
      end
      else begin
         $display("Dequeueing from dram, reqId = %d, byteCnt_resp = %d, nBytes = %d", reqId, byteCnt_resp, nBytes);
      end
      
      if (byteCnt_resp == 0) begin
         nextRespIdQ.enq(tuple2(nBytes,reqId));
      end
      
      if ( byteCnt_resp + 16 < nBytes) begin
         byteCnt_resp <= byteCnt_resp + 16;
      end
      else begin
         byteCnt_resp <= 0;
         nextBurst.deq();
      end
      let d <- toGet(rdRespQs[sel]).get();
      rdRespQ.enq(d);
   endrule

   // rule deqNextBurstQ;
   //    let d <- toGet(nextRespIdQ).get();
   //    $display("NextBurst, reqId = %d, nBytes = %d", tpl_2(d), tpl_1(d));
   // endrule
   
   Reg#(ValSizeT) byteCnt <- mkReg(0);
   rule drRdResp;
      let d =  nextRespIdQ.first();
      
      Bool deqData = (byteCnt % 16 == 8);
      
      if ( byteCnt + 8 >= tpl_1(d) ) begin
         byteCnt <= 0;
         nextRespIdQ.deq();
         deqData = True;
      end
      else begin
         byteCnt <= byteCnt + 8;
      end   
      
      //let v <- flashValStr.readServer.readVal.get();
      //let v <- toGet(rdRespQ).get();
      if ( deqData ) rdRespQ.deq();
      let v = rdRespQ.first();
      let data = tpl_1(v);
      let tag = tpl_2(v);
      //$display("%h, %d",data, tag);
      $display("Indication Read Response, byteCnt = %d, maxBytes = %d, deqData = %d, tag = %d, data = %h", byteCnt, tpl_1(d), deqData, tag, data);
      if ( byteCnt % 16 == 0 ) begin
         indication.getVal(truncate(data), extend(tag));
      end
      else begin
         indication.getVal(truncateLSB(data), extend(tag));
      end
   endrule
  
   Reg#(Bit#(29)) reqAddr <- mkReg(0);
   Reg#(Bit#(29)) resAddr <- mkReg(0);
   Reg#(Bit#(29)) maxAddr <- mkRegU();
   Reg#(Bool) dumpBool <- mkReg(False);
   rule dump_req if (dumpBool && reqAddr < maxAddr);

      dram.readReq(zeroExtend(reqAddr),64);
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
         des.request(numWords,?);
      end
      else begin
         byteCnt_des <= byteCnt_des + 64;
         des.request(8,?);
      end
   endrule
   
   rule doConn;
      let v <- des.getVal;
      //$display("flashValStr writeWord %h", v);
      flashValStr.writeServer.writeWord.put(tpl_1(v));
   endrule

   rule doWrAck;
      let v <- flashValStr.writeServer.writeServer.response.get;
      indication.wrAck(extend(pack(v)));
   endrule

   interface SimpleRequest request;
      method Action readReq(Bit#(64) startAddr, Bit#(64) nBytes, Bit#(32) tag);
         //rdRqQ.enq(tuple2(startAddr, nBytes));
         flashValStr.readServer.request.put(FlashReadReqT{addr: unpack(truncate(startAddr)), numBytes: truncate(nBytes), reqId: truncate(tag)});
      endmethod
   
      method Action writeReq(Bit#(64) nBytes);
         //wrRqQ.enq(tuple2(startAddr, nBytes));
         flashValStr.writeServer.writeServer.request.put(truncate(nBytes));
         numBytesQ.enq(truncate(nBytes));
      endmethod
      
      method Action writeVal(Bit#(64) wrVal);
         //wrValQ.enq(wrVal);
         wDataWord.enq(wrVal);
      endmethod
   endinterface
   
   interface Aurora_Pins aurora_fmc1 = flashCtrl.aurora;
   interface Aurora_Clock_Pins aurora_clk_fmc1 = gtx_clk_fmc1.aurora_clk;

endmodule
