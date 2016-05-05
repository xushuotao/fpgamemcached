
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
import SerDes::*;
import GetPut::*;
import JenkinsHash::*;
import Vector::*;
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
   method Action getHash(Bit#(32) v);   
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
   method Action start(Bit#(32) keylen);
//   method Action key(TripleWord key);
   method Action key(Bit#(64) k);
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
   let jenkins <- mkJenkinsHash_128();
   
   Reg#(Bit#(32)) cntQ <- mkReg(0);
   FIFO#(Bit#(32)) keylenQ <- mkFIFO();
   
   Integer keylen = 64;
   
   rule doJenkinsReq;
      let cntMax = keylenQ.first();
      if ( cntQ < cntMax ) begin
         jenkins.start(fromInteger(keylen));
         cntQ <= cntQ + 1;
      end
      else begin
         keylenQ.deq();
         cntQ <= 0;
      end
   endrule
   
   Reg#(Bit#(32)) keyCnt <- mkReg(0);
   Reg#(Bit#(32)) numReqs <- mkReg(0);
   FIFO#(Bit#(32)) reqQ <- mkFIFO();
   rule doJenkins if (numReqs < reqQ.first);
      if ( keyCnt + 16 > fromInteger(keylen) ) begin
         keyCnt <= 0;
         numReqs <= numReqs + 1;
      end
      else begin
         keyCnt <= keyCnt + 16;
      end
      //jenkins.putKey(128'hdeadbeefdeadbeefdeadbeefdeadbeef);
      jenkins.inPipe.put(128'hdeadbeefdeadbeefdeadbeefdeadbeef);
   endrule
               
      
   Reg#(Bit#(32)) respCnt <- mkReg(0);
   
   Reg#(Bit#(32)) cycleCnt <- mkReg(0);
   
   Reg#(Bool) started <- mkReg(False);
   
   rule doIncr if ( started);
      cycleCnt <= cycleCnt + 1;
   endrule
   
   rule getVal;
      if (respCnt + 1 == reqQ.first) begin
         respCnt <= 0;
         reqQ.deq();
         $display("finish in %d cycles", cycleCnt);
      end
      else begin
         respCnt <= respCnt + 1;
      end
      
      //let v <- jenkins.getHash();
      let v <- jenkins.response.get();
   endrule
      
   
   method Action start(Bit#(32) keylen);
      //jenkins.start(keylen);
      keylenQ.enq(keylen);
      reqQ.enq(keylen);
      started <= True;
   endmethod
   
   method Action key(Bit#(64) k);
      //jenkins.putKey(k);
      //des.demarshall.put(k);
   endmethod
   /*
   method Action key(TripleWord k);
      Vector#(3, Bit#(32)) inputKeys;
      inputKeys[0] = k.low;
      inputKeys[1] = k.mid;
      inputKeys[2] = k.high;
      jenkins.putKey(pack(inputKeys));
   endmethod
  */
   /*
   method Action say1(Bit#(32) v);
      indication.heard1(v);
   endmethod
   
   method Action say2(Bit#(16) a, Bit#(16) b);
      indication.heard2(a,b);
   endmethod
      
   method Action say3(S1 v);
      indication.heard3(v);
   endmethod
   
   method Action say4(S2 v);
      indication.heard4(v);
   endmethod
      
   method Action say5(Bit#(32) a, Bit#(64) b, Bit#(32) c);
      indication.heard5(a, b, c);
   endmethod

   method Action say6(Bit#(32) a, Bit#(40) b, Bit#(32) c);
      indication.heard6(a, b, c);
   endmethod

   method Action say7(S3 v);
      indication.heard7(v.a, v.e1);
   endmethod
   */
endmodule
