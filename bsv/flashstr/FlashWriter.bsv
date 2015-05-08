import ControllerTypes::*;
import ValFlashCtrlTypes::*;
import FlashServer::*;
import DRAMCommon::*;

import Shifter::*;
import SerDes::*;
import TagAlloc::*;

import FIFO::*;
import Vector::*;
import GetPut::*;
import Connectable::*;
import ClientServer::*;
import ClientServerHelper::*;
import BRAM::*;
import RegFile::*;

/*interface EvictionBufFlushRawIFC;
   interface Put#(FlushReqT) flushReq;
   interface Get#(Bit#(1)) flushAck;
endinterface*/
typedef Server#(FlushReqT, Bit#(1)) FlushServer;
typedef Client#(FlushReqT, Bit#(1)) FlushClient;

interface EvictionBufFlushIFC;
   interface FlushServer flushServer;
   interface Vector#(2,DRAM_LOCK_Client) dramClients;
   interface TagClient tagClient;
   interface FlashRawWriteClient flashRawWrClient;
endinterface

(*synthesize*)
module mkEvictionBufFlush(EvictionBufFlushIFC);
   /*** raw flash client fifos ****/
   FIFO#(FlashCmd) flashReqQ <- mkFIFO;
   FIFO#(TagT) writeTagRespQ <- mkFIFO;
   FIFO#(Tuple2#(Bit#(128), TagT)) writeWordQ <- mkFIFO;
   FIFO#(Tuple2#(TagT, StatusT)) doneAckQ <- mkFIFO();
   
   /***** write buf flushes to dram *****/
   Vector#(2,FIFO#(DRAM_LOCK_Req)) dramCmdQs <- replicateM(mkFIFO);
   Vector#(2,FIFO#(Bit#(512))) dramDtaQs <- replicateM(mkFIFO);

      
   BRAM_Configure cfg = defaultValue;
   BRAM2Port#(TagT, Bit#(TLog#(SuperPageSz))) tag2addrTable <- mkBRAM2Server(cfg);
   //RegFile#(TagT, Bit#(TLog#(SuperPageSz))) tag2addrTable <- mkRegFileFull;

   
   FIFO#(Bit#(32)) tagReqQ <- mkFIFO();
   FIFO#(TagT) freeTagQ <- mkFIFO();
   FIFO#(TagT) returnTagQ <- mkFIFO();
   
   
   FIFO#(FlushReqT) reqQ <- mkFIFO();
   FIFO#(Bit#(1)) respQ <- mkFIFO();
   
   FIFO#(FlushReqT) flashCmdQ <- mkFIFO();
   FIFO#(Bit#(1)) bufIdQ_dramReq <- mkFIFO();
   FIFO#(Bit#(1)) bufIdQ_dramResp <- mkFIFO();
   FIFO#(Bit#(1)) preRespQ <- mkFIFO();
   rule doReq;
      let req <- toGet(reqQ).get;
      flashCmdQ.enq(req);
      bufIdQ_dramReq.enq(req.bufId);
      bufIdQ_dramResp.enq(req.bufId);
      preRespQ.enq(req.bufId);
      tagReqQ.enq(fromInteger(valueOf(NumPagesPerSuperPage)));
   endrule
      
   
   //***** do flash comands
   //Reg#(Bit#(TLog#(NumPagesPerSuperPage))) pageCnt <- mkReg(0);
   Reg#(Bit#(TLog#(SuperPageSz))) byteCnt_flash <- mkReg(0);
   rule doFlashCmds;
      //***** tag allocation
      let newTag <- toGet(freeTagQ).get;
      
      let req = flashCmdQ.first();
      
      FlashAddrType addr = unpack({req.segId, byteCnt_flash});
      /*
      if (pageCnt + 1 == 0 ) begin
         flashCmdQ.deq();
      end
      
      pageCnt <= pageCnt + 1;
      */
      if ( byteCnt_flash + fromInteger(pageSz) == 0 )
         flashCmdQ.deq();
      //   byteCnt_flash <= 0;
//      else
  
      byteCnt_flash <= byteCnt_flash + fromInteger(pageSz);
      
      tag2addrTable.portA.request.put(BRAMRequest{write: True,
                                                  responseOnWrite: False,
                                                  address: newTag,
                                                  datain: byteCnt_flash
                                                  });
      //tag2addrTable.upd(newTag, byteCnt_flash);
            
      //$display("FlushWriter send cmd: tag = %d, bus = %d, chip = %d, block = %d, page = %d", newTag, addr.channel, addr.way, addr.block, addr.page);
      //flash.sendCmd(FlashCmd{tag: newTag, op: WRITE_PAGE, bus: addr.channel, chip: addr.way, block: extend(addr.block), page: extend(addr.page)});
      flashReqQ.enq(FlashCmd{tag: newTag, op: WRITE_PAGE, bus: addr.channel, chip: addr.way, block: extend(addr.block), page: extend(addr.page)});
            
   endrule
   
   
   //FIFO#(TagT) tagQ_cmd <- mkSizedFIFO(valueOf(NumTags));
   FIFO#(TagT) tagQ_dta <- mkSizedFIFO(valueOf(NumTags));
   FIFO#(Bit#(TLog#(SuperPageSz))) dramAddrQ <- mkSizedFIFO(valueOf(NumTags));
   mkConnection(toPut(dramAddrQ), tag2addrTable.portB.response);
   
   rule writeTags;
      //let tag <- flash.writeDataReq();
      let tag <- toGet(writeTagRespQ).get();
      tag2addrTable.portB.request.put(BRAMRequest{write: False,
                                                  responseOnWrite: False,
                                                  address: tag,
                                                  datain: ?
                                                  });
      //dramAddrQ.enq(tag2addrTable.sub(tag));
      //tagQ_cmd.enq(tag);
      tagQ_dta.enq(tag);
      $display("writeTag Ack: tag = %d", tag);
   endrule

   Reg#(Bit#(TLog#(SuperPageSz))) byteCnt_dram <- mkReg(0);
   //Reg#(Bit#(TLog#(PageSz))) byteCnt_page <- mkReg(0);
   
   rule doFlashWriteReq;
      let bufId = bufIdQ_dramReq.first();
      let addr = dramAddrQ.first();
      if (addr[5:0] != 0) $display("addr is incorrect");

      Bit#(TLog#(PageSz)) byteCnt_page = truncate(byteCnt_dram);
      $display("%m:: flush write buffer dramCmd[bufId = %d], addr = %d", bufId, addr+extend(byteCnt_page));

      //Bool lock = True;
      if ( byteCnt_dram + 64 == 0 ) begin
         bufIdQ_dramReq.deq();
//         byteCnt_dram <= 0;
         $display("last dram command sent");
         //lock = False;
      end
  //    else begin
      byteCnt_dram <= byteCnt_dram + 64;
    //  end
      
      
      if (byteCnt_page + 64 == 0 ) begin
         dramAddrQ.deq();
//         byteCnt_page <= 0;
      end
  //    else begin
   //      byteCnt_page <= byteCnt_page + 64;
   //   end
      //dramCmdQs[bufId].enq(DRAM_LOCK_Req{rnw: True, addr: extend(addr + extend(byteCnt_page)), data: ?, numBytes: 64, lock: lock, ignoreLock: False});
      dramCmdQs[bufId].enq(DRAM_LOCK_Req{rnw: True, addr: extend(addr + extend(byteCnt_page)), data: ?, numBytes: 64, lock: False, ignoreLock:True, initlock: False});      
   endrule
   
   SerializerIfc#(512, 128, Bit#(0)) des <- mkSerializer();
   Reg#(Bit#(TLog#(SuperPageSz))) byteCnt_resp <- mkReg(0);
   rule doReadResp;
      let bufId = bufIdQ_dramResp.first();
      let d <- toGet(dramDtaQs[bufId]).get();
      des.marshall(d, 4, ?);
      byteCnt_resp <= byteCnt_resp + 64;
      if (byteCnt_resp + 64 == 0)
         bufIdQ_dramResp.deq();
   endrule
   
   Reg#(Bit#(TLog#(PageSizeUser))) byteCnt_RdResp <- mkReg(0);
   rule doWriteDta;
      let tag = tagQ_dta.first();
      
      
      if (byteCnt_RdResp + 16 >= fromInteger(pageSizeUser) ) begin
         tagQ_dta.deq();
         byteCnt_RdResp <= 0;
      end
      else begin
         byteCnt_RdResp <= byteCnt_RdResp + 16;
      end
      
      if (byteCnt_RdResp < fromInteger(pageSz) ) begin
         let d <- des.getVal;
         //flash.writeWord(tuple2(tpl_1(d), tag));
         writeWordQ.enq(tuple2(tpl_1(d), tag));
      end
      else begin
         //flash.writeWord(tuple2(0, tag));
         writeWordQ.enq(tuple2(0, tag));
      end



   endrule
   
   Reg#(Bit#(NumPagesPerSuperPage)) ackCnt <- mkReg(0);
   rule doWriteAck;
      //let ack <- flash.ackStatus();
      let ack <- toGet(doneAckQ).get();
      let tag = tpl_1(ack);
      let status = tpl_2(ack);
      returnTagQ.enq(tag);
      
      
      if (ackCnt + 1 >= fromInteger(valueOf(NumPagesPerSuperPage)) ) begin
         let bufId <- toGet(preRespQ).get();
         respQ.enq(bufId);
         $display("WriteBuf flushed to Flash");
         ackCnt <= 0;
      end
      else begin
         ackCnt <= ackCnt + 1;
      end
         
      $display("WriteDoneAck received, ackCnt = %d, tag = %d", ackCnt, tag);
   endrule
   
   Vector#(2,DRAM_LOCK_Client) ds;
   for (Integer i = 0; i < 2; i = i + 1)
      ds[i] = (interface DRAM_LOCK_Client;
                  interface Get request = toGet(dramCmdQs[i]);
                  interface Put response = toPut(dramDtaQs[i]);
               endinterface);
   

   interface FlushServer flushServer;
      interface Put request = toPut(reqQ);
      interface Get response = toGet(respQ);
   endinterface
   
   interface dramClients = ds;
   
   interface TagClient tagClient;
      interface Client reqTag;
         interface Get request = toGet(tagReqQ);
         interface Put response = toPut(freeTagQ);
      endinterface
      interface Get retTag = toGet(returnTagQ);
   endinterface

   interface FlashRawWriteClient flashRawWrClient;
      interface Client client = toClient(flashReqQ, writeTagRespQ);
      interface Get wordPipe = toGet(writeWordQ);
      interface Put doneAck = toPut(doneAckQ);
   endinterface
endmodule
