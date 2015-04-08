package Valuestr;

import ValDRAMCtrl::*;
import ValueManager::*;
import DRAMArbiterTypes::*;
import DRAMArbiter::*;

interface ValuestrIFC;
   interface ValueDRAMUser dramUser;
   interface ValueAllocIFC allocator;
   interface DRAMClient dramClient;
endinterface

module mkValueStore(ValuestrIFC);
   let cmplBuf <- mkCompletionBuffer();
   let dramAccess <- mkValDRAMCtrl(cmplBuf.updatePort);
   let valMng <- mkValManager(cmplBuf.queryPort);

   DRAMArbiter#(2) dramArb <- mkDRAMArbiter();
   
   mkConnection(dramArb.dramServers[0], dramAccess.dramClient);
   mkConnection(dramArb.dramServers[1], valMng.dramClient);
   
   interface ValueDRAMUser dramUser = dramAccess.user;
   interface ValueAllocIFC allocator = valMng.valAlloc;
   interface DRAMClient dramClient = dramArb.dramClient;
endmodule

endpackage: Valuestr

