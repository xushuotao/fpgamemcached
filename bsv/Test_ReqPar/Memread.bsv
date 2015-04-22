// Copyright (c) 2013 Quanta Research Cambridge, Inc.

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
import Vector::*;
import GetPut::*;
import ClientServer::*;

import Arith::*;
import Pipe::*;
import MemTypes::*;
import MemreadEngine::*;
import Pipe::*;
import HostInterface::*; // for DataBusWidth

import Connectable::*;

import RequestParser::*;
import ProtocolHeader::*;
import DMAHelper::*;

typedef 1 NumEngineServers;

`ifdef NumOutstandingRequests
typedef `NumOutstandingRequests NumOutstandingRequests;
`else
typedef 2 NumOutstandingRequests;
`endif

`ifdef MemreadEngineBufferSize
Integer memreadEngineBufferSize=`MemreadEngineBufferSize;
`else
Integer memreadEngineBufferSize=256;
`endif

/*typedef 128 DmaBurstBytes; 
Integer dmaBurstBytes = valueOf(DmaBurstBytes);
Integer dmaBurstWords = dmaBurstBytes/wordBytes; //128/16 = 8*/

interface MemreadRequest;
   method Action startRead(Bit#(32) rp, Bit#(64) numBytes);
endinterface

interface Memread;
   interface MemreadRequest request;
   interface MemReadClient#(DataBusWidth) dmaClient;
endinterface

interface MemreadIndication;
   method Action readHeader(Bit#(64) v0, Bit#(64) v1, Bit#(64) v2);
   method Action readTokens(Bit#(64) v0, Bit#(64) v1);
endinterface

typedef TDiv#(DataBusWidth,32) DataBusWords;

module mkMemread#(MemreadIndication indication) (Memread);

   MemreadEngineV#(DataBusWidth,NumOutstandingRequests,NumEngineServers) re <- mkMemreadEngineBuff(memreadEngineBufferSize);
   
   Vector#(NumEngineServers, DMAReadIfc) readEngs;
   for (Integer i = 0; i < valueOf(NumEngineServers); i=i+1)
      readEngs[i] <- mkDMAReader(re.readServers[i], re.dataPipes[i]);
   
   Vector#(NumEngineServers, FIFO#(Tuple2#(Bit#(32), Bit#(64)))) dmaReqQs <- replicateM(mkFIFO);
   
   for(Integer i = 0; i < valueOf(NumEngineServers); i=i+1) begin
      rule initDMARead;
         let req <- toGet(dmaReqQs[i]).get();
         readEngs[i].readReq(tpl_1(req), tpl_2(req));
      endrule
   end
   
   let parser <- mkMemReqParser;
   
   mkConnection(parser.inPipe, readEngs[0].response);
   
   rule doHeader;
      let header <- parser.reqHeader.get();
      Vector#(3, Bit#(64)) v = unpack(pack(header));
      indication.readHeader(v[0], v[1], v[2]);
   endrule
   
   rule doKeyTokens;
      let v <- parser.keyPipe.get();
   endrule
   
   rule dokvTokens;
      let v <- parser.keyValPipe.get();
      indication.readTokens(truncate(v), truncateLSB(v));
   endrule
   
   interface dmaClient = re.dmaClient;
   interface MemreadRequest request;
      method Action startRead(Bit#(32) rp, Bit#(64) numBytes);
         $display(valueOf(SizeOf#(Protocol_Binary_Request_Header)));
      $display(valueOf(TDiv#(SizeOf#(Protocol_Binary_Request_Header),8)));
         dmaReqQs[0].enq(tuple2(rp, numBytes));
      endmethod
   endinterface
endmodule



