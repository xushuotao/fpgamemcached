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
import Proc_128::*;
import HashtableTypes::*;
import Hashtable::*;
import ValFlashCtrlTypes::*;
import ValuestrCommon::*;
import DRAMCommon::*;

import AuroraImportFmc1::*;

import ControllerTypes::*;
//import AuroraExtArbiter::*;
//import AuroraExtImport::*;
//import AuroraExtImport117::*;
import AuroraCommon::*;

import ControllerTypes::*;
import FlashCtrlVirtex::*;
import FlashCtrlModel::*;
import FlashServer::*;

typedef 1 NumEngineServers;

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
   method Action startRead(Bit#(32) rp, Bit#(32) numBytes);      
   method Action freeWriteBufId(Bit#(32) wp);
   method Action initDMABufSz(Bit#(32) bufSz);
   method Action initTable(Bit#(64) lgOffset);
   method Action initValDelimit(Bit#(32) randMax1, Bit#(32) randMax2, Bit#(32) randMax3, Bit#(32) lgSz1, Bit#(32) lgSz2, Bit#(32) lgSz3);
   method Action initAddrDelimit(Bit#(32) offset1, Bit#(32) offset2, Bit#(32) offset3);
endinterface

interface Bluecache;
   interface BluecacheRequest request;
   interface MemReadClient#(DataBusWidth) dmaReadClient;
   interface MemWriteClient#(DataBusWidth) dmaWriteClient;
   interface DRAMClient dramClient;
   interface Aurora_Pins#(4) aurora_fmc1;
   interface Aurora_Clock_Pins aurora_clk_fmc1;
   //interface FlashPins flashPins;
endinterface

interface BluecacheIndication;
   method Action eraseDone(Bit#(32) tag, Bit#(32) status);
   method Action dumpMapResp(Bit#(32) blockIdx, Bit#(32) status);
   method Action initDone(Bit#(32) dummy);
   method Action rdDone(Bit#(32) bufId);
   method Action wrDone(Bit#(32) bufId);
   
endinterface

typedef TDiv#(DataBusWidth,32) DataBusWords;

module mkBluecache#(BluecacheIndication indication, Clock clk250) (Bluecache);

   MemreadEngineV#(DataBusWidth,NumOutstandingRequests,NumEngineServers) re <- mkMemreadEngineBuff(memreadEngineBufferSize);
   MemwriteEngineV#(DataBusWidth,NumOutstandingRequests,NumEngineServers) we <- mkMemwriteEngineBuff(memwriteEngineBufferSize);
   
   GtxClockImportIfc gtx_clk_fmc1 <- mkGtxClockImport;
   `ifdef BSIM
   FlashCtrlVirtexIfc flashCtrl <- mkFlashCtrlModel(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
   `else
   FlashCtrlVirtexIfc flashCtrl <- mkFlashCtrlVirtex(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
   `endif
   
   let memcached <- mkMemCached();
   
      
   mkConnection(memcached.server.request, toGet(re.dataPipes[0]));
   mkConnection(memcached.server.response, toPut(we.dataPipes[0]));
   
   mkConnection(memcached.dmaReadClient, re.readServers[0]);
   mkConnection(memcached.dmaWriteClient, we.writeServers[0]);
   
   let flashServer <- mkFlashServer(flashCtrl.user);
   
   mkConnection(flashServer.writeServer, memcached.flashRawWrClient);
   mkConnection(flashServer.readServer, memcached.flashRawRdClient);
   
   rule indicateEraseAck;
      let d <- flashServer.eraseServer.response.get();
      TagT tag = tpl_1(d);
      StatusT st = tpl_2(d);
      Bit#(32) status = 0;
      if ( st == ERASE_ERROR )
         status = 1;
      
      $display("Erase done, send indication, tag = %d, status = %d", tag, status);
      indication.eraseDone(zeroExtend(tag), status);
   endrule
   
   rule indicateDumpMap;
      let d <- flashServer.dumpMap.response.get();
      indication.dumpMapResp(extend(tpl_1(d)), extend(pack(tpl_2(d))));
   endrule
   
   rule doInitDone;
      let d <- memcached.initDone.get();
      $display("FPGA:: send init done");
      indication.initDone(0);
   endrule
   
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
      
      method Action startRead(Bit#(32) readBase, Bit#(32) numBytes);
         memcached.startRead(readBase, numBytes);
      endmethod
   
      method Action freeWriteBufId(Bit#(32) writeBase);
         memcached.freeWriteBufId(writeBase);
      endmethod
      
      method Action initDMABufSz(Bit#(32) bufSz);
         memcached.initDMABufSz(bufSz);
      endmethod
   
      
      method Action initTable(Bit#(64) lgOffset);
         memcached.initDRAMSeg((1 << lgOffset) << 6);
         memcached.htableInit.initTable(lgOffset);
         memcached.valInit.totalSize(fromInteger(dramSize) - ((1 << lgOffset) << 6));
      endmethod
      method Action initValDelimit(Bit#(32) randMax1, Bit#(32) randMax2, Bit#(32) randMax3, Bit#(32) lgSz1, Bit#(32) lgSz2, Bit#(32) lgSz3);
         memcached.valInit.manage_init.initValDelimit(randMax1, randMax2, randMax3, lgSz1, lgSz2, lgSz3);
      endmethod
      method Action initAddrDelimit(Bit#(32) offset1, Bit#(32) offset2, Bit#(32) offset3);
         memcached.valInit.manage_init.initAddrDelimit(offset1, offset2, offset3);
      endmethod
   
      method Action eraseBlock(Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) tag);
         flashServer.eraseServer.request.put(FlashCmd{tag: truncate(tag),
	                                              op: ERASE_BLOCK,
	                                              bus: truncate(bus),
	                                              chip: truncate(chip),
	                                              block: truncate(block),
	                                              page: 0
                                                      });
      endmethod
      method Action populateMap(Bit#(32) idx, Bit#(32) data);
         flashServer.populateMap(truncate(idx), truncate(data));
      endmethod
   
      method Action dumpMap(Bit#(32) dummy);
         flashServer.dumpMap.request.put(?);
      endmethod

   endinterface
   
   interface Aurora_Pins aurora_fmc1 = flashCtrl.aurora;
   interface Aurora_Clock_Pins aurora_clk_fmc1 = gtx_clk_fmc1.aurora_clk;

endmodule



