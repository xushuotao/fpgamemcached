//import ControllerTypes::*;
import ValDRAMCtrlTypes::*;
import ValFlashCtrlTypes::*;
import DRAMArbiterTypes::*;
import SerDes::*;
import Align::*;

import Shifter::*;

import FIFO::*;
import GetPut::*;
import Vector::*;
import Connectable::*;
import ClientServer::*;

interface FlashWriteBufWrIfc;
   interface Put#(ValSizeT) writeReq;
   interface Get#(FlashAddrType) writeAck;
   interface Put#(Bit#(512)) writeWord;
endinterface

interface FlashWriteBufRdIfc;
   interface Put#(FlashReadReqT) readReq;
   interface Get#(Bit#(64)) readVal;
endinterface

interface FlashWriteBufIfc;
   interface FlashWriteBufWrIfc writeUser;
   interface FlashWriteBufRdIfc readUser;
   interface Vector#(2,DRAMClient) dramClients;
endinterface

typedef struct{
   Bool rnw;
   FlashAddrType addr;
   ValSizeT numBytes;
   Bit#(1) bufId;
   } WriteBufCmdT deriving (Bits, Eq);

module mkFlashWriteBuffer(FlashWriteBufIfc);
   Vector#(2,FIFO#(DRAMReq)) dramCmdQs <- replicateM(mkFIFO);
   Vector#(2,FIFO#(Bit#(512))) dramDtaQs <- replicateM(mkFIFO);
   
   Reg#(SuperPageIndT) superPageCnt <- mkReg(0);      
   
   /* processing write commands */
   //FIFO#(ValSizeT) writeReqQ <- mkFIFO;
   FIFO#(WriteBufCmdT) reqQ <- mkFIFO;
   FIFO#(WriteBufCmdT) dramReqQ <- mkFIFO;
   
   FIFO#(Bit#(512)) inDataQ <- mkFIFO;
   FIFO#(FlashAddrType) respQ <- mkFIFO;
   /* send dram cmd to write the dram write buf */
   
   Reg#(Bit#(1)) bufSel <- mkReg(0);
   Vector#(2, Reg#(Bool)) readLocks <- replicateM(mkReg(False));
   Vector#(2,Reg#(Bit#(TAdd#(TLog#(SuperPageSz),1)))) byteCnt_seg_V <- replicateM(mkReg(0));
   Vector#(2,Reg#(Bit#(TAdd#(TLog#(SuperPageSz),1)))) byteCnt_wr_V <- replicateM(mkReg(0));
   
   ByteDeAlignIfc#(Bit#(512), Bit#(1)) deAlign <- mkByteDeAlignPipeline;
   mkConnection(deAlign.inPipe, toGet(inDataQ));
   
   FIFO#(FlushReqT) flushQ <- mkFIFO();
   rule doWriteBuf if ( !reqQ.first.rnw );
      let req = reqQ.first;
      let numBytes = req.numBytes;
      //**** select which buffer to write *****
      let bufIdx = bufSel;
      Bool block = False;
      //**** if current writeBuf is full
      if ( byteCnt_seg_V[bufSel] + extend(numBytes) > fromInteger(superPageSz) ) begin
         //*** lock the current buffer for flushing
         if (!readLocks[bufSel]) begin
            readLocks[bufSel] <= True;
            superPageCnt <= superPageCnt + 1;
            //flushQ.enq(FlushReqT{segId: superPageCnt, bufId: bufSel});
         end
         //*** if next writeBuf is free
         if ( !readLocks[bufSel+1]) begin
            bufIdx = bufIdx + 1;
            bufSel <= bufSel + 1;
         end
         //*** if next writeBuf is being dumped
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
         $display("WrAck addr = %d", {superPageCnt, byteCnt_seg});
         respQ.enq(unpack({superPageCnt, byteCnt_seg}));
      end
   endrule
   
   
   Reg#(ValSizeT) byteCnt_Wr <- mkReg(0);
   rule driveDRAMWriteCmd if (!dramReqQ.first.rnw);
      let args = dramReqQ.first();
      
      let v <- deAlign.outPipe.get();
      let data = tpl_1(v);
      let nBytes = tpl_2(v);
      let dramSel = tpl_3(v);
      
      let addr = byteCnt_wr_V[dramSel];
      
      $display("writeBuf dramWr dramSel = %d, addr = %d, data = %h, nBytes = %d", dramSel, addr, data, nBytes);
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
   
   ByteAlignIfc#(Bit#(512),Bit#(0)) align <- mkByteAlignPipeline;
 
   rule doReadCmd if (reqQ.first.rnw);
      let req <- toGet(reqQ).get();
      let addr = req.addr;
      let numBytes = req.numBytes;
      
      req.bufId = bufSel;
      
      SuperPageIndT currSegId = truncateLSB(pack(addr));
      
      if (currSegId == superPageCnt) begin
         // do dram Read
         dramReqQ.enq(req);
         //reqQ.deq();
         Bit#(6) byteOffset = truncate(pack(addr));
         align.align(byteOffset, extend(numBytes),?);
      end
      else begin
         // do flash read
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
      
      $display("writeBuf dramRd dramSel = %d, addr = %d, nBytes = %d", dramSel, rowidx << 6, nBytes);
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
         $display("dramDtaQ got data = %h", dta);
         dramDtaQ.enq(dta);
      endrule
   end
   
      
   
   SerializerIfc#(512, 64) ser <- mkSerializer();
      
   rule doSer;
      let v <- align.outPipe.get();
      let data = tpl_1(v);
      let numBytes = tpl_2(v);
   
      Bit#(4) numWords = truncate(numBytes >> 3);
      
      if ( numBytes[2:0] != 0)
         numWords = numWords + 1;
      
      ser.marshall(data, numWords);
   endrule    
       
   
   Vector#(2,DRAMClient) ds;
   for (Integer i = 0; i < 2; i = i + 1)
      ds[i] = (interface DRAMClient;
                  interface Get request = toGet(dramCmdQs[i]);
                  interface Put response = toPut(dramDtaQs[i]);
               endinterface);
                  

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
            reqQ.enq(WriteBufCmdT{rnw: True, addr: v. addr, numBytes: v.numBytes});
         endmethod
      endinterface
      interface Get readVal;
         method ActionValue#(Bit#(64)) get();
            let d <- ser.getVal;
            return d;
         endmethod
      endinterface
   endinterface


   
   interface dramClients = ds;

endmodule
