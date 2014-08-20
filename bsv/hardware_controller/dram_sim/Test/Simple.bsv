
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

//import FIFO::*;
import DDR3Sim::*;
import DRAMController::*;

typedef struct{
   Bit#(64) v7;
   Bit#(64) v6;
   Bit#(64) v5;
   Bit#(64) v4;
   Bit#(64) v3;
   Bit#(64) v2;
   Bit#(64) v1;
   Bit#(64) v0;
   } DDRLine deriving (Bits);

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
   method Action readRes(DDRLine data);
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




interface SimpleRequest;
   method Action readReq(Bit#(64) addr, Bit#(7) bytes);
   method Action write(Bit#(64) addr, DDRLine data, Bit#(7) bytes);
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
   
   rule process;
      let data <- dram.read;
      indication.readRes(unpack(data));
   endrule
   
   method Action readReq(Bit#(64) addr, Bit#(7) bytes);
      dram.readReq(addr, bytes);
   endmethod
   
   method Action write(Bit#(64) addr, DDRLine data, Bit#(7) bytes);
      dram.write(addr, pack(data), bytes);
   endmethod
  
endmodule
