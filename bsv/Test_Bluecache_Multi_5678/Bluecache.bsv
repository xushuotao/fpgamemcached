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
import MemwriteEngine::*;
import Pipe::*;
import HostInterface::*; // for DataBusWidth

import Connectable::*;

import RequestParser::*;
import ProtocolHeader::*;
import DMAHelper::*;
import Proc_128_remote::*;
import HashtableTypes::*;
import Hashtable::*;
import ValFlashCtrlTypes::*;
import ValuestrCommon::*;
import DRAMCommon::*;

import Clocks :: *;
import Xilinx       :: *;
`ifndef BSIM
import XilinxCells ::*;
`endif

import HostFIFO::*;

import AuroraImportFmc1::*;

import ControllerTypes::*;
import AuroraExtArbiterBar::*;
import AuroraExtEndpoint::*;
import AuroraExtImport::*;
//import AuroraExtImport117::*;
import AuroraCommon::*;

import InterFPGAEndpoints::*;

import TagAlloc::*;

import ControllerTypes::*;
import FlashCtrlVirtex::*;
import FlashCtrlModel::*;
import FlashServer::*;

typedef 1 NumEngineServers;
typedef 1 NumReadEngineServers;

`ifdef NumOutstandingRequests
typedef `NumOutstandingRequests NumOutstandingRequests;
`else
`ifdef BSIM
typedef 64 NumOutstandingRequests;
`else
typedef 4 NumOutstandingRequests;
`endif
`endif

Integer memreadEngineBufferSize = 128*valueOf(NumOutstandingRequests);
Integer memwriteEngineBufferSize= 128*valueOf(NumOutstandingRequests);

`ifdef DRAMSize
Integer dramSize = `DRAMSize;
`else
Integer dramSize = valueOf(TExp#(30));
`endif

interface BluecacheRequest;
   method Action eraseBlock(Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) tag);
   method Action populateMap(Bit#(32) idx, Bit#(32) data);
   method Action dumpMap(Bit#(32) dummy);
   method Action initDMARefs(Bit#(32) rp, Bit#(32) wp);
   method Action initDMABufSz(Bit#(32) dmaBufSz);
   method Action startRead(Bit#(32) rp, Bit#(32) numBytes);      
   method Action freeWriteBufId(Bit#(32) wp);
   method Action initTable();
   method Action reset(Bit#(32) randNum);
   
   method Action setNetId(Bit#(32) netid);
   method Action auroraStatus(Bit#(32) dummy);

endinterface

interface Bluecache;
   interface BluecacheRequest request;
   interface MemReadClient#(DataBusWidth) dmaReadClient;
   interface MemWriteClient#(DataBusWidth) dmaWriteClient;
   interface DRAMClient dramClient;
   interface Aurora_Pins#(4) aurora_fmc1;
   interface Aurora_Clock_Pins aurora_clk_fmc1;
   
   interface Vector#(AuroraExtPerQuad, Aurora_Pins#(1)) aurora_ext;
   interface Aurora_Clock_Pins aurora_quad119;
endinterface

interface BluecacheIndication;
   method Action initDone(Bit#(32) dummy);
   method Action rdDone(Bit#(32) bufId);
   method Action wrDone(Bit#(32) bufId);
   method Action hexDump(Bit#(32) hex);
endinterface

typedef TDiv#(DataBusWidth,32) DataBusWords;

module mkBluecache#(BluecacheIndication indication, Clock clk250) (Bluecache);

   //MemreadEngineV#(DataBusWidth,NumOutstandingRequests,NumEngineServers) re <- mkMemreadEngineBuff(memreadEngineBufferSize);
   MemreadEngineV#(DataBusWidth,NumOutstandingRequests,NumReadEngineServers) re <- mkMemreadEngineBuff(memreadEngineBufferSize);
   MemwriteEngineV#(DataBusWidth,NumOutstandingRequests,NumEngineServers) we <- mkMemwriteEngineBuff(memwriteEngineBufferSize);
   
   GtxClockImportIfc gtx_clk_fmc1 <- mkGtxClockImport;
   `ifdef BSIM
   FlashCtrlVirtexIfc flashCtrl <- mkFlashCtrlModel(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
   `else
   FlashCtrlVirtexIfc flashCtrl <- mkFlashCtrlVirtex(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
   `endif
   
   MemCachedIfc#(NumReadEngineServers) memcached <- mkMemCached();
   
   `ifndef BSIM
   ClockDividerIfc auroraExtClockDiv5 <- mkDCMClockDivider(5, 4, clocked_by clk250);
   Clock clk50 = auroraExtClockDiv5.slowClock;
   `else
   Clock clk50 <- exposeCurrentClock;
   `endif

   //Reg#(Bit#(HeaderFieldSz)) myNetIdx <- mkReg(1);
   
   let interfpga <- mkInterFPGAEndpoints;
   mkConnection(interfpga.req_ends, memcached.req_ends);
   mkConnection(interfpga.resp_ends, memcached.resp_ends);
   
   GtxClockImportIfc gtx_clk_119 <- mkGtxClockImport;
   AuroraExtIfc auroraExt119 <- mkAuroraExt(gtx_clk_119.gtx_clk_p_ifc, gtx_clk_119.gtx_clk_n_ifc, clk50);
   
   AuroraExtArbiterBarIfc auroraExtArbiter <- mkAuroraExtArbiterBar(auroraExt119.user, interfpga.endpoints);
   
   for ( Integer i = 0; i < valueOf(NumReadEngineServers); i = i + 1) begin
   //for ( Integer i = 0; i < 8; i = i + 1) begin
      mkConnection(memcached.dmaReadClients[i], re.readServers[i]);
      mkConnection(memcached.inPipes[i], toGet(re.dataPipes[i]));
   end
   //mkConnection(memcached.server.request, toGet(re.dataPipes[0]));
   
   mkConnection(memcached.dmaWriteClient, we.writeServers[0]);
   mkConnection(memcached.server.response, toPut(we.dataPipes[0]));

   // mkConnection(memcached.server.request, toGet(re.dataPipes[0]));
   // mkConnection(memcached.server.response, toPut(we.dataPipes[0]));
   
   // mkConnection(memcached.dmaReadClient, re.readServers[0]);
   // mkConnection(memcached.dmaWriteClient, we.writeServers[0]);

   // `ifdef BSIM
   // let flashServer <- mkFlashServer_dummy(flashCtrl.user);
   // `else
   let flashServer <- mkFlashServer(flashCtrl.user);
   //`endif
   
   mkConnection(flashServer.writeServer, memcached.flashRawWrClient);
   mkConnection(flashServer.readServer, memcached.flashRawRdClient);
   
   
   let tagAlloc <- mkTagAlloc;
   
   TagAllocArbiterIFC#(2) tagArb <- mkTagAllocArbiter();
   
   mkConnection(tagAlloc, tagArb.client);
   
   mkConnection(flashServer.tagClient, tagArb.servers[0]);
   mkConnection(memcached.tagClient, tagArb.servers[1]);
   
   
   rule doRdDone;
      let d <- memcached.rdDone.get();
      $display("FPGA:: send read done, bufId = %d", d);
      indication.rdDone(d);
   endrule
   
   rule doWrDone;
      let d <- memcached.wrDone.get();
      indication.wrDone(d);
      $display("FPGA:: send write done, bufId = %d", d);
   endrule
   
   
   interface MemReadClient dmaReadClient = re.dmaClient;
   interface MemWriteClient dmaWriteClient = we.dmaClient;
   
   interface dramClient = memcached.dramClient;
   
   interface BluecacheRequest request;
   
      method Action initDMARefs(Bit#(32) rp, Bit#(32) wp);
         memcached.initDMARefs(rp, wp);
      endmethod
   
      method Action initDMABufSz(Bit#(32) dmaBufSz);
         memcached.initDMABufSz(dmaBufSz);
      endmethod
      
      method Action startRead(Bit#(32) readBase, Bit#(32) numBytes);
         memcached.startRead(readBase, numBytes);
      endmethod
   
      method Action freeWriteBufId(Bit#(32) writeBase);
         memcached.freeWriteBufId(writeBase);
      endmethod
      
      method Action initTable();
         let v <- memcached.htableInit.initialized;
         $display("FPGA:: send init done");
         indication.initDone(0);
      endmethod
      
      method Action reset(Bit#(32) randNum);
         memcached.reset();
         flashServer.reset(randNum);
      endmethod
   
      method Action setNetId(Bit#(32) netid);
	 //myNetIdx <= truncate(netid);
         memcached.setNodeIdx(truncate(netid));
	 auroraExtArbiter.setMyId(truncate(netid));
	 auroraExt119.setNodeIdx(truncate(netid));
      endmethod
      method Action auroraStatus(Bit#(32) dummy);
	 indication.hexDump({
	                     0,
	                     auroraExt119.user[3].channel_up,
	                     auroraExt119.user[2].channel_up,
	                     auroraExt119.user[1].channel_up,
	                     auroraExt119.user[0].channel_up
            });
      endmethod
   

   endinterface
   
   interface Aurora_Pins aurora_fmc1 = flashCtrl.aurora;
   interface Aurora_Clock_Pins aurora_clk_fmc1 = gtx_clk_fmc1.aurora_clk;
   
   interface Aurora_Pins aurora_ext = auroraExt119.aurora;
   interface Aurora_Clock_Pins aurora_quad119 = gtx_clk_119.aurora_clk;


endmodule



