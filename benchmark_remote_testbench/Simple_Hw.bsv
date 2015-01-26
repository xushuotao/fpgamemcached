
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
import MemTypes::*;
import MemEngineTG::*;
import Pipe::*;

import DMAHelper::*;

import DRAMController::*;
import Proc::*;
import Hashtable::*;
import Valuestr::*;

import IlaWrapper::*;
import Clocks :: *;
import Xilinx       :: *;

`ifndef BSIM
import XilinxCells ::*;
`endif

import AuroraCommon::*;
import AuroraEndpointHelper::*;
//import AuroraEndpointHelper_Verifier::*;


interface SimpleIndication;
    method Action finish(Bit#(64) v);
endinterface

interface SimpleRequest;
   /*** cmd key dta request ***/
   method Action start(Bit#(32) numTests);
   
   /*** initialize ****/
   method Action initTable(Bit#(64) lgOffset);
   method Action initValDelimit(Bit#(64) randMax1, Bit#(64) randMax2, Bit#(64) randMax3, Bit#(64) lgSz1, Bit#(64) lgSz2, Bit#(64) lgSz3);
   method Action initAddrDelimit(Bit#(64) offset1, Bit#(64) offset2, Bit#(64) offset3);
   method Action setAuroraExtRoutingTable(Bit#(32) node, Bit#(32) portidx, Bit#(32) portsel);
   method Action setNetId(Bit#(32) netid);
endinterface

interface SimpleIfc;
   interface SimpleRequest request;
   
   interface Vector#(AuroraExtCount, Aurora_Pins#(1)) aurora_ext;
   interface Aurora_Clock_Pins aurora_quad119;
   interface Aurora_Clock_Pins aurora_quad117;
endinterface 


module mkSimpleRequest#(SimpleIndication indication, DRAMControllerIfc dram, Clock clk250, Reset rst250)(SimpleIfc);
   
   MemreadEngine#(64,1)  re <- mkReadTrafficGen;
   MemwriteEngine#(64,1) we <- mkWriteTrafficGen;
   
   `ifndef BSIM
   let ila <- mkChipscopeDebug();
   `else
   let ila <- mkChipscopeEmpty();
   `endif
   
   let dmaReader <- mkDMAReader(re.readServers[0], re.dataPipes[0], ila.ila_dma_0);
   let dmaWriter <- mkDMAWriter(we.writeServers[0], we.dataPipes[0], ila.ila_dma_1);
   
/*   let dmaReader1 <- mkDMAReader(re.readServers[0], re.dataPipes[0], ila.ila_dma_0);
   let dmaWriter1 <- mkDMAWriter(we.writeServers[0], we.dataPipes[0], ila.ila_dma_1);
   */
   RemoteAccessIfc#(1) remote_access <- mkRemoteAccess(clk250, rst250);
   
      
   let memcached <- mkMemCached(dram, dmaReader, dmaWriter, remote_access.remotePorts[0], 0);
   
   //let memcached_remote <- mkMemCached(dram, ?, ?, remote_access.remotePorts[1], 1);
   
   mkConnection(dmaReader.response, memcached.server.request);
  
   mkConnection(memcached.server.response, dmaWriter.request);
   
   
   
   Reg#(Bit#(32)) testCnt <- mkReg(-1);
   Reg#(Bit#(32)) testMax <- mkReg(0);
   
   Reg#(Bool) started <- mkReg(False);
   Reg#(Bit#(64)) cycleCnt <- mkRegU();
   Reg#(Bit#(32)) testCnt2 <- mkReg(0);
   rule process_done if (started);
      if ( testCnt2 >= testMax ) begin
         $display("Finish: cycleCnt = %d", cycleCnt);
         indication.finish(cycleCnt);
         started <= False;
      end
      else begin
         //dmaWriter.done();
         let v <- memcached.done();
         //Protocol_Binary_Response_Header v = unpack(d);
         let header = tpl_1(v);
      //let id = tpl_2(v);
         $display("Memcached sends back indication: opcode = %d", header.opcode);
     
      //indication.done(unpack(pack(header)), id);
         testCnt2 <= testCnt2 + 1;
      end
   endrule
   
   (* descending_urgency = "command_issue, incr_cnt" *)
   
   rule incr_cnt;     //$display(cycleCnt);
      cycleCnt <= cycleCnt + 1;
   endrule
   
   rule command_issue if (started);
      let init = memcached.htableInit.initialized;
      if (init) begin
         if (testCnt == 0) cycleCnt <= 0;
         if (testCnt < testMax) begin
            $display("Issuing command %d", testCnt);
            if ( testCnt[3] == 0 ) begin
               memcached.start(Protocol_Binary_Request_Header{magic:PROTOCOL_BINARY_REQ,
                                                              opcode:PROTOCOL_BINARY_CMD_SET,
                                                              keylen:64,
                                                              extlen:0,
                                                              datatype:?,
                                                              reserved:?,
                                                              bodylen:128,
                                                              opaque: ?,
                                                              cas:?}, 1,2,128,0);
            end
            else begin
               memcached.start(Protocol_Binary_Request_Header{magic:PROTOCOL_BINARY_REQ,
                                                              opcode:PROTOCOL_BINARY_CMD_GET,
                                                              keylen:64,
                                                              extlen:0,
                                                              datatype:?,
                                                              reserved:?,
                                                              bodylen:64,
                                                              opaque: ?,
                                                              cas:?}, 1,2,64,0);
            end
            testCnt <= testCnt + 1;
         end
      end
   endrule

   
   interface SimpleRequest request;
      method Action start(Bit#(32) numTest);
         $display("Start testing, numTest = %d", numTest);
         testMax <= numTest;
         started <= True;
         testCnt <= 0;
         //cycleCnt <= 0;
         testCnt2 <= 0;
      endmethod
   
      method Action initTable(Bit#(64) lgOffset);
         memcached.htableInit.initTable(lgOffset);
         //memcached_remote.htableInit.initTable(lgOffset);
      endmethod
   
      method Action initValDelimit(Bit#(64) randMax1, Bit#(64) randMax2, Bit#(64) randMax3, Bit#(64) lgSz1, Bit#(64) lgSz2, Bit#(64) lgSz3);
         $display("Server initializing val store size delimiter");
         memcached.valInit.initValDelimit(randMax1, randMax2, randMax3, lgSz1, lgSz2, lgSz3);
         //memcached_remote.valInit.initValDelimit(randMax1, randMax2, randMax3, lgSz1, lgSz2, lgSz3);
      endmethod
   
      method Action initAddrDelimit(Bit#(64) offset1, Bit#(64) offset2, Bit#(64) offset3);
         $display("Server initializing val store addr delimiter");
         memcached.valInit.initAddrDelimit(offset1, offset2, offset3);
         //memcached_remote.valInit.initAddrDelimit(offset1, offset2, offset3);
      endmethod
 
      method Action setNetId(Bit#(32) netid);
         remote_access.setNetId(netid);
      endmethod
   
      method Action setAuroraExtRoutingTable(Bit#(32) node, Bit#(32) portidx, Bit#(32) portsel);
	 remote_access.setRoutingTable(truncate(node), truncate(portidx), truncate(portsel));
      endmethod
      
   endinterface
   interface Aurora_Pins aurora_ext = remote_access.aurora_ext;
   interface Aurora_Clock_Pins aurora_quad119 = remote_access.aurora_quad119;
   interface Aurora_Clock_Pins aurora_quad117 = remote_access.aurora_quad117;
   

endmodule
