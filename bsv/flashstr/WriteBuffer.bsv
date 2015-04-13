import ControllerTypes::*;
import ValDRAMCtrlTypes::*;
import ValFlashCtrlTypes::*;
import FlashWriter::*;
import FlashReader::*;

import DRAMArbiterTypes::*;
import DRAMPartioner::*;
import SerDes::*;
import Align::*;
import MyArbiter::*;

import Shifter::*;

import FIFO::*;
import FIFOF::*;
import GetPut::*;
import Vector::*;
import Connectable::*;
import ClientServer::*;
import RegFile::*;
import ClientServerHelper::*;

interface FlashWriteBufWrIfc;
   interface Put#(ValSizeT) writeReq;
   interface Get#(FlashAddrType) writeAck;
   interface Put#(Bit#(512)) writeWord;
endinterface

interface FlashWriteBufRdIfc;
   interface Put#(FlashReadReqT) readReq;
   interface Get#(Tuple2#(Bit#(64), TagT)) readVal;
endinterface

interface FlashWriteBufIfc;
   interface FlashWriteBufWrIfc writeUser;
   interface FlashWriteBufRdIfc readUser;
   interface FlushClient flashFlClient;
   interface FlashReaderClient flashRdClient;
   interface DRAMClient dramClient;
endinterface

typedef struct{
   Bool rnw;
   FlashAddrType addr;
   ValSizeT numBytes;
   Bit#(1) bufId;
   TagT reqId;
   } WriteBufCmdT deriving (Bits, Eq);


(*synthesize*)
module mkFlashWriteBuffer(FlashWriteBufIfc);
   Vector#(2,FIFO#(DRAMReq)) dramCmdQs <- replicateM(mkFIFO);
   Vector#(2,FIFO#(Bit#(512))) dramDtaQs <- replicateM(mkFIFO);
   
   Reg#(SuperPageIndT) superPageCnt <- mkReg(0);      
   
   /* processing write commands */
   //FIFO#(ValSizeT) writeReqQ <- mkFIFO;
   FIFO#(WriteBufCmdT) reqQ <- mkSizedFIFO(valueOf(NumTags));
   FIFO#(WriteBufCmdT) dramReqQ <- mkFIFO;
   
   FIFO#(Bit#(512)) inDataQ <- mkFIFO;
   FIFO#(FlashAddrType) respQ <- mkFIFO;
   /* send dram cmd to write the dram write buf */
   
   Reg#(Bit#(1)) currBuf <- mkReg(0);
   Vector#(2, Reg#(Bool)) writeLocks <- replicateM(mkReg(False));
   Vector#(2, Reg#(Bool)) clean <- replicateM(mkReg(True));
   
   Vector#(2,Reg#(Bit#(TAdd#(TLog#(SuperPageSz),1)))) byteCnt_seg_V <- replicateM(mkReg(0));
   Vector#(2,Reg#(Bit#(TAdd#(TLog#(SuperPageSz),1)))) byteCnt_wr_V <- replicateM(mkReg(0));
   
   ByteDeAlignIfc#(Bit#(512), Bit#(1)) deAlign <- mkByteDeAlignPipeline;
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
            block = True;
         end
      end
      

      Bit#(TLog#(SuperPageSz)) byteCnt_seg = truncate(byteCnt_seg_V[bufIdx]);
      
      if ( !block ) begin
         deAlign.deAlign(truncate(byteCnt_seg), extend(numBytes), bufIdx);
         byteCnt_seg_V[bufIdx] <= byteCnt_seg_V[bufIdx] + extend(numBytes);
         dramReqQ.enq(req);
         reqQ.deq();
         //$display("WrAck addr = %d", {superPageId, byteCnt_seg});
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
      
      //$display("writeBuf dramWr dramSel = %d, addr = %d, data = %h, nBytes = %d", dramSel, addr, data, nBytes);
      byteCnt_wr_V[dramSel] <= byteCnt_wr_V[dramSel] + extend(nBytes);
      dramCmdQs[dramSel].enq(DRAMReq{rnw: False, addr: extend(addr), data: data, numBytes: nBytes});
      
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
   FIFO#(Tuple2#(Bit#(64), TagT)) flashRdRespQ <- mkFIFO;
   
   ByteAlignIfc#(Bit#(512), TagT) align <- mkByteAlignPipeline;
 
   rule doReadCmd if (reqQ.first.rnw);
      let req <- toGet(reqQ).get();
      let addr = req.addr;
      let numBytes = req.numBytes;
      let reqId = req.reqId;
      
      readCmdLUT.upd(reqId, numBytes);
      
      SuperPageIndT currSegId = truncateLSB(pack(addr));
      //$display("currSegId = %d, superPageCnt = %d, currBuf = %d", currSegId, superPageCnt, currBuf);
      if (currSegId == superPageCnt) begin
         // do dram Read
         $display("Serve Flash Read commmand from DRAM reqId = %d", reqId);
         req.bufId = currBuf;
         dramReqQ.enq(req);
         //reqQ.deq();
         Bit#(6) byteOffset = truncate(pack(addr));
         align.align(byteOffset, extend(numBytes), reqId);
      end
      else if (currSegId == superPageCnt - 1 && clean[~currBuf]) begin
         // do dram Read
         $display("Serve Flash Read commmand from DRAM reqId = %d", reqId);
         req.bufId = ~currBuf;
         dramReqQ.enq(req);
         //reqQ.deq();
         Bit#(6) byteOffset = truncate(pack(addr));
         align.align(byteOffset, extend(numBytes), reqId);
      end
      else begin
         //flash read
         flashRdReqQ.enq(FlashReadReqT{addr: addr, numBytes: numBytes, reqId: reqId});
      end
   endrule
   
   FIFO#(Bit#(1)) dramSelQ <- mkSizedFIFO(16);   
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
      
      //$display("writeBuf dramRd dramSel = %d, addr = %d, nBytes = %d", dramSel, rowidx << 6, nBytes);
      dramCmdQs[dramSel].enq(DRAMReq{rnw:True, addr: extend(rowidx << 6), data:?, numBytes:nBytes});
      dramSelQ.enq(dramSel);

      if (byteCnt_Rd + extend(nBytes) < numBytes) begin
         byteCnt_Rd <= byteCnt_Rd + extend(nBytes);
      end
      else begin
         byteCnt_Rd <= 0;
         dramReqQ.deq();
      end
   endrule
   
   FIFO#(Bit#(512)) dramDtaQ <- mkFIFO();
   mkConnection(toGet(dramDtaQ), align.inPipe);
   
   for (Integer i = 0; i < 2; i = i + 1) begin
      rule doDeqDramDta if ( dramSelQ.first == fromInteger(i));
         dramSelQ.deq();
         let dta <- toGet(dramDtaQs[i]).get();
         //$display("dramDtaQ got data = %h", dta);
         dramDtaQ.enq(dta);
      endrule
   end
   
      
   
   SerializerIfc#(512, 64, TagT) ser <- mkSerializer();
      
   rule doSer;
      let v <- align.outPipe.get();
      let data = tpl_1(v);
      let numBytes = tpl_2(v);
      let reqId = tpl_3(v);
   
      Bit#(4) numWords = truncate(numBytes >> 3);
      
      if ( numBytes[2:0] != 0)
         numWords = numWords + 1;
      
      ser.marshall(data, numWords, reqId);
   endrule    
   
   
   
   Vector#(2, FIFOF#(Tuple2#(Bit#(64), TagT))) respDtaQs <- replicateM(mkFIFOF);
   FIFO#(Tuple2#(Bit#(64), TagT)) respDtaQ <- mkFIFO;
   
   Vector#(2, FIFOF#(ValSizeT)) respSizeQs <- replicateM(mkFIFOF);

   Reg#(ValSizeT) byteCnt_dramResp <- mkReg(0);
   Reg#(ValSizeT) byteCntMax_dramResp <- mkReg(0);
   rule doDeqDramRes;
      let d <- ser.getVal;
      respDtaQs[0].enq(d);
      
      /*let reqId = tpl_2(d);
      
      if ( byteCnt_dramResp + 8 >= byteCntMax_dramResp) begin
         byteCnt_dramResp <= 0;
         byteCntMax_dramResp <= readCmdLUT.sub(reqId);
         respSizeQs[0].enq(readCmdLUT.sub(reqId));
      end
      else begin
         byteCnt_dramResp <= byteCnt_dramResp + 8;
      end*/
   endrule

   Reg#(ValSizeT) byteCnt_flashResp <- mkReg(0);
   Reg#(ValSizeT) byteCntMax_flashResp <- mkReg(0);
 
   rule doDeqFlashRes;
      let d <- toGet(flashRdRespQ).get();
      respDtaQs[1].enq(d);
      
      /*let reqId = tpl_2(d);
      
      if ( byteCnt_flashResp + 8 >= byteCntMax_flashResp) begin
         byteCnt_flashResp <= 0;
         byteCntMax_flashResp <= readCmdLUT.sub(reqId);
         respSizeQs[1].enq(readCmdLUT.sub(reqId));
      end
      else begin
         byteCnt_flashResp <= byteCnt_flashResp + 8;
      end*/
   endrule
   
   Arbiter_IFC#(2) arbiter <- mkArbiter(False);
   for (Integer i = 0; i < 2; i = i + 1) begin
      rule doReqs_0 if (respDtaQs[i].notEmpty);
         arbiter.clients[i].request;
      endrule
      
      rule doReqs_1 if (arbiter.grant_id == fromInteger(i));
         let v <- toGet(respDtaQs[i]).get();
         respDtaQ.enq(v);
      endrule
   end

   //FIFO#(Tuple2#(Bit#(1), ValSizeT)) respSizeQ <- mkFIFO;
   /*
   for (Integer i = 0; i < 2; i = i + 1) begin
      rule doReqs_0 if (respSizeQs[i].notEmpty);
         arbiter.clients[i].request;
      endrule
      
      rule doReqs_1 if (arbiter.grant_id == fromInteger(i));
         let v <- toGet(respSizeQs[i]).get();
         respSizeQ.enq(tuple2(fromInteger(i),v));
      endrule
   end
   
   Reg#(ValSizeT) byteCnt_Resp <- mkReg(0);
 
   rule doResp;
      let v = respSizeQ.first();
      let sel = tpl_1(v);
      let numBytes = tpl_2(v);
      if ( byteCnt_Resp + 8 >= numBytes) begin
         respSizeQ.deq();
         byteCnt_Resp <= 0;
      end
      else begin
         byteCnt_Resp <= byteCnt_Resp + 8;
      end

      let data <- toGet(respDtaQs[sel]).get();
      //$display("dequeing data from sel = %d, data = %h, tag = %d", sel, tpl_1(data), tpl_2(data));
      respDtaQ.enq(data);
   endrule
   */
   
   Vector#(2,DRAMClient) dramClients;
   for (Integer i = 0; i < 2; i = i + 1)
      dramClients[i] = toClient(dramCmdQs[i], dramDtaQs[i]);
      /*((interface DRAMClient;
                           interface Get request = toGet(dramCmdQs[i]);
                           interface Put response = toPut(dramDtaQs[i]);
                        endinterface);*/
   
   DRAMSegmentIfc#(2) dramPar <- mkDRAMSegments;
   
   mkConnection(dramPar.dramServers[0], dramClients[0]);
   mkConnection(dramPar.dramServers[1], dramClients[1]);
   
   Reg#(Bool) initFlag <- mkReg(False);
   rule init if (!initFlag);
      dramPar.initializers[0].put(fromInteger(valueOf(SuperPageSz)));
      dramPar.initializers[1].put(fromInteger(valueOf(SuperPageSz)));
      initFlag <= True;
   endrule

                  

   interface FlashWriteBufWrIfc writeUser;
      interface Put writeReq;
         method Action put(ValSizeT v);
            reqQ.enq(WriteBufCmdT{rnw: False, numBytes: v});
         endmethod
      endinterface
      interface Get writeAck = toGet(respQ);
      interface Put writeWord = toPut(inDataQ);
   endinterface
   
   interface FlashWriteBufRdIfc readUser;
      interface Put readReq;
         method Action put(FlashReadReqT v);
            reqQ.enq(WriteBufCmdT{rnw: True, addr: v. addr, numBytes: v.numBytes, reqId: v.reqId});
         endmethod
      endinterface
      interface Get readVal = toGet(respDtaQ);
   /*
         method ActionValue#(Tuple2#(Bit#(64), TagT)) get();
            let d <- ser.getVal;
            return d;
         endmethod
      endinterface*/
   endinterface

   interface FlushClient flashFlClient = toClient(flushReqQ, flushRespQ);
   interface FlashReaderClient flashRdClient = toClient(flashRdReqQ, flashRdRespQ);
   
   interface DRAMClient dramClient = dramPar.dramClient;
endmodule
