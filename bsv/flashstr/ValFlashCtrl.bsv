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
   interface TagClient tagClient;
   interface Put#(Bool) ack;
endinterface

(*synthesize*)
module mkValFlashCtrl(ValFlashCtrlUser);
  
   let flusher <- mkEvictionBufFlush();
   let reader <- mkFlashReader();
   
   
   TagAllocArbiterIFC#(2) tagArb <- mkTagAllocArbiter();
   
   
   mkConnection(flusher.tagClient, tagArb.servers[0]);
   mkConnection(reader.tagClient, tagArb.servers[1]);
   
      
   interface FlushServer flushServer = flusher.flushServer;
   interface FlashReadServer readServer = reader.server;
   interface DRAMClient dramClient = flusher.dramClient;
   
   interface FlashRawWriteClient flashRawWrClient = flusher.flashRawWrClient;
   interface FlashRawReadClient flashRawRdClient = reader.flashRawRdClient;
   
   interface TagClient tagClient = tagArb.client;
   interface Put ack = flusher.dramAck;
   
endmodule
   
