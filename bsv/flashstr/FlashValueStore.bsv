import AuroraImportFmc1::*;
import ControllerTypes::*;
import FlashServer::*;
import AuroraCommon::*;

import DRAMCommon::*;
import DRAMArbiter::*;

import WriteBuffer::*;

import ValFlashCtrlTypes::*;
import ValFlashCtrl::*;

import Connectable::*;
import GetPut::*;


(*synthesize*)
module mkFlashValueStore(FlashValueStoreIfc);
      
   let writeBuffer <- mkFlashWriteBuffer();
   let valFlashCtrl <- mkValFlashCtrl();
   
   mkConnection(writeBuffer.flashFlClient, valFlashCtrl.flushServer);
   mkConnection(writeBuffer.flashRdClient, valFlashCtrl.readServer);
   
   DRAM_LOCK_Arbiter#(2) dramArb <- mkDRAM_LOCK_Arbiter();
   mkConnection(dramArb.ack, valFlashCtrl.ack);
   
   mkConnection(dramArb.dramServers[0], writeBuffer.dramClient);
   mkConnection(dramArb.dramServers[1], valFlashCtrl.dramClient);

   
   interface FlashWriteServer writeServer = writeBuffer.writeUser;
   interface FlashReadServer readServer = writeBuffer.readUser;
   interface DRAMClient dramClient = dramArb.dramClient;
   interface FlashRawWriteClient flashRawWrClient = valFlashCtrl.flashRawWrClient;
   interface FlashRawReadClient flashRawRdClient = valFlashCtrl.flashRawRdClient;
   interface TagClient tagClient = valFlashCtrl.tagClient;
   
   /*interface FlashPins flashPins;
      interface Aurora_Pins aurora_fmc1 = valFlashCtrl.aurora_fmc1;
      interface Aurora_Clock_Pins aurora_clk_fmc1 = valFlashCtrl.aurora_clk_fmc1;
   endinterface*/
   
endmodule
