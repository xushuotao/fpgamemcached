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

typedef Server#(FlushReqT, Bit#(1)) FlushServer;
typedef Client#(FlushReqT, Bit#(1)) FlushClient;

interface EvictionBufFlushIFC;
   interface FlushServer flushServer;
   interface DRAM_LOCK_Client dramClient;
   interface TagClient tagClient;
   interface FlashRawWriteClient flashRawWrClient;
   interface Put#(Bool) dramAck;
endinterface

//(*synthesize*)
module mkEvictionBufFlush(EvictionBufFlushIFC);
   /*** raw flash client fifos ****/
   FIFO#(FlashCmd) flashReqQ <- mkFIFO;
   FIFO#(TagT) writeTagRespQ <- mkSizedFIFO(valueOf(NumTags));
   FIFO#(Tuple2#(Bit#(128), TagT)) writeWordQ <- mkFIFO;
   FIFO#(Tuple2#(TagT, StatusT)) doneAckQ <- mkFIFO();
   
   /***** write buf flushes to dram *****/
   // Vector#(2,FIFO#(DRAMReq)) dramCmdQs <- replicateM(mkFIFO);
   // Vector#(2,FIFO#(Bit#(512))) dramDtaQs <- replicateM(mkFIFO);
   FIFO#(Tuple2#(DRAM_LOCK_Req, Bit#(1))) dramCmdQ <- mkFIFO;
   FIFO#(DRAM_LOCK_Req) dramCmdQ_raw <- mkFIFO;
   FIFO#(Bit#(512)) dramDtaQ <- mkFIFO;

   //Vector#(2,FIFO#(Bit#(512))) dramDtaQs <- replicateM(mkSizedFIFO(32));

      
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
   //FIFO#(Bit#(1)) bufIdQ_dramResp <- mkFIFO();
   FIFO#(Bit#(1)) preRespQ <- mkFIFO();
   
   FIFO#(Bit#(32)) reserveReqQ <- mkFIFO();
   FIFO#(Bool) reserveRespQ <- mkFIFO();
   rule doReq;
      let req <- toGet(reqQ).get;
      reserveRespQ.deq();
      flashCmdQ.enq(req);
      bufIdQ_dramReq.enq(req.bufId);
      //bufIdQ_dramResp.enq(req.bufId);

      tagReqQ.enq(fromInteger(valueOf(NumPagesPerSuperPage)));
      $display("FlushWriter, prepare for segId = %d", req.segId);
   endrule
      
   
   //***** do flash comands
   //Reg#(Bit#(TLog#(NumPagesPerSuperPage))) pageCnt <- mkReg(0);
   Reg#(Bit#(TLog#(SuperPageSz))) byteCnt_flash <- mkReg(0);
   rule doFlashCmds;
      //***** tag allocation
      let newTag <- toGet(freeTagQ).get;
      
      let req = flashCmdQ.first();
      
      FlashAddrType addr = unpack({req.segId, byteCnt_flash});

      if ( byteCnt_flash + fromInteger(pageSz) == 0 )
         flashCmdQ.deq();
  
      byteCnt_flash <= byteCnt_flash + fromInteger(pageSz);
      
      tag2addrTable.portA.request.put(BRAMRequest{write: True,
                                                  responseOnWrite: False,
                                                  address: newTag,
                                                  datain: byteCnt_flash
                                                  });
      //tag2addrTable.upd(newTag, byteCnt_flash);
            
      $display("FlushWriter send cmd for [segId= %d]: tag = %d, bus = %d, chip = %d, block = %d, page = %d", req.segId, newTag, addr.channel, addr.way, addr.block, addr.page);
      $display("FlushWriter send cmd for [segId= %d]: byteCnt_flash = %d", req.segId, byteCnt_flash);
      flashReqQ.enq(FlashCmd{tag: newTag, op: WRITE_PAGE, bus: addr.channel, chip: addr.way, block: extend(addr.block), page: extend(addr.page)});
            
   endrule
   
   
   //FIFO#(TagT) tagQ_cmd <- mkSizedFIFO(valueOf(NumTags));
   FIFO#(TagT) tagQ_dta <- mkSizedFIFO(valueOf(NumTags));
   //FIFO#(TagT) tagQ_dta <- mkFIFO();
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
   
   //FIFO#(Tuple2#(Bit#(7), Bit#(9))) flushDRAMStatQ <- mkSizedFIFO(32);
   
   rule doFlashWriteReq;
      let bufId = bufIdQ_dramReq.first();
      let addr = dramAddrQ.first();
      if (addr[5:0] != 0) $display("addr is incorrect");

      Bit#(TLog#(PageSz)) byteCnt_page = truncate(byteCnt_dram);
      $display("%m:: flush write buffer dramCmd[bufId = %d], addr = %d", bufId, addr+extend(byteCnt_page));

      Bool doLock = True;
      
      Bool ackReq = False;
      
      if ( byteCnt_dram + 64 == 0 ) begin
         doLock = False;
         bufIdQ_dramReq.deq();
         $display("last dram command sent");
         ackReq = True;
         preRespQ.enq(bufId);
      end
      byteCnt_dram <= byteCnt_dram + 64;
      
      
      if (byteCnt_page + 64 == 0 ) begin
         dramAddrQ.deq();
         $display("last dram for page sent");
      end

      $display("Flash Flusher sends DRAMreq, bufId = %d, pageId = %d, cachelineId = %d", bufId, addr/8192, byteCnt_page/64);
      //dramCmdQ.enq(tuple2(DRAM_LOCK_Req{lock: doLock, rnw: True, addr: extend(addr + extend(byteCnt_page)), data: ?, numBytes: 64}, bufId));
      dramCmdQ.enq(tuple2(DRAM_LOCK_Req{ackReq:ackReq ,lock: False, rnw: True, addr: extend(addr + extend(byteCnt_page)), data: ?, numBytes: 64}, bufId));
      //flushDRAMStatQ.enq(tuple2(truncate(addr/8192), truncate(byteCnt_page/64)));
   endrule
      
   rule doDRAMCmd;
      let v <- toGet(dramCmdQ).get();
      let cmd = tpl_1(v);
      let bufId = tpl_2(v);
      if (bufId == 1) begin
         cmd.addr = cmd.addr + fromInteger(valueOf(SuperPageSz));
      end
      dramCmdQ_raw.enq(cmd);
   endrule
   
   
   
   SerializerIfc#(512, 128, Bit#(0)) des <- mkSerializer();
   Reg#(Bit#(TLog#(SuperPageSz))) byteCnt_resp <- mkReg(0);
   rule doReadResp;
      //let bufId = bufIdQ_dramResp.first();
      let d <- toGet(dramDtaQ).get();
      des.marshall(d, 4, ?);
      byteCnt_resp <= byteCnt_resp + 64;
      // let stats <- toGet(flushDRAMStatQ).get();
      // $display("Flash Flusher got DRAMresp, pageId = %d, cachelineId = %d, data = %h", tpl_1(stats), tpl_2(stats), d);
      // if (byteCnt_resp + 64 == 0)
      //    bufIdQ_dramResp.deq();
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
         $display("Flash Flusher write to flash, tag = %d, wordCnt = %d, data = %h", tag, byteCnt_RdResp/16, tpl_1(d));
      end
      else begin
         //flash.writeWord(tuple2(0, tag));
         writeWordQ.enq(tuple2(0, tag));
         $display("Flash Flusher write to flash, tag = %d, wordCnt = %d, data = %h", tag, byteCnt_RdResp/16, 0);
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
         //let bufId <- toGet(preRespQ).get();
         //respQ.enq(bufId);
         $display("WriteBuf flushed to Flash");
         ackCnt <= 0;
      end
      else begin
         ackCnt <= ackCnt + 1;
      end
         
      $display("WriteDoneAck received, ackCnt = %d, tag = %d", ackCnt, tag);
   endrule
   
   // Vector#(2,DRAMClient) ds;
   // for (Integer i = 0; i < 2; i = i + 1)
   //    ds[i] = (interface DRAMClient;
   //                interface Get request = toGet(dramCmdQs[i]);
   //                interface Put response = toPut(dramDtaQs[i]);
   //             endinterface);
   
   Reg#(Bit#(32)) reqCnt_resp <- mkReg(0);
   interface FlushServer flushServer;
      interface Put request;
         method Action put(FlushReqT v);
            $display("Flush Request, segId = %d", v.segId);
            reqQ.enq(v);
            reserveReqQ.enq(fromInteger(valueOf(NumPagesPerSuperPage)));
         endmethod
      endinterface
      interface Get response = toGet(respQ);
   endinterface
   
   interface dramClient = toClient(dramCmdQ_raw, dramDtaQ);
   
   interface TagClient tagClient;
      interface Client reqTag;
         interface Get request = toGet(tagReqQ);
         interface Put response = toPut(freeTagQ);
      endinterface
      interface Get retTag = toGet(returnTagQ);
   endinterface

   interface FlashRawWriteClient flashRawWrClient;
      interface Client reserve = toClient(reserveReqQ, reserveRespQ);
      interface Client client = toClient(flashReqQ, writeTagRespQ);
      interface Get wordPipe = toGet(writeWordQ);
      interface Put doneAck = toPut(doneAckQ);
   endinterface
   
   interface Put dramAck;
      method Action put(Bool v);
         let bufId <- toGet(preRespQ).get();
         respQ.enq(bufId);
   
         reqCnt_resp <= reqCnt_resp + 1;
         $display("Flusher Done, bufId = %d, reqCnt = %d", bufId, reqCnt_resp);
      endmethod
   endinterface
endmodule
