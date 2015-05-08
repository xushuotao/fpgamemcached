package Valuestr;

import Vector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import GetPut::*;
import Pipe::*;
import PipeOutSwitch::*;
import ClientServer::*;
import Connectable::*;

import DRAMCommon::*;
import DRAMArbiter::*;
import DRAMSegment::*;

import AuroraImportFmc1::*;
import MemcachedTypes::*;
import ControllerTypes::*;
import AuroraCommon::*;
import ValuestrCommon::*;

import ValueManager::*;

import ValDRAMCtrl_128::*;
import ValFlashCtrlTypes::*;
import SerDes::*;
import FlashValueStore::*;

import TagAlloc::*;
import MyArbiter::*;
import ValuestrCommon::*;

import RegFile::*;


import ParameterTypes::*;



(*synthesize*)
module mkValueStore(ValuestrIFC);
   FIFO#(ValstrCmdType) reqQ <- mkSizedFIFO(numStages);
   //FIFO#(FlashAddrType) wrRespQ <- mkFIFO;   
   FIFO#(WordT) wordQ <- mkFIFO;

   Vector#(2, FIFOF#(Tuple2#(WordT, TagT))) dramRdRespQs <- replicateM(mkFIFOF);

   FIFO#(Tuple2#(WordT, TagT)) dramRdRespQ <- mkFIFO;


   let dramValueStore <- mkValDRAMCtrl();
   let flashValueStore <- mkFlashValueStore();
   let valMng <- mkValManager;
   
   Vector#(2, FIFOF#(Tuple2#(ValSizeT, TagT))) dramBurstSzQs <- replicateM(mkFIFOF());
   
   Vector#(2, FIFOF#(Tuple2#(ValSizeT, TagT))) burstSzQs <- replicateM(mkFIFOF());
   Vector#(2, FIFOF#(Tuple2#(WordT, TagT))) rdRespQs <- replicateM(mkFIFOF);

   
   mkConnection(dramValueStore.flashWriteClient, flashValueStore.writeServer);
   mkConnection(toPut(dramRdRespQs[0]), flashValueStore.readServer.dramResp);
   
   mkConnection(toPut(dramBurstSzQs[0]), flashValueStore.readServer.dramBurstSz);
   
   mkConnection(toPut(rdRespQs[1]), flashValueStore.readServer.flashResp);
   
   mkConnection(toPut(burstSzQs[1]), flashValueStore.readServer.flashBurstSz);

   
   
   DRAM_LOCK_Arbiter_Bypass#(2) dramArb <- mkDRAM_LOCK_Arbiter_Bypass();
   mkConnection(dramArb.dramServers[0], dramValueStore.dramClient);
   mkConnection(dramArb.dramServers[1], valMng.dramClient);
   
   DRAM_LOCK_SegmentIfc#(2) dramSeg <- mkDRAM_LOCK_Segments;
   
   mkConnection(dramSeg.dramServers[1], dramArb.dramClient);
   mkConnection(dramSeg.dramServers[0], flashValueStore.dramClient);
   
   //RegFile#(TagT, ValSizeT) nBytesTable <- mkRegFileFull;
  
 
   rule doWrReq if (!reqQ.first.rnw);
      let req <- toGet(reqQ).get();
      $display("Issue write req");
      dramValueStore.user.writeReq(ValstrWriteReqT{addr: extend(req.addr.valAddr),
                                                   nBytes: req.nBytes,
                                                   hv: req.hv,
                                                   idx: req.idx,
         
                                                   doEvict: req.doEvict,
                                                   old_hv: req.old_hv,
                                                   old_idx: req.old_idx,
                                                   old_nBytes: req.old_nBytes
                                                   });
   endrule
   
   rule connWrDta;
      let d <- toGet(wordQ).get();
      dramValueStore.user.writeVal(d);
   endrule
   
   FIFO#(Tuple2#(Bit#(32),TagT)) dramTagQ <- mkSizedFIFO(numStages);
   rule doRdReq if (reqQ.first.rnw);
      let req <- toGet(reqQ).get();
      
      //nBytesTable.upd(req.reqId, req.nBytes);
      if (req.addr.onFlash) begin
         //$finish;
         flashValueStore.readServer.request.put(FlashReadReqT{addr: unpack(truncate(req.addr.valAddr)),
                                                                         numBytes: req.nBytes,
                                                                         reqId: req.reqId});
      end
      else begin
         dramValueStore.user.readReq(extend(req.addr.valAddr), extend(req.nBytes));
         dramTagQ.enq(tuple2(extend(req.nBytes),req.reqId));
      end
   endrule
   
   Reg#(Bit#(32)) byteCnt <- mkReg(0);
   rule connDRAMRdDta;
      let v = dramTagQ.first();
      let nBytes = tpl_1(v);
      let tag = tpl_2(v);
      
      if (byteCnt == 0)
         dramBurstSzQs[1].enq(tuple2(truncate(nBytes), tag));

         
      if ( byteCnt + fromInteger(valueOf(WordBytes)) < nBytes) begin
         byteCnt <= byteCnt + fromInteger(valueOf(WordBytes));
      end
      else begin
         byteCnt <= 0;
         dramTagQ.deq();
      end
      let d <- dramValueStore.user.readVal;
      dramRdRespQs[1].enq(tuple2(d, tag));
   endrule

   
   Reg#(ValSizeT) byteCnt_dramResp <- mkReg(0);
   FIFO#(Tuple3#(Bit#(1), ValSizeT, TagT)) nextDramBurst <- mkFIFO();
   
   Reg#(Bit#(32)) debug_cnt <- mkReg(0);
   rule arbDRAMBurst;

      let id <- dramSeg.nextBurstSeg.get();
      $display("%m:: next dramSeg = %d, debug_cnt = %d", id, debug_cnt);
      debug_cnt <= debug_cnt + 1;
      let v <- toGet(dramBurstSzQs[id]).get;
      nextDramBurst.enq(tuple3(id, tpl_1(v), tpl_2(v)));
   endrule
   
   rule doDRAMBurst;
      let v = nextDramBurst.first();
      let sel = tpl_1(v);
      let nBytes = tpl_2(v);
      let reqId = tpl_3(v);
      
      if ( byteCnt_dramResp == 0) 
         burstSzQs[0].enq(tuple2(nBytes, reqId));
      
      if ( byteCnt_dramResp + 16 < nBytes) begin
         byteCnt_dramResp <= byteCnt_dramResp + 16;
      end
      else begin
         byteCnt_dramResp <= 0;
         nextDramBurst.deq();
      end
      let d <- toGet(dramRdRespQs[sel]).get();
      //dramRdRespQ.enq(d);
      rdRespQs[0].enq(d);
   endrule
   


   FIFO#(Tuple2#(WordT, TagT)) rdRespQ <- mkFIFO;
   
   Reg#(ValSizeT) byteCnt_resp <- mkReg(0);
   FIFO#(Tuple3#(Bit#(1), ValSizeT, TagT)) nextBurst <- mkFIFO();
   
   Arbiter_IFC#(2) arbiter <- mkArbiter(False);
   
   for (Integer i = 0; i < 2; i = i + 1) begin
      rule arbitReq ( burstSzQs[i].notEmpty );
         //$display("valuestr, req for burst i = %d", i);
         arbiter.clients[i].request;
      endrule
      
      rule arbitResp if ( arbiter.grant_id == fromInteger(i));
         let v <- toGet(burstSzQs[i]).get;
         //let nBytes = nBytesTable.sub(tpl_2(rdRespQs[i].first));
         nextBurst.enq(tuple3(fromInteger(i), tpl_1(v), tpl_2(v)));
      endrule
   end
   
   FIFO#(Tuple2#(ValSizeT, TagT)) nextRespIdQ <- mkFIFO();
   rule doBurst;
      let v = nextBurst.first();
      let sel = tpl_1(v);
      let nBytes = tpl_2(v);
      let reqId = tpl_3(v);
      
      if ( sel == 1 ) begin
         $display("Dequeueing from flash, reqId = %d, byteCnt_resp = %d, nBytes = %d", reqId, byteCnt_resp, nBytes);
      end
      else begin
         $display("Dequeueing from dram, reqId = %d, byteCnt_resp = %d, nBytes = %d", reqId, byteCnt_resp, nBytes);
      end
      
      if (byteCnt_resp == 0) begin
         nextRespIdQ.enq(tuple2(nBytes,reqId));
      end
      
      if ( byteCnt_resp + 16 < nBytes) begin
         byteCnt_resp <= byteCnt_resp + 16;
      end
      else begin
         byteCnt_resp <= 0;
         nextBurst.deq();
      end
      let d <- toGet(rdRespQs[sel]).get();
      rdRespQ.enq(d);
   endrule
  
   
   
   interface ValuestrWriteServer writeUser;
      interface Server writeServer;
         interface Put request;
            method Action put(ValstrWriteReqT v);
               reqQ.enq(ValstrCmdType{rnw: False,
                                      addr: ValAddrT{onFlash: False, valAddr: truncate(v.addr)},
                                      nBytes: v.nBytes,
                                      reqId: v.reqId,
                                   
                                      doEvict: v.doEvict,
                                      old_hv: v.old_hv,
                                      old_idx: v.old_idx,
                                      old_nBytes: v.old_nBytes
                                      });
            endmethod
         endinterface
         interface Get response = dramValueStore.htableRequest;
      endinterface
   
      interface Put writeWord = toPut(wordQ);
   endinterface
   
   interface ValuestrReadServer readUser;
      interface Put request;
         method Action put(ValstrReadReqT v);
            reqQ.enq(ValstrCmdType{rnw: True,
                                   addr: v.addr,
                                   nBytes: v.nBytes,
                                   reqId: v.reqId
                                   });
         endmethod
      endinterface
      interface Get response = toGet(rdRespQ);
   endinterface
   interface Get nextRespId = toGet(nextRespIdQ);
   
   
   interface ValAllocServer valAllocServer = valMng.server;
   
   interface ValuestrInitIfc valInit;
      interface ValManageInitIFC manage_init = valMng.valInit;
      method Action totalSize(Bit#(64) v);
         dramSeg.initializers[0].put(fromInteger(2*(valueOf(SuperPageSz))));
         dramSeg.initializers[1].put(v-fromInteger(2*(valueOf(SuperPageSz))));
      endmethod
   endinterface
   
   interface DRAMClient dramClient = dramSeg.dramClient;
   interface FlashRawWriteClient flashRawWrClient = flashValueStore.flashRawWrClient;
   interface FlashRawReadClient flashRawRdClient = flashValueStore.flashRawRdClient;
   //interface FlashPins flashPins = flashValueStore.flashPins;
endmodule

endpackage: Valuestr

