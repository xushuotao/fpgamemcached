
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
import DRAMController::*;
import Time::*;
import Valuestr::*;

import ChipscopeWrapper::*;

import GetPut::*;
import ClientServer::*;
import Connectable::*;

import DRAMArbiter::*

import PortalMemory::*;
import MemTypes::*;
import MemreadEngine::*;
import MemwriteEngine::*;
import Pipe::*;

interface SimpleIndication;
   method Action rdDone();
   method Action wrDone();
   //method Action getVal(Bit#(64) v);
endinterface


interface SimpleRequest;
   method Action readReq(Bit#(64) startAddr, Bit#(64) nBytes, Bit#(32) wp);
   
   method Action writeReq(Bit#(64) startAddr, Bit#(64) nBytes, Bit#(32) rp);
//   method Action writeVal(Bit#(64) wrVal);

endinterface

interface Simple;
   interface SimpleRequest request;
   interface ObjectReadClient#(64) dmaReadClient;
   interface ObjectWriteClient#(64) dmaWriteClient;
endinterface

module mkSimple#(SimpleIndication indication, DRAMControllerIfc dram, DebugVal probe_0, DebugVal probe_1)(Simple);
   
   MemreadEngine#(64,1)  re <- mkMemreadEngine;
   MemwriteEngine#(64,1) we <- mkMemwriteEngine;

   
   
   let clock <- mkLogicClock();
   
   let valstr <- mkValRawAccess(clock, dram);
   
   mkConnection(valstr.dramClient,dram);
   //FIFO#(Tuple3#(Bit#(64), Bit#(64), Bit#(32))) rdRqQ <- mkFIFO;
  // FIFO#(Tuple3#(Bit#(64), Bit#(64), Bit#(32))) wrRqQ <- mkFIFO;
  // FIFO#(Bit#(64)) wrValQ <- mkFIFO();
   
//   Reg#(Bit#(64)) addr <- mkRegU();
//   Reg#(Bit#(64)) bytes <- mkRegU();
   Reg#(Bit#(32)) burstCnt <- mkRegU();
   Reg#(Bit#(32)) numBursts <- mkRegU();
   Reg#(Bit#(32)) lastBurstSz <- mkRegU();
   Reg#(Bit#(32)) buffPtr <- mkRegU();
   
   Reg#(Bool) busy <- mkReg(False);
   Reg#(Bool) rnw <- mkRegU();
   
   /*Reg#(Bit#(64)) respCnt <- mkRegU();
   Reg#(Bit#(64)) numBytes <- mkRegU();*/
   Reg#(Bit#(32)) burstIterCnt <- mkRegU();
   Reg#(Bit#(32)) numOfResp <- mkRegU();
   
   rule debugWrReq;
      probe_0.setAddr(valstr.debug.debugWrReq.addr);
      probe_0.setBytes(valstr.debug.debugWrReq.nBytes);
   endrule
   
   rule debugWrDta;
      probe_0.setData(valstr.debug.debugWrDta);
   endrule
   
   rule debugRdReq;
      probe_1.setAddr(valstr.debug.debugRdReq.addr);
      probe_1.setBytes(valstr.debug.debugRdReq.nBytes);
   endrule
   
   rule debugRdDta;
      probe_1.setData(valstr.debug.debugRdDta);
   endrule
   
   
   rule drRdRq if (busy && rnw && burstCnt <= numBursts);
      //let v = rdRqQ.first;
      //rdRqQ.deq;
      $display("drRdRq: burstCnt = %d, numBursts = %d", burstCnt, numBursts);
      if ( burstCnt == numBursts && lastBurstSz != 0)
         we.writeServers[0].request.put(MemengineCmd{sglId:buffPtr, base:extend(burstCnt<<7), len:truncate(lastBurstSz), burstLen:truncate(lastBurstSz)});
      else begin
         we.writeServers[0].request.put(MemengineCmd{sglId:buffPtr, base:extend(burstCnt<<7), len:128, burstLen:128});
      end
      burstCnt <= burstCnt + 1;
   endrule
  
   rule drWrRq if (busy && !rnw && burstCnt <= numBursts);
      $display("drWrRq: burstCnt = %d, numBursts = %d", burstCnt, numBursts);
      if ( burstCnt == numBursts && lastBurstSz != 0 )
         re.readServers[0].request.put(MemengineCmd{sglId:buffPtr, base:extend(burstCnt<<7), len:truncate(lastBurstSz), burstLen:truncate(lastBurstSz)});
      else begin
         re.readServers[0].request.put(MemengineCmd{sglId:buffPtr, base:extend(burstCnt<<7), len:128, burstLen:128});
      end
      burstCnt <= burstCnt + 1;
   endrule
   
   

   rule drWrVal;
/*      let v = wrValQ.first;
      wrValQ.deq;*/
      let v <- toGet(re.dataPipes[0]).get;
      valstr.writeVal(v);
      //$display("Get Val = %h, respCnt = %d, numBytes = %d", v, respCnt, numBytes);
      //if ( respCnt + 8 >= numBytes) begin
       //  indication.rdDone();
       //  busy <= False;
      //end
      
     // respCnt <= respCnt + 8;
   endrule
   
   rule drRdResp;
      let v <- valstr.readVal();
      //$display("%h, %d",v, v);
      //indication.getVal(v);
      we.dataPipes[0].enq(v);
   //   $display("Send Val = %h, respCnt = %d, numBytes = %d", v, respCnt, numBytes);
     // if ( respCnt + 8 >= numBytes) begin
        // indication.wrDone();
       //  busy <= False;
      //end
      
      //respCnt <= respCnt + 8;
   endrule
   
   rule read_finish if (busy && !rnw);
      $display("read_finish %d", burstIterCnt, numOfResp);
      if ( burstIterCnt < numOfResp) begin
         let rv0 <- re.readServers[0].response.get;
      end
      else if ( burstIterCnt == numOfResp) begin
         indication.rdDone();
         busy <= False;
      end
      
      burstIterCnt <= burstIterCnt + 1;
      //indication.rdDone();
   endrule
   
   rule write_finish if (busy && rnw);
      $display("write_finish %d, %d", burstIterCnt, numOfResp);
      if ( burstIterCnt < numOfResp) begin
         let rv1 <- we.writeServers[0].response.get;
      end
      else if ( burstIterCnt == numOfResp) begin
         indication.wrDone();
         busy <= False;
      end
      
      burstIterCnt <= burstIterCnt + 1;
      //if(wrIterCnt==0)
      //indication.wrDone;
   endrule
   
   
   interface SimpleRequest request;
      method Action readReq(Bit#(64) startAddr, Bit#(64) nBytes, Bit#(32) wp) if (!busy);
         //if nBytes >= 255
         valstr.readReq(startAddr, nBytes);
      
         burstCnt <= 0;
         numBursts <= truncate(nBytes >> 7);
         if ( nBytes[2:0] == 0 )
            lastBurstSz <= extend(nBytes[6:0]);
         else
            lastBurstSz <= extend(nBytes[6:3]+1)<<3;
         
         buffPtr <= wp;
         //rdRqQ.enq(tuple3(startAddr, nBytes, wp));
         busy <= True;
   
         burstIterCnt <= 0;
         if (nBytes[6:0] == 0 )
            numOfResp <= truncate(nBytes >> 7);
         else
            numOfResp <= truncate(nBytes >> 7) + 1;
   
         rnw <= True;
      endmethod
      
      method Action writeReq(Bit#(64) startAddr, Bit#(64) nBytes, Bit#(32) rp) if (!busy);
         //wrRqQ.enq(tuple3(startAddr, nBytes, rp));
         valstr.writeReq(startAddr, nBytes);
      
         burstCnt <= 0;
         numBursts <= truncate(nBytes >> 7);
         if ( nBytes[2:0] == 0 )
            lastBurstSz <= extend(nBytes[6:0]);
         else
            lastBurstSz <= extend(nBytes[6:3]+1)<<3;
         
         buffPtr <= rp;
        // rdRqQ.enq(tuple3(startAddr, nBytes, wp));
         busy <= True;
   
         //respCnt <= 0;
         //numBytes <= nBytes;
         burstIterCnt <= 0;
         if (nBytes[6:0] == 0 )
            numOfResp <= truncate(nBytes >> 7);
         else
            numOfResp <= truncate(nBytes >> 7) + 1;
         rnw <= False;
      endmethod
   
/*      method Action writeVal(Bit#(64) wrVal);
         wrValQ.enq(wrVal);
      endmethod*/
   endinterface
   
   interface ObjectReadClient dmaReadClient = re.dmaClient;
   interface ObjectWriteClient dmaWriteClient = we.dmaClient;

endmodule
