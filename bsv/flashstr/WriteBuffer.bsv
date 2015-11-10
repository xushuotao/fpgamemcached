import ControllerTypes::*;
//import ValDRAMCtrlTypes::*;
import MemcachedTypes::*;
import ValuestrCommon::*;
import ValFlashCtrlTypes::*;
import FlashWriter::*;
import FlashReader::*;
import Time::*;

import DRAMCommon::*;
import DRAMSegment::*;
import SerDes::*;
import Align::*;
import MyArbiter::*;

import Shifter::*;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import GetPut::*;
import Vector::*;
import Connectable::*;
import ClientServer::*;
import RegFile::*;
import ClientServerHelper::*;

interface FlashWriteBufIfc;
   interface FlashWriteServer writeUser;
   //interface FlashReadServer readUser;
   interface FlashValueStoreReadServer readUser;
   interface FlushClient flashFlClient;
   interface FlashReadClient flashRdClient;
   interface DRAM_LOCK_Client dramClient;
endinterface

typedef struct{
   Bool rnw;
   FlashAddrType addr;
   ValSizeT numBytes;
   Bit#(1) bufId;
   TagT reqId;
   } WriteBufCmdT deriving (Bits, Eq);


Integer flashHeaderSz = valueOf(TSub#(BytesOf#(ValHeader),BytesOf#(Time_t)));

(*synthesize*)
module mkFlashWriteBuffer(FlashWriteBufIfc);
   Vector#(2,FIFO#(DRAM_LOCK_Req)) dramCmdQs <- replicateM(mkFIFO);
   Vector#(2,FIFO#(Bit#(512))) dramDtaQs <- replicateM(mkFIFO);
   
   Reg#(SuperPageIndT) superPageCnt <- mkReg(0);      
   
   /* processing write commands */
   //FIFO#(ValSizeT) writeReqQ <- mkFIFO;
   FIFO#(WriteBufCmdT) reqQ <- mkSizedFIFO(valueOf(NumTags));
   FIFO#(WriteBufCmdT) dramReqQ <- mkFIFO;
   
   Vector#(2, FIFOF#(Tuple2#(ValSizeT, TagT))) burstSzQs <- replicateM(mkSizedFIFOF(32));
   FIFO#(ValSizeT) burstSzQ <- mkFIFO();
   
   FIFO#(Bit#(512)) inDataQ <- mkFIFO;
   FIFO#(FlashAddrType) respQ <- mkBypassFIFO;
   /* send dram cmd to write the dram write buf */
   
   Reg#(Bit#(1)) currBuf <- mkReg(0);
   Vector#(2, Reg#(Bool)) writeLocks <- replicateM(mkReg(False));
   Vector#(2, Reg#(Bool)) clean <- replicateM(mkReg(True));
   
   Vector#(2,Reg#(Bit#(TAdd#(TLog#(SuperPageSz),1)))) byteCnt_seg_V <- replicateM(mkReg(0));
   Vector#(2,Reg#(Bit#(TAdd#(TLog#(SuperPageSz),1)))) byteCnt_wr_V <- replicateM(mkReg(0));
   
   //ByteDeAlignIfc#(Bit#(512), Bit#(1)) deAlign <- mkByteDeAlignPipeline;
   ByteDeAlignIfc#(Bit#(512), Bit#(1)) deAlign <- mkByteDeAlignCombinational;
   mkConnection(deAlign.inPipe, toGet(inDataQ));
   
   FIFO#(FlushReqT) flushReqQ <- mkFIFO();
   FIFO#(Bit#(1)) flushRespQ <- mkFIFO();
   rule doWriteBuf if ( !reqQ.first.rnw );
      let req = reqQ.first;
      let numBytes = req.numBytes;
      //**** select which buffer to write *****
      let bufIdx = currBuf;
      Bool block = False;
      SuperPageIndT superPageId = superPageCnt;
      //**** if current writeBuf is full
      if ( byteCnt_seg_V[currBuf] + extend(numBytes) > fromInteger(superPageSz) ) begin
         //*** lock the current buffer for flushing and use the next writeBuf
         if ( !writeLocks[currBuf] && !writeLocks[currBuf+1]  ) begin
            writeLocks[currBuf] <= True;
            superPageCnt <= superPageCnt + 1;
            superPageId = superPageId + 1;
            flushReqQ.enq(FlushReqT{segId: superPageCnt, bufId: currBuf});
            clean[currBuf] <= True;
            
            bufIdx = bufIdx + 1;
            currBuf <= currBuf + 1;
            clean[currBuf + 1] <= False;
         end
         //*** if next writeBuf is still being dumped
         else begin
            $display("blocked");
            block = True;
         end
      end
      

      Bit#(TLog#(SuperPageSz)) byteCnt_seg = truncate(byteCnt_seg_V[bufIdx]);
      
      if ( !block ) begin
         $display("not blocked");
         deAlign.deAlign(truncate(byteCnt_seg), extend(numBytes), bufIdx);
         byteCnt_seg_V[bufIdx] <= byteCnt_seg_V[bufIdx] + extend(numBytes);
         dramReqQ.enq(req);
         reqQ.deq();
         $display("WrAck addr = %d", {superPageId, byteCnt_seg});
         respQ.enq(unpack({superPageId, byteCnt_seg}));
      end
   endrule
   
   rule doUnlockBuf;
      let bufId <- toGet(flushRespQ).get();
      writeLocks[bufId] <= False;
      byteCnt_seg_V[bufId] <= 0;
      byteCnt_wr_V[bufId] <= 0;
   endrule
   
   
   Reg#(ValSizeT) byteCnt_Wr <- mkReg(0);
   rule driveDRAMWriteCmd if (!dramReqQ.first.rnw);
      let args = dramReqQ.first();
      
      let v <- deAlign.outPipe.get();
      let data = tpl_1(v);
      let nBytes = tpl_2(v);
      let dramSel = tpl_3(v);
      
      let addr = byteCnt_wr_V[dramSel];
      
      $display("%m:: writeBuf dramWr[dramSel = %d], addr = %d, data = %h, nBytes = %d, byteCnt_wr = %d, byteMax = %d", dramSel, addr, data, nBytes, byteCnt_Wr, args.numBytes);
      byteCnt_wr_V[dramSel] <= byteCnt_wr_V[dramSel] + extend(nBytes);
      dramCmdQs[dramSel].enq(DRAM_LOCK_Req{initlock: False, rnw: False, addr: extend(addr), data: data, numBytes: nBytes, lock:False, ignoreLock: True});
      
      if ( byteCnt_Wr + extend(nBytes) == args.numBytes ) begin
         byteCnt_Wr <= 0;
         dramReqQ.deq();
      end
      else begin
         byteCnt_Wr <= byteCnt_Wr + extend(nBytes);
      end
      
   endrule
   
   // processing read commands
   RegFile#(TagT, ValSizeT) readCmdLUT <- mkRegFileFull;
    
   FIFO#(FlashReadReqT) flashRdReqQ <- mkFIFO;
   FIFO#(Tuple2#(WordT, TagT)) flashRdRespQ <- mkFIFO;
   
   //ByteAlignIfc#(Bit#(512), TagT) align <- mkByteAlignPipeline;
   ByteAlignIfc#(Bit#(512), TagT) align <- mkByteAlignCombinational_debug;
 
   rule doReadCmd if (reqQ.first.rnw);
      let req <- toGet(reqQ).get();
      FlashAddrType addr = unpack(pack(req.addr) + fromInteger(flashHeaderSz));
      //FlashAddrType addr = unpack(pack(req.addr));// Test Purposes
      req.addr = addr;
      let numBytes = req.numBytes;
      let reqId = req.reqId;
      
      readCmdLUT.upd(reqId, numBytes);
      
      SuperPageIndT currSegId = truncateLSB(pack(addr));
      $display("FlashSore serve read: addr = %d, currSegId = %d, superPageCnt = %d, currBuf = %d", addr, currSegId, superPageCnt, currBuf);
      if (currSegId == superPageCnt) begin
         // do dram Read
         $display("Serve Flash Read commmand from DRAM reqId = %d", reqId);
         req.bufId = currBuf;
         //burstSzQs[0].enq(tuple2(extend(numBytes), reqId));
         dramReqQ.enq(req);
         //reqQ.deq();
         Bit#(6) byteOffset = truncate(pack(addr));
         //align.align(byteOffset, extend(numBytes), reqId);
      end
      else if (currSegId == superPageCnt - 1 && clean[~currBuf]) begin
         // do dram Read
         $display("Serve Flash Read commmand from DRAM reqId = %d", reqId);
         req.bufId = ~currBuf;
         dramReqQ.enq(req);
         //burstSzQs[0].enq(tuple2(extend(numBytes), reqId));
         //reqQ.deq();
         Bit#(6) byteOffset = truncate(pack(addr));
         //align.align(byteOffset, extend(numBytes), reqId);
      end
      else begin
         //flash read
         $display("Serve Flash Read command from Flash reqId = %d", reqId);
         flashRdReqQ.enq(FlashReadReqT{addr: addr, numBytes: numBytes, reqId: reqId});
      end
   endrule
   
   FIFO#(Tuple4#(Bit#(1), ValSizeT, TagT, Bit#(7))) dramSelQ <- mkSizedFIFO(32);   
   Reg#(ValSizeT) byteCnt_Rd <- mkReg(0);
   rule driveDRAMReadCmd if (dramReqQ.first.rnw);
      let v = dramReqQ.first();
      Bit#(TLog#(SuperPageSz)) currAddr = truncate(pack(v.addr));
      let numBytes = v.numBytes;
      let dramSel = v.bufId;
      
      let addr = currAddr + truncate(byteCnt_Rd);
      let rowidx = addr >> 6;
      
      Bit#(6) byteOffset = truncate(currAddr);
      Bit#(7) nBytes = ?;

      if (addr[5:0] == 0) begin
         nBytes = 64;
      end
      else begin
         nBytes = 64 - extend(byteOffset);
      end
      
      Bool lock = True;
      if (byteCnt_Rd + extend(nBytes) < numBytes) begin
         byteCnt_Rd <= byteCnt_Rd + extend(nBytes);
           end
      else begin
         lock = False;
         byteCnt_Rd <= 0;
         dramReqQ.deq();
      end
      
      Bool initlock = False;
      if ( byteCnt_Rd == 0)
         initlock = True;
      
      $display("writeBuf dramRd, reqId = %d, dramSel = %d, addr = %d, byteCnt_Rd = %d, nBytes = %d", v.reqId, dramSel, rowidx << 6, byteCnt_Rd, nBytes);
      dramCmdQs[dramSel].enq(DRAM_LOCK_Req{initlock: initlock, rnw:True, addr: extend(rowidx << 6), data:?, numBytes:nBytes, lock: lock, ignoreLock: False});
      dramSelQ.enq(tuple4(dramSel, numBytes, v.reqId, nBytes));
   endrule
   
   FIFO#(Bit#(512)) dramDtaQ <- mkFIFO();
   mkConnection(toGet(dramDtaQ), align.inPipe);
            
   for (Integer i = 0; i < 2; i = i + 1) begin
      Reg#(ValSizeT) byteCnt_bucket <- mkReg(0);
      Reg#(Bit#(32)) wordCnt <- mkReg(0);
      rule doDeqDramDta if ( tpl_1(dramSelQ.first) == fromInteger(i));
         let d = dramSelQ.first();
         dramSelQ.deq();
         let dta <- toGet(dramDtaQs[i]).get();
         let numBytes = tpl_2(d);
         let reqId = tpl_3(d);
         let byteIncr = tpl_4(d);
         
         Bit#(6) byteOffset = truncate(64-byteIncr); 

         $display("Dram Response dramDtaQ[%d] reqId = %d, byteCnt = %d, byteIncr = %d, maxBytes = %d, wordCnt = %d, got data = %h", i, tpl_3(d), byteCnt_bucket, tpl_4(d), tpl_2(d), wordCnt, dta);

         if (byteCnt_bucket == 0) begin
            align.align(byteOffset, extend(numBytes), reqId);
            burstSzQs[0].enq(tuple2(extend(numBytes), reqId));
         end
         
         //if ( byteCnt_debug + 64 >= 12281 )
         if ( byteCnt_bucket + extend(tpl_4(d)) >= tpl_2(d)) begin
            byteCnt_bucket <= 0;
            wordCnt <= 0;
         end
         else begin
            byteCnt_bucket <= byteCnt_bucket + extend(tpl_4(d));
            wordCnt <= wordCnt + 1;
         end
         
         dramDtaQ.enq(dta);
      endrule
   end
   
   
   SerializerIfc#(512, WordSz, TagT) ser <- mkSerializer();
   
   Reg#(Bit#(32)) byteCnt_shit <- mkReg(0);
      
   rule doSer;
      let v <- align.outPipe.get();
      let data = tpl_1(v);
      let numBytes = tpl_2(v);
      let reqId = tpl_3(v);
      /*
      Bit#(4) numWords = truncate(numBytes >> 3);
      if ( numBytes[2:0] != 0)
         numWords = numWords + 1;
      */
      if ( byteCnt_shit + extend(numBytes) >= 12281 )
         byteCnt_shit <= 0;
      else
         byteCnt_shit <= byteCnt_shit + extend(numBytes);
      
      $display("writeBuf RdResp: aligner got reqId = %d, data = %h, byteCnt_shit = %d, numBytes = %d", reqId, data, byteCnt_shit, numBytes);
      Bit#(TAdd#(TLog#(TDiv#(512, WordSz)),1)) numWords = truncate(numBytes >> valueOf(TLog#(WordBytes)));
      Bit#(TLog#(WordBytes)) remainder = truncate(numBytes);
      if ( remainder != 0)
         numWords = numWords + 1;
      ser.marshall(data, numWords, reqId);
   endrule    
   
   
   
   Vector#(2, FIFOF#(Tuple2#(WordT, TagT))) respDtaQs <- replicateM(mkFIFOF);
   FIFO#(Tuple2#(WordT, TagT)) respDtaQ <- mkFIFO;
      
   Reg#(Bit#(32)) byteCnt_debug <- mkReg(0);
   rule doDeqDramRes;
      let d <- ser.getVal;
      respDtaQs[0].enq(d);
      $display("%m:: WriteBuf got data from DRAM, byteCnt = %d, d = %h, reqid = %d", byteCnt_debug, tpl_1(d), tpl_2(d));
      if ( byteCnt_debug + 16 >= 12281 )
         byteCnt_debug <= 0;
      else
         byteCnt_debug <= byteCnt_debug + 16;
   endrule
   
   rule doDeqFlashRes;
      let d <- toGet(flashRdRespQ).get();
      respDtaQs[1].enq(d);
   endrule
   /*
   Reg#(ValSizeT) byteCnt_resp <- mkReg(0);
  
   FIFO#(Tuple2#(Bit#(1), ValSizeT)) nextBurst <- mkBypassFIFO();
   
   Arbiter_IFC#(2) arbiter <- mkArbiter(False);
   for (Integer i = 0; i < 2; i = i + 1) begin
      rule doReqs_0 if (burstSzQs[i].notEmpty);
         arbiter.clients[i].request;
      endrule
      
      rule doReqs_1 if (arbiter.grant_id == fromInteger(i));
         let nBytes <- toGet(burstSzQs[i]).get();
         burstSzQ.enq(nBytes);
         nextBurst.enq(tuple2(fromInteger(i), nBytes));
      endrule
   end
   
   rule doBurst;

      let v = nextBurst.first();
      let sel = tpl_1(v);
      let nBytes = tpl_2(v);
      $display("%m:: byteCnt_resp = %d, nBytes = %d, sel = %d", byteCnt_resp, nBytes, sel);
      if ( byteCnt_resp + 16 < nBytes) begin
         byteCnt_resp <= byteCnt_resp + 16;
      end
      else begin
         byteCnt_resp <= 0;
         nextBurst.deq();
      end
      let d <- toGet(respDtaQs[sel]).get();
      respDtaQ.enq(d);
   endrule
  */

   Vector#(2,DRAM_LOCK_Client) dramClients;
   for (Integer i = 0; i < 2; i = i + 1)
      dramClients[i] = toClient(dramCmdQs[i], dramDtaQs[i]);
   
   DRAM_LOCK_Segment_Bypass#(2) dramPar <- mkDRAM_LOCK_Segments_Bypass;
   
   mkConnection(dramPar.dramServers[0], dramClients[0]);
   mkConnection(dramPar.dramServers[1], dramClients[1]);
   
   Reg#(Bool) initFlag <- mkReg(False);
   rule init if (!initFlag);
      dramPar.initializers[0].put(fromInteger(valueOf(SuperPageSz)));
      dramPar.initializers[1].put(fromInteger(valueOf(SuperPageSz)));
      initFlag <= True;
   endrule

                  

   interface FlashWriteServer writeUser;
      interface Server writeServer;
         interface Put request;
            method Action put(ValSizeT v);
               reqQ.enq(WriteBufCmdT{rnw: False, numBytes: v});
            endmethod
         endinterface
         interface Get response = toGet(respQ);
      endinterface
      interface Put writeWord = toPut(inDataQ);
   endinterface
   
   interface FlashValueStoreReadServer readUser;
      interface Put request;
         method Action put(FlashReadReqT v);
            reqQ.enq(WriteBufCmdT{rnw: True, addr: v. addr, numBytes: v.numBytes, reqId: v.reqId});
         endmethod
      endinterface
      interface Get dramResp = toGet(respDtaQs[0]);
      interface Get flashResp = toGet(respDtaQs[1]);
      interface Get dramBurstSz = toGet(burstSzQs[0]);
      interface Get flashBurstSz = toGet(burstSzQs[1]);
   endinterface
   
   interface FlushClient flashFlClient = toClient(flushReqQ, flushRespQ);
   interface FlashReadClient flashRdClient;
      interface Server readClient = toClient(flashRdReqQ, flashRdRespQ);
      interface Put burstSz = toPut(burstSzQs[1]);
   endinterface
   
   interface DRAMClient dramClient = dramPar.dramClient;
endmodule
