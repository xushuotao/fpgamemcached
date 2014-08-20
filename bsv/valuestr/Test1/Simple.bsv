
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
import Valuestr::*;
import Vector::*;
import DDR3Sim::*;
import DRAMController::*;
import Time::*;

/*
typedef struct{
   Bit#(32) a;
   Bit#(32) b;
   } S1 deriving (Bits);

typedef struct{
   Bit#(32) a;
   Bit#(16) b;
   Bit#(7) c;
   } S2 deriving (Bits);

typedef enum {
   E1Choice1,
   E1Choice2,
   E1Choice3
   } E1 deriving (Bits,Eq);

typedef struct{
   Bit#(32) a;
   E1 e1;
   } S3 deriving (Bits);
*/
interface SimpleIndication;
   method Action getVarAddr(Bit#(64) v);   
   method Action dump(Bit#(29) addr, Bit#(64) v0, Bit#(64) v1, Bit#(64) v2, Bit#(64) v3, Bit#(64) v4, Bit#(64) v5, Bit#(64) v6, Bit#(64) v7);
   /*
    method Action heard1(Bit#(32) v);
    method Action heard2(Bit#(16) a, Bit#(16) b);
    method Action heard3(S1 v);
    method Action heard4(S2 v);
    method Action heard5(Bit#(32) a, Bit#(64) b, Bit#(32) c);
    method Action heard6(Bit#(32) a, Bit#(40) b, Bit#(32) c);
    method Action heard7(Bit#(32) a, E1 e1);
   */
endinterface

/*
typedef struct{
   Bit#(32) low;
   Bit#(32) mid;
   Bit#(32) high;
   } TripleWord deriving (Bits, Eq);
*/
interface SimpleRequest;
   method Action readReq(Bit#(64) startAddr, Bit#(64) nBytes);
   //method ActionValue#(Bit#(64)) readVal();
   
   method Action writeReq(Bit#(64) startAddr, Bit#(64) nBytes);
   method Action writeVal(Bit#(64) wrVal);
   //method Action writeReq(Bit#(8) keylen, Bit#(32) hv);
   //method Action key(Bit#(64) keys);
   method Action dump(Bit#(29) toAddr);
    //method Action say2(Bit#(16) a, Bit#(16) b);
    //method Action say3(S1 v);
    //method Action say4(S2 v);
    //method Action say5(Bit#(32)a, Bit#(64) b, Bit#(32) c);
    //method Action say6(Bit#(32)a, Bit#(40) b, Bit#(32) c);
    //method Action say7(S3 v);
endinterface
/*
typedef struct {
    Bit#(32) a;
    Bit#(40) b;
    Bit#(32) c;
} Say6ReqSimple deriving (Bits);
*/

module mkSimpleRequest#(SimpleIndication indication)(SimpleRequest);
   
   
   let ddr3_ctrl_user <- mkDDR3Simulator();
   
   let dram <- mkDRAMController(ddr3_ctrl_user);
   
   let clock <- mkLogicClock();
   
   let valstr <- mkValRawAccess(clock, dram);
   
   FIFO#(Tuple2#(Bit#(64), Bit#(64))) rdRqQ <- mkFIFO;
   FIFO#(Tuple2#(Bit#(64), Bit#(64))) wrRqQ <- mkFIFO;
   FIFO#(Bit#(64)) wrValQ <- mkSizedFIFO(64);
   
   rule drRdRq;
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
   endrule
   
   rule drRdResp;
      let v <- valstr.readVal();
      $display("%h, %d",v, v);
   endrule
  
   Reg#(Bit#(29)) reqAddr <- mkReg(0);
   Reg#(Bit#(29)) resAddr <- mkReg(0);
   Reg#(Bit#(29)) maxAddr <- mkRegU();
   Reg#(Bool) dumpBool <- mkReg(False);
   rule dump_req if (dumpBool && reqAddr < maxAddr);

      dram.readReq(zeroExtend(reqAddr),64);
      reqAddr <= reqAddr + 64;

   endrule
   
   rule dump_res if ( dumpBool );
      if ( resAddr < maxAddr) begin
         let line <- dram.read;
         Vector#(8, Bit#(64)) v = unpack(line);
//         $display("%h",line);
         indication.dump(resAddr, v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7]);
         resAddr <= resAddr + 64;
      end
      else begin
         dumpBool <= False;
         reqAddr <= 0;
         resAddr <= 0;
      end
   endrule
   
   method Action readReq(Bit#(64) startAddr, Bit#(64) nBytes);
      rdRqQ.enq(tuple2(startAddr, nBytes));
   endmethod
   
   method Action writeReq(Bit#(64) startAddr, Bit#(64) nBytes);
      wrRqQ.enq(tuple2(startAddr, nBytes));
   endmethod
   
   method Action writeVal(Bit#(64) wrVal);
      wrValQ.enq(wrVal);
   endmethod

   method Action dump(Bit#(29) toAddr);
      dumpBool <= True;
      maxAddr <= toAddr;
   endmethod  
endmodule
