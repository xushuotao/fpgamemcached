
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
import Hashtable::*;
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
   method Action start(Bit#(8) keylen, Bit#(32) hv);
   method Action key(Bit#(64) keys);
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
   
   let htable <- mkAssocHashtb(dram, clock);
   
   Reg#(Bit#(29)) reqAddr <- mkReg(0);
   Reg#(Bit#(29)) resAddr <- mkReg(0);
   
   Reg#(Bit#(29)) maxAddr <- mkRegU();
   
   Reg#(Bool) dumpBool <- mkReg(False);
   
   FIFO#(Tuple2#(Bit#(8), Bit#(32))) startFifo <- mkFIFO();
   FIFO#(Bit#(64)) keyFifo <- mkFIFO();
   
   rule process;
      let retval <- htable.getValAddr();
      indication.getVarAddr(retval);
   endrule
   
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
   
   rule process_start;
      let v = startFifo.first;
      startFifo.deq();
      htable.readTable(tpl_1(v), tpl_2(v));
   endrule
   
   rule process_key;
      let v = keyFifo.first();
      keyFifo.deq();
      htable.keyTokens(v);
   endrule
   
   method Action start(Bit#(8) keylen, Bit#(32) hv);
      //htable.readTable(keylen, hv);
      startFifo.enq(tuple2(keylen, hv));
   endmethod
   
   method Action key(Bit#(64) keys);
      //htable.keyTokens(keys);
      keyFifo.enq(keys);
   endmethod
   
   method Action dump(Bit#(29) toAddr);
      dumpBool <= True;
      maxAddr <= toAddr;
   endmethod
  
endmodule
