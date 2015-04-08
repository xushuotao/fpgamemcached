import ControllerTypes::*;
import ValFlashCtrlTypes::*;
import DRAMArbiterTypes::*;
import SerDes::*;
import Align::*;

import Shifter::*;

import FIFO::*;
import GetPut::*;


interface EvictionBufAccessIFC;
   interface Put#(FlashWriteCmdT) writeReq;
   interface Get#(FlashAddrType) writeAck;
   interface Put#(Bit#(512)) writeWord;
   interface Vector#(2,DRAMClient) dramClients;
endinterface

interface EvictionBufFlushIFC;
   interface Put#(Bit#(1)) flushReq;
   interface Get#(Bit#(1)) writeAck;
   interface Vector#(2,DRAMClient) dramClients;
endinterface


interface ValFlashReadIFC;
   interface Put#(FlashAddrType) readReq;
   interface Get#(Bit#(64)) readVal;
endinterface

/*
   DRAMSegmentIfc#(2) dramSegs <- mkDRAMSegments;
   Reg#(Bool) initflag <- mkReg(False);
   rule initSeg (!initflag);
      initflag <= True;
      dramSegs.initializers[0].put(fromInteger(segmentSize));
      dramSegs.initializers[1].put(fromInteger(segmentSize));
   endrule
*/


module mkValBufWrite(EvictionBufAccessIFC);
   Vector#(2,FIFO#(DRAMReq)) dramCmdQs <- mkFIFO;
   //Vector#(2,FIFO#(Bit#(512))) dramDtaQ <- mkFIFO;
   FIFO#(BufWriteCmdT) writeReqQ <- mkFIFO;
   FIFO#(Bit#(512)) inDataQ <- mkFIFO;
   FIFO#(FlashAddrType) respQ <- mkFIFO;
   
   //ByteAlignIfc#(Bit#(512), Bit#(0)) align <- mkByteAlignPipeline();
   
   
   
   // shift dram data line to 512bit alignment
   /*
   FIFO#(ShiftCmdT) sftCmdQ <- mkFIFO()
   Reg#(Bit#(512)) shiftCache <- mkRegU();
   Reg#(Bit#(32)) burstCnt_sft <- mkReg(0);
   ByteSftIfc#(Bit#(1024)) preSft <- mkPipelineRightShifter;
   rule doShift;
      let cmd = sftCmdQ.first();
      let d <- toGet(inDataQ).get();
      shiftCache <= d;
      
      if (burstCnt_sft + 1 >= cmd.numBursts) begin
         if ( burstCnt_sft > 0 )
            preSft.rotateBytes({d, shiftCache}, cmd.offset);
         else
            preSft.rotateBytes(extend(d), cmd.offset);
         burstCnt_sft <= 0;
         sftCmdQ.deq();
      end
      else if (burstCnt_sft == 0) begin
         if (cmd.offset == 0) begin
            preSft.rotateBytes(extend(d), cmd.offset);
         end
         burstCnt_sft <= burstCnt_sft + 1;
      end
      else begin
         preSft.rotateBytes({d, shiftCache}, cmd.offset);
         burstCnt_sft <= burstCnt_sft + 1;
      end
   endrule
   */
   
   
   /* send dram cmd to write the dram write buf */
   Reg#(Bit#(16)) segmentCnt <- mkReg(0);      
   ByteSftIfc#(Bit#(1024)) sfter <- mkPipelineRightShifter;
   FIFO#(DRAMReq) dramCmdQ_Imm <- mkSizedFIFO(valueOf(ElementShiftSz#(1024)));
   FIFO#(Bit#(1)) dramSelQ <- mkSizedFIFO(valueOf(ElementShiftSz#(1024)));
   
   Reg#(Bit#(32)) byteCnt_cmd <- mkReg(0);
   Reg#(Bit#(32)) burstCnt_cmd <- mkReg(0);
   Reg#(Bit#(512)) readCache <- mkRegU();
   
   Reg#(Bit#(1)) bufSel <- mkReg(0);
   Vector#(2, Reg#(Bool)) readLocks <- replicateM(mkReg(False));
   Vector#(2,Reg#(Bit#(32))) byteCnt_seg_V <- mkReg(0);
   Vector#(2,Reg#(Bit#(32))) byteCnt_wr_V <- mkReg(0);
   
   ByteDeAlignIfc#(Bit#(512), Bit#(1)) deAlign <- mkByteDeAlignPipeline;
   
   //FIFO#(Bit#(1)) flushQ <- mkFIFO();
   rule doWriteBuf;
      let req = writeReqQ.first();
      //**** select which buffer to write *****
      let bufIdx = bufSel;
      Bool block = False;
      //**** if current writeBuf is full
      if ( byteCnt_set[bufSel] + req.numBytes >= fromInteger(segmentSz) ) begin
         //*** lock the current buffer for dumping
         if (!readLock[bufSel]) begin
            readLock[bufSel] <= True;
            flushQ.enq(bufSel);
         end
         //*** if next writeBuf is free
         if ( !readLock[bufSel+1]) begin
            bufIdx = bufIdx + 1;
            bufSel <= bufSel + 1;
         end
         //*** if next writeBuf is being dumped
         else begin
            block = True;
         end
      end
      
      let byteCnt_seg = byteCnt_seg_V[bufIdx];
      
      if ( !block ) begin
         deAlign.deAlign(byteCnt_seg, req.numBytes, bufIdx);
         byteCnt_seg_V[bufIdx] <= byteCnt_seg_V[bufIdx] + req.numBytes;
      end
   endrule
   
   
   rule driveWriteCmd;
      let v <- deAlign.outPipe.get();
      let data = tpl_1(v);
      let nBytes = tpl_2(v);
      let dramSel = tpl_3(v);
      
      let addr = byteCnt_wr_V[dramSel];
      byteCnt_wr_V[dramSel] <= byteCnt_wr_V[dramSel] + extend(nBytes);
            
      dramCmdQs[dramSel].enq(DRAMReq{rnw: False, addr: extend(addr), data: data, nBytes: nBytes});
   endrule
   
   Vector#(2,DRAMClient) ds;
   for (Integer i = 0; i < 2; i = i + 1)
      ds = (interface DRAMClient;
            interface Get request = toGet(dramCmdQs[i]);
               interface Put response;
                  method Action put(Bit#(512) v);
                     $display("Error: no dram reads allowed");
                  endmethod
               endinterface
            endinterface);
                  


   interface Put writeReq;
      method Action put(FlashWriteCmdT v);
         Bit#(32) totalBytes = v.nBytes + extend(v.wordOffset);
         Bit#(32) numBursts = totalBytes >> 6;
         if ( totalBytes[5:0] != 0 )
            numBursts = numBursts + 1;
         
         sftCmdQ.enq(ShiftCmdT{numBursts:numBursts, v.wordoffset});
         writeReqQ.enq(FlashWriteCmdT{numBytes:v.nBytes, numBursts: numBursts});
      endmethod
   endinterface
   interface Get writeAck = toGet(respQ);
   interface Put writeWord = toPut(inDataQ);
   interface dramClients = ds;

endmodule
