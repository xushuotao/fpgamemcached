import AuroraImportFmc1::*;
import ControllerTypes::*;
import AuroraCommon::*;

import DRAMArbiterTypes::*;
import DRAMArbiter::*;
import DRAMPartioner::*;

import WriteBuffer::*;

import ValFlashCtrlTypes::*;
import ValFlashCtrl::*;

import Connectable::*;
import GetPut::*;


interface FlashValueStoreIfc;
   interface FlashWriteBufWrIfc writeServer;
   interface FlashWriteBufRdIfc readServer;
   interface DRAMClient dramClient;
   interface Aurora_Pins#(4) aurora_fmc1;
   interface Aurora_Clock_Pins aurora_clk_fmc1;
endinterface

module mkFlashValueStore#(Clock clk250)(FlashValueStoreIfc);
      
   let writeBuffer <- mkFlashWriteBuffer();
   let valFlashCtrl <- mkValFlashCtrl(clk250);
   
   mkConnection(writeBuffer.flashFlClient, valFlashCtrl.flushServer);
   mkConnection(writeBuffer.flashRdClient, valFlashCtrl.readServer);
   
   DRAMArbiterIfc#(2) dramArb <- mkDRAMArbiter;
   
   mkConnection(dramArb.dramServers[0], writeBuffer.dramClient);
   mkConnection(dramArb.dramServers[1], valFlashCtrl.dramClient);

   
   interface FlashWriteBufWrIfc writeServer = writeBuffer.writeUser;
   interface FlashWriteBufRdIfc readServer = writeBuffer.readUser;
   interface DRAMClient dramClient = dramArb.dramClient;
   interface Aurora_Pins aurora_fmc1 = valFlashCtrl.aurora_fmc1;
   interface Aurora_Clock_Pins aurora_clk_fmc1 = valFlashCtrl.aurora_clk_fmc1;
   
endmodule
