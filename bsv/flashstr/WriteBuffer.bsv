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
import ByteSerDes::*;
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

typedef 2 NUMBUFS;

interface FlashWriteBufIfc;
   interface FlashWriteServer writeUser;
   interface FlashReadServer readUser;
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

//(*synthesize*)
module mkFlashWriteBuffer(FlashWriteBufIfc);
   // Vector#(2,FIFO#(DRAM_LOCK_Req)) dramCmdQs <- replicateM(mkFIFO);
   FIFO#(Tuple2#(DRAM_LOCK_Req, Bit#(1))) dramCmdQ <- mkFIFO;
   FIFO#(DRAM_LOCK_Req) dramCmdQ_raw <- mkFIFO;
   
   // Vector#(2,FIFO#(Bit#(512))) dramDtaQs <- replicateM(mkFIFO);
   FIFO#(Bit#(512)) dramDtaQ <- mkFIFO;
   
   Reg#(SuperPageIndT) superPageCnt <- mkReg(0);      
   
   /* processing write commands */
   //FIFO#(ValSizeT) writeReqQ <- mkFIFO;
   FIFO#(WriteBufCmdT) reqQ <- mkSizedFIFO(valueOf(NumTags));
   FIFOF#(WriteBufCmdT) dramReqQ <- mkFIFOF;

   Vector#(2, FIFOF#(Tuple2#(ValSizeT, TagT))) burstSzQs <- replicateM(mkSizedFIFOF(32));
   FIFO#(ValSizeT) burstSzQ <- mkFIFO();
   
   FIFO#(Bit#(128)) inDataQ <- mkFIFO;
   FIFO#(FlashAddrType) respQ <- mkBypassFIFO;
   /* send dram cmd to write the dram write buf */
   
   Reg#(Bit#(1)) currBuf <- mkReg(0);
   Vector#(2, Reg#(Bool)) writeLocks <- replicateM(mkReg(False));
   Vector#(2, Reg#(Bool)) clean <- replicateM(mkReg(True));
   
   Reg#(Bit#(TAdd#(TLog#(SuperPageSz),1))) byteCnt_seg_V0 <- mkReg(fromInteger(valueOf(SuperPageSz)));
   Reg#(Bit#(TAdd#(TLog#(SuperPageSz),1))) byteCnt_seg_V1 <- mkReg(0);
   
   //Vector#(2,Reg#(Bit#(TAdd#(TLog#(SuperPageSz),1)))) byteCnt_seg_V <- replicateM(mkReg(0));
   `ifdef BSIM
   Vector#(2,Reg#(Bit#(TAdd#(TLog#(SuperPageSz),1)))) byteCnt_seg_V;// = newVector();// <- replicateM(mkReg(0));
   byteCnt_seg_V[0] = byteCnt_seg_V0;
   byteCnt_seg_V[1] = byteCnt_seg_V1;
   `else
   Vector#(2,Reg#(Bit#(TAdd#(TLog#(SuperPageSz),1)))) byteCnt_seg_V <- replicateM(mkReg(0));
   `endif
   
   Vector#(2,Reg#(Bit#(TAdd#(TLog#(SuperPageSz),1)))) byteCnt_wr_V <- replicateM(mkReg(0));
   
   //ByteDeAlignIfc#(Bit#(512), Bit#(1)) deAlign <- mkByteDeAlignPipeline;
   //ByteDeAlignIfc#(Bit#(512), Bit#(1)) deAlign <- mkByteDeAlignCombinational;
   ByteDeAlignIfc#(Bit#(128), void) deAlign <- mkByteDeAlignCombinational_regular();
   FIFO#(Tuple3#(ValSizeT, Bit#(6), Bit#(1))) desCmdQ <- mkFIFO();
   
   mkConnection(deAlign.inPipe, toGet(inDataQ));

   FIFO#(FlushReqT) flushReqQ <- mkFIFO();
   FIFO#(Bit#(1)) flushRespQ <- mkFIFO();
   
   Reg#(Bit#(32)) writeReqCnt <- mkReg(0);
   Reg#(Bit#(32)) totalEnq <- mkReg(0);
   Reg#(Bit#(32)) totalDeq <- mkReg(0);
   
   ByteDes des <- mkByteDes;
   
   FIFO#(Tuple2#(Bit#(TAdd#(TLog#(SuperPageSz),1)), Bit#(1))) writeAddrQ <- mkFIFO();
   
   rule doWriteBuf if ( !reqQ.first.rnw );
      let req = reqQ.first;
      let numBytes = req.numBytes;
      //**** select which buffer to write *****
      let bufIdx = currBuf;
      Bool block = False;
      SuperPageIndT superPageId = superPageCnt;

      let numPages = numBytes >> 13;
      if ( numBytes[12:0] != 0) 
         numPages = numPages + 1;
      
      //**** if current writeBuf is full
      // if ( byteCnt_seg_V[currBuf] + extend(numBytes) > fromInteger(superPageSz) ) begin
      if ( byteCnt_seg_V[currBuf] + extend(numPages << 13) > fromInteger(superPageSz) ) begin
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
         deAlign.deAlign(truncate(byteCnt_seg), extend(numBytes), ?);
         desCmdQ.enq(tuple3(numBytes, truncate(byteCnt_seg), bufIdx));
         byteCnt_seg_V[bufIdx] <= byteCnt_seg_V[bufIdx] + extend(numPages<<13);
         // byteCnt_seg_V[bufIdx] <= byteCnt_seg_V[bufIdx] + extend(numBytes);
         dramReqQ.enq(req);
         writeAddrQ.enq(tuple2(byteCnt_seg_V[bufIdx], bufIdx));
         reqQ.deq();
         $display("Flashstore serve write at addr = %d, numBytes = %d, writeReqCnt = %d, totalDeq = %d", {superPageId, byteCnt_seg}, numBytes, writeReqCnt, totalDeq);
         writeReqCnt <= writeReqCnt + 1;
         totalDeq <= totalDeq + 1;
         respQ.enq(unpack({superPageId, byteCnt_seg}));
      end
   endrule
   
   rule doUnlockBuf;
      let bufId <- toGet(flushRespQ).get();
      writeLocks[bufId] <= False;
      byteCnt_seg_V[bufId] <= 0;
      byteCnt_wr_V[bufId] <= 0;
   endrule

   
   Reg#(ValSizeT) byteCnt_des <- mkReg(0);
   //FIFO#(Bit#(1)) segIdQ <- mkSizedFIFO(4);
   rule doDesCmd;
      let cmd = desCmdQ.first();
      Bit#(6) offset = 0;
      Bit#(7) byteIncr = 64;
      let numBytes = tpl_1(cmd);
      let byteOffset = tpl_2(cmd);
      let segId = tpl_3(cmd);
      
      if (byteCnt_des == 0) begin
         offset = byteOffset;
         byteIncr = 64 - extend(byteOffset);
      end
      
      if ( byteCnt_des + extend(byteIncr) >= numBytes) begin
         desCmdQ.deq();
         byteCnt_des <= 0;
         byteIncr = truncate(numBytes - byteCnt_des);
      end
      else begin
         byteCnt_des <= byteCnt_des + extend(byteIncr);
      end
      
      des.request.put(tuple2(offset,byteIncr));
      //segIdQ.enq(segId);
   endrule
   
   Reg#(Bit#(32)) cycles <- mkReg(0);
   rule doCycles;
      cycles <= cycles + 1;
   endrule

   Reg#(Bit#(32)) cycles_pre <- mkRegU();
   rule doConn;
      let v <- deAlign.outPipe.get();
      des.inPipe.put(tpl_1(v));
      cycles_pre <= cycles;
      $display("%m getting data cycles = %d, gap = %d, step = %d", cycles, cycles!=cycles_pre+1, cycles-cycles_pre);
   endrule
   
      
   Reg#(ValSizeT) byteCnt_Wr <- mkReg(0);
   rule driveDRAMWriteCmd if (!dramReqQ.first.rnw);
      let args = dramReqQ.first();
      
      let addr = tpl_1(writeAddrQ.first);
      let dramSel = tpl_2(writeAddrQ.first);
      
      let v <- des.outPipe.get();
      let data = tpl_1(v);
      let nBytes = tpl_2(v);
      
      //let addr = byteCnt_wr_V[dramSel];
      
      $display("writeBuf dramWr[dramSel = %d], addr = %d, data = %h, nBytes = %d, byteCnt_wr = %d, byteMax = %d", dramSel, addr, data, nBytes, byteCnt_Wr, args.numBytes);
      //byteCnt_wr_V[dramSel] <= byteCnt_wr_V[dramSel] + extend(nBytes);
      dramCmdQ.enq(tuple2(DRAM_LOCK_Req{ackReq: False, rnw: False, addr: extend(addr)+extend(byteCnt_Wr), data: data, numBytes: nBytes},dramSel));
      
      if ( byteCnt_Wr + extend(nBytes) == args.numBytes ) begin
         byteCnt_Wr <= 0;
         dramReqQ.deq();
         writeAddrQ.deq();
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
      //FlashAddrType addr = unpack(pack(req.addr) + fromInteger(flashHeaderSz));
      FlashAddrType addr = unpack(pack(req.addr));// Test Purposes
      req.addr = addr;
      let numBytes = req.numBytes;
      let reqId = req.reqId;
      
      readCmdLUT.upd(reqId, numBytes);
      
      SuperPageIndT currSegId = truncateLSB(pack(addr));
      $display("Flashstore serve read: addr = %d, currSegId = %d, superPageCnt = %d, currBuf = %d, totalDeq = %d", addr, currSegId, superPageCnt, currBuf, totalDeq);
      totalDeq <= totalDeq + 1;
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
      
      Bool doLock = True;
      
      if (byteCnt_Rd + extend(nBytes) < numBytes) begin
         byteCnt_Rd <= byteCnt_Rd + extend(nBytes);
      end
      else begin
         doLock = False;
         byteCnt_Rd <= 0;
         dramReqQ.deq();
      end
      
      $display("writeBuf dramRd, reqId = %d, dramSel = %d, addr = %d, byteCnt_Rd = %d, nBytes = %d, maxBytes = %d", v.reqId, dramSel, rowidx << 6, byteCnt_Rd, nBytes, numBytes);
      //dramCmdQ.enq(tuple2(DRAM_LOCK_Req{lock: doLock, rnw:True, addr: extend(rowidx << 6), data:?, numBytes:nBytes},dramSel));
      dramCmdQ.enq(tuple2(DRAM_LOCK_Req{ackReq: False, lock: False, rnw:True, addr: extend(rowidx << 6), data:?, numBytes:nBytes},dramSel));
      dramSelQ.enq(tuple4(dramSel, numBytes, v.reqId, nBytes));
   endrule
   

   rule doOffset;
      let v <- toGet(dramCmdQ).get();
      let cmd = tpl_1(v);
      let sel = tpl_2(v);
      if ( sel == 1) begin
         cmd.addr = cmd.addr + fromInteger(valueOf(SuperPageSz));
      end
      dramCmdQ_raw.enq(cmd);
   endrule
      
   Reg#(ValSizeT) byteCnt_bucket <- mkReg(0);
   Reg#(Bit#(32)) wordCnt <- mkReg(0);
   rule doDeqDramDta;
      let d = dramSelQ.first();
      dramSelQ.deq();
      let dta <- toGet(dramDtaQ).get();
      let numBytes = tpl_2(d);
      let reqId = tpl_3(d);
      let byteIncr = tpl_4(d);
         
      Bit#(6) byteOffset = truncate(64-byteIncr); 

      $display("Dram Response dramDtaQ reqId = %d, byteCnt = %d, byteIncr = %d, maxBytes = %d, wordCnt = %d, got data = %h", tpl_3(d), byteCnt_bucket, tpl_4(d), tpl_2(d), wordCnt, dta);

      if (byteCnt_bucket == 0) begin
         align.align(byteOffset, extend(numBytes), reqId);
         burstSzQs[0].enq(tuple2(extend(numBytes), reqId));
      end
         
      if ( byteCnt_bucket + extend(tpl_4(d)) >= tpl_2(d)) begin
         byteCnt_bucket <= 0;
         wordCnt <= 0;
      end
      else begin
         byteCnt_bucket <= byteCnt_bucket + extend(tpl_4(d));
         wordCnt <= wordCnt + 1;
      end
         
      align.inPipe.put(dta);
   endrule
   
   
   SerializerIfc#(512, WordSz, TagT) ser <- mkSerializer();
   
   Reg#(Bit#(32)) byteCnt_shit <- mkReg(0);
      
   rule doSer;
      let v <- align.outPipe.get();
      let data = tpl_1(v);
      let numBytes = tpl_2(v);
      let reqId = tpl_3(v);
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
      let d <- toGet(respDtaQs[sel]).get();
      rdRespQ.enq(d);
   endrule

   interface FlashWriteServer writeUser;
      interface Server writeServer;
         interface Put request;
            method Action put(ValSizeT v);
               $display("Flashstore enq write req, totalEnq = %d", totalEnq);
               totalEnq <= totalEnq + 1;
               reqQ.enq(WriteBufCmdT{rnw: False, numBytes: v});
            endmethod
         endinterface
         interface Get response = toGet(respQ);
      endinterface
      interface Put writeWord = toPut(inDataQ);
   endinterface
   
   interface FlashReadServer readUser;
      interface Server readServer;
         interface Put request;
            method Action put(FlashReadReqT v);
               $display("Flashstore enq read req, totalEnq = %d", totalEnq);
               totalEnq <= totalEnq + 1;
               reqQ.enq(WriteBufCmdT{rnw: True, addr: v. addr, numBytes: v.numBytes, reqId: v.reqId});
            endmethod
         endinterface
         interface Get response = toGet(rdRespQ);
      endinterface
      interface Get burstSz = toGet(nextRespIdQ);
   endinterface
   
   interface FlushClient flashFlClient = toClient(flushReqQ, flushRespQ);
   interface FlashReadClient flashRdClient;
      interface Server readClient = toClient(flashRdReqQ, flashRdRespQ);
      interface Put burstSz = toPut(burstSzQs[1]);
   endinterface
   
   interface DRAMClient dramClient = toClient(dramCmdQ_raw, dramDtaQ);
   

endmodule
