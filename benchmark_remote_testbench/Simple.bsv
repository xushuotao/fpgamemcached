
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

import ProtocolHeader::*;
import GetPut::*;
import Vector::*;
import Connectable::*;

//import PortalMemory::*;
import DRAMController::*;
import Dut::*;

import Clocks :: *;
import Xilinx       :: *;

`ifndef BSIM
import XilinxCells ::*;
`endif

import AuroraCommon::*;


import AuroraEndpointHelper::*;

typedef struct{
   Bit#(8) opcode;
   Bit#(8) keylen;
   Bit#(21) vallen;
   Bit#(32) hv;
   } MemReqType_dummy deriving (Bits,Eq);
 

interface SimpleIndication;
   method Action finish(Bit#(64) v);
   method Action dumpReqs(MemReqType_dummy v);
   method Action dumpDta(Bit#(64) v);
   method Action hexDump(Bit#(32) v);
endinterface

interface SimpleRequest;
   method Action start(Bit#(32) numTests);
   method Action dumpStart();
   method Action setNetId(Bit#(32) netid);
   method Action setAuroraExtRoutingTable(Bit#(32) node, Bit#(32) portidx, Bit#(32) portsel);
   method Action auroraStatus(Bit#(32) dummy);
endinterface

interface SimpleIfc;
   interface SimpleRequest request;
   
   interface Vector#(AuroraExtCount, Aurora_Pins#(1)) aurora_ext;
   interface Aurora_Clock_Pins aurora_quad119;
   interface Aurora_Clock_Pins aurora_quad117;
endinterface 


module mkSimpleRequest#(SimpleIndication indication, DRAMControllerIfc dram, Clock clk250, Reset rst250)(SimpleIfc);
   
   RemoteAccessIfc#(1) remote_access <- mkRemoteAccess(clk250, rst250);
   
      
   let dut <- mkProc(remote_access.remotePorts[0]);
   
   rule dumpCmd;
      let v <- dut.dumpReqs.get();
      indication.dumpReqs(unpack(pack(v)));
   endrule
   
   rule dumpDta;
      let v <- dut.dumpDta.get();
      indication.dumpDta(v);
   endrule
   
   rule done;
      let v <- dut.done();
      indication.finish(-1);
   endrule
   
   interface SimpleRequest request;
      method Action start(Bit#(32) numTest);
         $display("Start testing, numTest = %d", numTest);
         dut.start(numTest);
      endmethod
      
      method Action setNetId(Bit#(32) netid);
         remote_access.setNetId(netid);
         dut.setNetId(netid);
      endmethod

      method Action auroraStatus(Bit#(32) dummy);
         let v <- remote_access.auroraStatus();
         indication.hexDump(v);
      endmethod
         
      method Action dumpStart();
         dut.dumpStart();
      endmethod
   
      method Action setAuroraExtRoutingTable(Bit#(32) node, Bit#(32) portidx, Bit#(32) portsel);
	 remote_access.setRoutingTable(truncate(node), truncate(portidx), truncate(portsel));
      endmethod
   
   endinterface
   interface Aurora_Pins aurora_ext = remote_access.aurora_ext;
   interface Aurora_Clock_Pins aurora_quad119 = remote_access.aurora_quad119;
   interface Aurora_Clock_Pins aurora_quad117 = remote_access.aurora_quad117;
   
   
endmodule
