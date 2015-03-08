
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

typedef enum{Idle, DoSet, DoGet} State deriving (Eq, Bits);


interface SimpleIndication;
    method Action finish(Bit#(64) v, Bit#(64) v2, Bit#(32) hits, Bit#(32) hits2);
endinterface

interface SimpleRequest;
   /*** cmd key dta request ***/
   //method Action start(Bit#(32) numTests);
   method Action start(Bit#(32) numTests, Bit#(64) resetNum);
            
   /*** initialize ****/
   method Action initTable(Bit#(64) lgOffset);
   method Action initValDelimit(Bit#(64) randMax1, Bit#(64) randMax2, Bit#(64) randMax3, Bit#(64) lgSz1, Bit#(64) lgSz2, Bit#(64) lgSz3);
   method Action initAddrDelimit(Bit#(64) offset1, Bit#(64) offset2, Bit#(64) offset3);
   method Action setAuroraExtRoutingTable(Bit#(32) node, Bit#(32) portidx, Bit#(32) portsel);
   method Action setNetId(Bit#(32) netid);
endinterface

interface SimpleIfc;
   interface SimpleRequest request;
   
   interface Vector#(AuroraExtQuad, Aurora_Pins#(1)) aurora_ext;
   interface Aurora_Clock_Pins aurora_quad119;
   //interface Aurora_Clock_Pins aurora_quad117;
endinterface 


module mkSimpleRequest#(SimpleIndication indication, DRAMControllerIfc dram, Clock clk250, Reset rst250)(SimpleIfc);
   MemreadEngineReset#(64,1,1)  re <- mkReadTrafficGen;
//   MemreadEngine#(64,1)  re <- mkReadTrafficGen;
   MemwriteEngine#(64,1) we <- mkWriteTrafficGen;
   
   `ifndef BSIM
   let ila <- mkChipscopeDebug();
   `else
   let ila <- mkChipscopeEmpty();
   `endif
   
   let dmaReader <- mkDMAReader(re.re.readServers[0], re.re.dataPipes[0], ila.ila_dma_0);
   let dmaWriter <- mkDMAWriter(we.writeServers[0], we.dataPipes[0], ila.ila_dma_1);
   
/*   let dmaReader1 <- mkDMAReader(re.readServers[0], re.dataPipes[0], ila.ila_dma_0);
   let dmaWriter1 <- mkDMAWriter(we.writeServers[0], we.dataPipes[0], ila.ila_dma_1);
   */
   RemoteAccessIfc#(1) remote_access <- mkRemoteAccess(clk250, rst250);
   
      
   let memcached <- mkMemCached(dram, dmaReader, dmaWriter, remote_access.remotePorts[0]);//, 0);
   
   //let memcached_remote <- mkMemCached(dram, ?, ?, remote_access.remotePorts[1]);//, 1);
    
   mkConnection(dmaReader.response, memcached.server.request);
  
   mkConnection(memcached.server.response, dmaWriter.request);
   
   
   
   Reg#(Bit#(64)) cycleCnt <- mkRegU();

   
   Reg#(State) state <- mkReg(Idle);
   Reg#(Bit#(64)) cycles_set <- mkRegU();
   
   Reg#(Bit#(32)) testCnt_Set <- mkReg(-1);
   Reg#(Bit#(32)) testMax <- mkReg(0);
   Reg#(Bit#(32)) respCnt_Set <- mkReg(0);
   Reg#(Bit#(32)) respCnt_Get <- mkReg(0);

   Reg#(Bit#(32)) testCnt_Get <- mkReg(-1);
      
   Reg#(Bit#(64)) cycles_get <- mkRegU();
   
   Reg#(Bit#(32)) hits_set <- mkRegU();
   Reg#(Bit#(32)) hits_get <- mkRegU();

   
   (* descending_urgency = "process_done, process_done_2, incr_cnt" *)
   (* conflict_free = "command_issue, process_done"*)
   (* conflict_free = "command_issue_2, process_done_2"*)
   
   rule incr_cnt if ( state != Idle );     //$display(cycleCnt);
      cycleCnt <= cycleCnt + 1;
   endrule

  
   
   rule command_issue (state == DoSet && memcached.htableInit.initialized && testCnt_Set < testMax); // if (started);
                         
      if (testCnt_Set == 0) 
         cycles_set <= cycleCnt;
      
      $display("Issuing command Set %d", testCnt_Set);
      //if ( testCnt[3] == 0 ) begin
      memcached.start(Protocol_Binary_Request_Header{magic:PROTOCOL_BINARY_REQ,
                                                     opcode:PROTOCOL_BINARY_CMD_SET,
                                                     keylen:64,
                                                     extlen:0,
                                                     datatype:?,
                                                     reserved:?,
                                                     bodylen:128,
                                                     opaque: ?,
                                                     cas:?}, 1,2,128,0);
      testCnt_Set <= testCnt_Set + 1;
            
   endrule


   
   
   rule process_done (state == DoSet);// if (started);
      if ( respCnt_Set >= testMax ) begin
         $display("Finish: cycleCnt = %d", cycleCnt);
         //indication.finish(cycleCnt);
         //started <= False;
         cycles_set <= cycleCnt - cycles_set;
         state <= DoGet;
      end
      else begin
         //dmaWriter.done();
         let v <- memcached.done();
         //Protocol_Binary_Response_Header v = unpack(d);
         let header = tpl_1(v);
      //let id = tpl_2(v);
         $display("Memcached sends back indication: opcode = %d", header.opcode);
         
         if ( header.status == PROTOCOL_BINARY_RESPONSE_SUCCESS )
            hits_set <= hits_set + 1;
     
      //indication.done(unpack(pack(header)), id);
         respCnt_Set <= respCnt_Set + 1;
      end
   endrule
   


   rule command_issue_2 (state == DoGet && memcached.htableInit.initialized && testCnt_Get < testMax); //if (started);

      
      if (testCnt_Get == 0) 
         cycles_get <= cycleCnt;
      
      
      $display("Issuing command %d", testCnt_Get);
      //if ( testCnt_Get[3] == 0 ) begin
      memcached.start(Protocol_Binary_Request_Header{magic:PROTOCOL_BINARY_REQ,
                                                     opcode:PROTOCOL_BINARY_CMD_GET,
                                                     keylen:64,
                                                     extlen:0,
                                                     datatype:?,
                                                     reserved:?,
                                                     bodylen:64,
                                                     opaque: ?,
                                                     cas:?}, 1,2,64,0);
      testCnt_Get <= testCnt_Get + 1;


      
   endrule


   
   rule process_done_2 (state == DoGet);// if (started);
      if ( respCnt_Get >= testMax ) begin
         $display("Finish: cycleCnt = %d", cycleCnt);
         //indication.finish(cycleCnt);
         //started <= False;
         //cycle_set <= cycleCnt - cycle_set;
         state <= Idle;
         indication.finish(cycles_set, cycleCnt - cycles_get, hits_set, hits_get);
      end
      else begin
         //dmaWriter.done();
         let v <- memcached.done();
         //Protocol_Binary_Response_Header v = unpack(d);
         let header = tpl_1(v);
      //let id = tpl_2(v);
         $display("Memcached sends back indication: opcode = %d", header.opcode);
     
         if ( header.status == PROTOCOL_BINARY_RESPONSE_SUCCESS )
            hits_get <= hits_get + 1;
      //indication.done(unpack(pack(header)), id);
         respCnt_Get <= respCnt_Get + 1;
      end
   endrule
   
   
   interface SimpleRequest request;
      method Action start(Bit#(32) numTest, Bit#(64) resetNum);
         $display("Start testing, numTest = %d", numTest);
         testMax <= numTest;
         //started <= True;
         state <= DoSet;
         testCnt_Set <= 0;
         testCnt_Get <= 0;
         cycleCnt <= 0;
         respCnt_Set <= 0;
         respCnt_Get <= 0;
         hits_get <= 0;
         hits_set <= 0;
         
         re.setReset(resetNum);
      endmethod

   
      method Action initTable(Bit#(64) lgOffset);
         memcached.htableInit.initTable(lgOffset);
      endmethod
   
      method Action initValDelimit(Bit#(64) randMax1, Bit#(64) randMax2, Bit#(64) randMax3, Bit#(64) lgSz1, Bit#(64) lgSz2, Bit#(64) lgSz3);
         $display("Server initializing val store size delimiter");
         memcached.valInit.initValDelimit(randMax1, randMax2, randMax3, lgSz1, lgSz2, lgSz3);
      endmethod
   
      method Action initAddrDelimit(Bit#(64) offset1, Bit#(64) offset2, Bit#(64) offset3);
         $display("Server initializing val store addr delimiter");
         memcached.valInit.initAddrDelimit(offset1, offset2, offset3);
         //memcached.htableInit.initTable(lgOffset1);
      endmethod
 
      method Action setNetId(Bit#(32) netid);
         remote_access.setNetId(netid);
         memcached.setNetId(netid);
      endmethod
   
      method Action setAuroraExtRoutingTable(Bit#(32) node, Bit#(32) portidx, Bit#(32) portsel);
	 remote_access.setRoutingTable(truncate(node), truncate(portidx), truncate(portsel));
      endmethod
      
   endinterface
   interface Aurora_Pins aurora_ext = remote_access.aurora_ext;
   interface Aurora_Clock_Pins aurora_quad119 = remote_access.aurora_quad119;
   //interface Aurora_Clock_Pins aurora_quad117 = remote_access.aurora_quad117;
endmodule
