import Clocks :: *;
import Xilinx       :: *;
`ifndef BSIM
import XilinxCells ::*;
`endif

import AuroraImportFmc1::*;
import ControllerTypes::*;
import AuroraCommon::*;

import ControllerTypes::*;
import FlashCtrlVirtex::*;
import FlashCtrlModel::*;

import ValFlashCtrlTypes::*;
import DRAMCommon::*;
import TagAlloc::*;
import DRAMSegment::*;
import FlashReader::*;
import FlashWriter::*;
import FlashServer::*;
import Connectable::*;
import GetPut::*;


interface ValFlashCtrlUser;
   interface FlushServer flushServer;
   interface FlashReadServer readServer;
   interface DRAM_LOCK_Client dramClient;
   interface FlashRawWriteClient flashRawWrClient;
   interface FlashRawReadClient flashRawRdClient;
   //interface Aurora_Pins#(4) aurora_fmc1;
   //interface Aurora_Clock_Pins aurora_clk_fmc1;
endinterface

(*synthesize*)
module mkValFlashCtrl(ValFlashCtrlUser);
   /*
   GtxClockImportIfc gtx_clk_fmc1 <- mkGtxClockImport;
   `ifdef BSIM
   FlashCtrlVirtexIfc flashCtrl <- mkFlashCtrlModel(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
   `else
   FlashCtrlVirtexIfc flashCtrl <- mkFlashCtrlVirtex(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
   `endif
   */
   let flusher <- mkEvictionBufFlush();
   let reader <- mkFlashReader();
   
   let tagAlloc <- mkTagAlloc;
   
   TagAllocArbiterIFC#(2) tagArb <- mkTagAllocArbiter();
   
   mkConnection(tagAlloc, tagArb.client);
   
   mkConnection(flusher.tagClient, tagArb.servers[0]);
   mkConnection(reader.tagClient, tagArb.servers[1]);
   
   DRAM_LOCK_Segment_Bypass#(2) dramPar <- mkDRAM_LOCK_Segments_Bypass;
   
   mkConnection(dramPar.dramServers[0], flusher.dramClients[0]);
   mkConnection(dramPar.dramServers[1], flusher.dramClients[1]);
   
   Reg#(Bool) initFlag <- mkReg(False);
   rule init if (!initFlag);
      dramPar.initializers[0].put(fromInteger(valueOf(SuperPageSz)));
      dramPar.initializers[1].put(fromInteger(valueOf(SuperPageSz)));
      initFlag <= True;
   endrule
   
   
   interface FlushServer flushServer = flusher.flushServer;
   interface FlashReadServer readServer = reader.server;
   interface DRAM_LOCK_Client dramClient = dramPar.dramClient;
   
   interface FlashRawWriteClient flashRawWrClient = flusher.flashRawWrClient;
   interface FlashRawReadClient flashRawRdClient = reader.flashRawRdClient;
   /*
   interface Aurora_Pins aurora_fmc1 = flashCtrl.aurora;
   interface Aurora_Clock_Pins aurora_clk_fmc1 = gtx_clk_fmc1.aurora_clk;
   */
endmodule
   
