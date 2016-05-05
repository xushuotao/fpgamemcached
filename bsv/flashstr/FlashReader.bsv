import ControllerTypes::*;
import MemcachedTypes::*;
//import ValuestrCommon::*;
import ValFlashCtrlTypes::*;
import FlashServer::*;
import DRAMCommon::*;


import TagAlloc::*;
import Shifter::*;
import MyArbiter::*;
import Align::*;
import SerDes::*;

import FIFO::*;
import BRAMFIFO::*;
import FIFOF::*;
import Vector::*;
import GetPut::*;
import BRAM::*;
import RegFile::*;
import ClientServer::*;
import ClientServerHelper::*;
import Connectable::*;

import ReorderBuffer::*;

typedef struct{
   TagT reqId;
   FlashAddrType baseAddr;
   ValSizeT numBytes;
   Bit#(TAdd#(TLog#(NumPagesPerSuperPage),1)) numPages;
   } ReadPipeT deriving (Bits, Eq);


//typedef Server#(FlashReadReqT, Tuple2#(WordT, TagT)) FlashReaderServer;
//typedef Client#(FlashReadReqT, Tuple2#(WordT, TagT)) FlashReaderClient;

interface FlashReaderIFC;
   interface FlashReadServer server;
   interface TagClient tagClient;
   interface FlashRawReadClient flashRawRdClient;
endinterface

//(*synthesize*)
module mkFlashReader(FlashReaderIFC);
   FIFO#(FlashReadReqT) reqQ <- mkSizedFIFO(valueOf(NumTags));
   Vector#(NUM_BUSES, FIFOF#(Tuple2#(WordT, TagT))) respQs <- replicateM(mkFIFOF());
   FIFO#(Tuple2#(WordT, TagT)) respQ <- mkFIFO;
   
   FIFO#(ReadPipeT) immQ <- mkSizedFIFO(valueOf(NumTags));
   
      
   FIFO#(Bit#(32)) tagReqQ <- mkFIFO();
   FIFO#(TagT) freeTagQ <- mkFIFO();
   FIFO#(TagT) returnTagQ <- mkFIFO();
   
   //FIFO#(Tuple2#(ValSizeT, TagT)) burstSzQ <- mkFIFO();
   FIFO#(Tuple2#(ValSizeT, TagT)) burstSzQ <- mkSizedFIFO(128);

   FIFO#(FlashCmd) flashReqQ <- mkFIFO();
   FIFO#(Tuple2#(Bit#(128), TagT)) flashRespQ <- mkFIFO();
   
   ReorderBuffer_Flash reorderbuf <- mkReorderBuffer_Flash();
   
   rule doReaderCmd;
      let req <- toGet(reqQ).get();
      let addr = req.addr;
      let numBytes = req.numBytes;
      
      let addrBits = pack(addr);
      
      Bit#(TLog#(NumSuperPages)) segId = truncateLSB(addrBits);
      Bit#(TLog#(SuperPageSz)) addrSeg = truncate(addrBits);
      
      //if ( extend(addrSeg) + numBytes > fromInteger(segmentSz) ) begin
      //   $dipsplay("Req goes out of segment range");
      //end
      
      let numPages = (extend(addr.offset) + numBytes) >> valueOf(TLog#(PageSz));
      Bit#(TLog#(PageSz)) addrRemainder = truncate((extend(addr.offset) + numBytes));
      if ( addrRemainder != 0 )
         numPages = numPages + 1;
      
      //if ( numPages == 1 ) begin
      $display("read cmd basics, reqid = %d, baseAddr = %d, numBytes = %d, numPages = %d", req.reqId, addr, numBytes, numPages);
      immQ.enq(ReadPipeT{reqId: req.reqId, baseAddr: addr, numBytes: numBytes, numPages: truncate(numPages)});
      tagReqQ.enq(extend(numPages));
      reorderbuf.reserveServer.request.put(truncate(numPages));
      //end
      // else begin
      //    $display("Num of pages is out of bounds");
      // end
   endrule
      
   
   BRAM_Configure cfg = defaultValue;
   // address: virtual pageId;
   // data: regId, deqTag, enqTag, pageCnt, channel, PageOffset, nBytes, numPages;
   BRAM2Port#(TagT, Tuple8#(TagT, TagT, TagT, Bit#(8), BusT, PageOffsetT, ValSizeT, Bit#(8))) tag2reqIdTable <- mkBRAM2Server(cfg);
   
   // RegFile#(TagT, Tuple8#(TagT, TagT, TagT, Bit#(8), BusT, PageOffsetT, ValSizeT, Bit#(8))) tag2reqIdTable <- mkRegFileFull;
    
   

   Reg#(Bit#(32)) cmdCnt <- mkReg(0);
   Reg#(Bit#(32)) reqNum <- mkReg(0);
   Reg#(Bit#(32)) respNum <- mkReg(0);
   rule doFlashCmd;
      //***** tag allocation
      let nextTag <- toGet(freeTagQ).get();
      let d <- reorderbuf.reserveServer.response.get();

      let v = immQ.first();
      let numPages = v.numPages;
      if ( cmdCnt + 1 >= extend(numPages) ) begin
         immQ.deq();
         cmdCnt <= 0;
      end
      else begin
         cmdCnt <= cmdCnt + 1;
      end

      $display("doFlashCmd cmdCnt = %d, numPages = %d", cmdCnt, numPages);      
      RawFlashAddrT addr = unpack(truncateLSB(pack(v.baseAddr)) + truncate(cmdCnt));
      $display("Flash Reader sends flash cmd, reqId = %d, addr = %d, tag = %d, deqTag = %d, enqTag = %d", v.reqId, addr, nextTag, tpl_1(d), tpl_2(d));
      $display("reqNum = %d", reqNum);
      reqNum <= reqNum + 1;
      flashReqQ.enq(FlashCmd{tag: nextTag, op: READ_PAGE, bus: addr.channel, chip: addr.way, block: extend(addr.block), page: extend(addr.page)});
      
      tag2reqIdTable.portA.request.put(BRAMRequest{write: True,
                                                   responseOnWrite: False,
                                                   address: nextTag,
                                                   datain: tuple8(v.reqId,
                                                                  tpl_1(d),
                                                                  tpl_2(d),
                                                                  truncate(cmdCnt),
                                                                  addr.channel,
                                                                  truncate(pack(v.baseAddr)),
                                                                  v.numBytes,
                                                                  truncate(numPages))});
      
      // tag2reqIdTable.upd(nextTag, tuple8(v.reqId,
      //                                    tpl_1(d),
      //                                    tpl_2(d),
      //                                    truncate(cmdCnt),
      //                                    addr.channel,
      //                                    truncate(pack(v.baseAddr)),
      //                                    v.numBytes,
      //                                    truncate(numPages)));
      
   endrule

   FIFO#(Tuple2#(Bit#(128), TagT)) immDtaQ <- mkFIFO;
   //Vector#(NUM_BUSES,FIFO#(Tuple2#(Bit#(128), TagT))) dataQs <- replicateM(mkFIFO());
   
   FIFO#(Tuple8#(TagT, TagT, TagT, Bit#(8), BusT, PageOffsetT, ValSizeT, Bit#(8))) metaQ <- mkFIFO();
   rule doFlashRead;
      //let v <- flash.readWord();
      let v <- toGet(flashRespQ).get();
      let tag = tpl_2(v);
      immDtaQ.enq(v);
      //if ( byteCnt_page == 0 )
      //$display("Flash Read God data, tag = %d, data = %h", tag, tpl_1(v));
      tag2reqIdTable.portB.request.put(BRAMRequest{write:False,
                                                   responseOnWrite: False,
                                                   address:tag,
                                                   datain: ?});
      // metaQ.enq(tag2reqIdTable.sub(tag));
      
   endrule
   
   //tuple3 = {reqId, numBytes, offset}
   //Vector#(NUM_BUSES,FIFO#(Tuple3#(TagT, ValSizeT, PageOffsetT))) cmdQs <- replicateM(mkFIFO);
   FIFO#(Tuple4#(TagT, ValSizeT, PageOffsetT, Bit#(8))) cmdQ <- mkSizedFIFO(128);
   Vector#(NUM_BUSES, Reg#(Bit#(TLog#(PageSizeUser)))) pgByteCnts <- replicateM(mkReg(0));
   rule doDistributeData;
      let v <- tag2reqIdTable.portB.response.get();
      // let v <- toGet(metaQ).get();
      
      //let data <- flash.readWord();
      let data <- toGet(immDtaQ).get();
      
      let tag = tpl_2(data);

   // address: virtual pageId;
   // data: regId, deqTag, enqTag, pageCnt, channel, PageOffset, nBytes;
   
      let reqId = tpl_1(v);
      let deqTag = tpl_2(v);
      let enqTag = tpl_3(v);
      let pageSeqId = tpl_4(v);
      let channel = tpl_5(v);
      let pgOffset = tpl_6(v);
      let numBytes = tpl_7(v);
      let numPages = tpl_8(v);
      
      $display("Flash Read Got data, enqtag = %d, data = %h, reqId = %d", enqTag, tpl_1(v), reqId);
      
      //dataQs[channel].enq(data);
      
      for (Integer i = 0; i < valueOf(NUM_BUSES); i = i + 1) begin
         if ( channel == fromInteger(i) ) begin
           //            pgByteCnts[i] <= pgByteCnts[i] + 1;
            
            if (pgByteCnts[i] == 0 && pageSeqId == 0) begin
               $display("Flash Read, got first token from reqid = %d", reqId);
               // cmdQ.enq(tuple4(reqId, numBytes, pgOffset, numPages));
               // reorderbuf.deqReq(deqTag, numPages);
               //burstSzQ.enq(tuple2(numBytes, reqId));
            end
            
            if (pgByteCnts[i] == fromInteger(pageSizeUser-16) ) begin
               pgByteCnts[i] <= 0;
               returnTagQ.enq(tpl_2(data));
               $display("tag is returned, tag = %d", tpl_2(data));
               $display("respNum = %d", respNum);
               respNum <= respNum + 1;
               if ( pageSeqId == 0 ) begin
                  cmdQ.enq(tuple4(reqId, numBytes, pgOffset, numPages));
                  reorderbuf.deqReq(deqTag, numPages);
                  burstSzQ.enq(tuple2(numBytes, reqId));
               end
            end
            else begin
               pgByteCnts[i] <= pgByteCnts[i] + 16;
            end
            
            if (pgByteCnts[i] < fromInteger(pageSz)) begin
               //dataQs[i].enq(data);
               reorderbuf.inData(enqTag, tpl_1(data));
            end
         end
      end
      
   endrule


   Reg#(Bit#(TSub#(SizeOf#(ValSizeT),3))) wordCnt_total <- mkReg(0);
   Reg#(Bit#(TSub#(SizeOf#(ValSizeT),3))) wordCnt_resp <- mkReg(0);

   ByteAlignIfc#(Bit#(128), TagT) byteAlign <- mkByteAlignCombinational();
   
   Reg#(Bit#(8)) byteReg <- mkReg(0);
   
   rule doExtractData;
      let v = cmdQ.first;
      let reqId = tpl_1(v);
      let numBytes = tpl_2(v);
      let pgOffset = tpl_3(v);
      let numPages = tpl_4(v);

      let d <- reorderbuf.outPipe.get();
            
      Bit#(TSub#(SizeOf#(ValSizeT),3)) wordIdx = extend(pgOffset>>4);
      Bit#(4) wordOffset = truncate(pgOffset);
      
      ValSizeT effectiveBytes = extend(wordOffset) + numBytes;
      Bit#(TSub#(SizeOf#(ValSizeT), 3)) numWords = truncate(effectiveBytes >> 4);
      Bit#(4) remainder = truncate(effectiveBytes);
      if (remainder != 0) begin
         numWords = numWords + 1;
      end

      // Vector#(16, Bit#(8)) dVec = unpack(d);
      // byteReg <= dVec[15];
      // Bool warning = (dVec[0] != byteReg + 1);
      
      // for (Integer i = 0; i < 15; i = i + 1 ) begin
      //    if ( dVec[i] + 1 != dVec[i+1] )
      //       warning = True;
      // end

      // if ( warning ) $display("Warning!!!!");
      
      $display("Flash read: do extract data, reqId = %d, wordCnt_total == %d, wordCnt_resp = %d, numWords = %d, numPages = %d, wordMax = %d, data = %h", reqId, wordCnt_total, wordCnt_resp, numWords, numPages, numPages << 9, d);

      
      if (wordCnt_total + 1 == extend(numPages) << 9 ) begin
         cmdQ.deq();
         wordCnt_total <= 0;
      end
      else begin
         wordCnt_total <= wordCnt_total + 1;
      end
      
      if ( wordCnt_total >= wordIdx ) begin
         if ( wordCnt_total + 1 == extend(numPages) << 9) begin
            wordCnt_resp <= 0;
         end
         else if (wordCnt_resp < numWords) begin
            wordCnt_resp <= wordCnt_resp + 1;
         end

         if ( wordCnt_resp == 0) begin
            byteAlign.align(wordOffset, extend(numBytes), reqId);
            //burstSzQ.enq(tuple2(numBytes, reqId));
         end
      
         if ( wordCnt_resp < numWords ) begin
            byteAlign.inPipe.put(d);
         end
      end
   endrule
              
   interface FlashReadServer server;      
      interface Server readServer;
         interface Put request = toPut(reqQ);
         interface Get response;
            method ActionValue#(Tuple2#(Bit#(128), TagT)) get;
               let d <- byteAlign.outPipe.get();
               return tuple2(tpl_1(d), tpl_3(d));
            endmethod
         endinterface
      endinterface
      interface Get burstSz = toGet(burstSzQ);
   endinterface   
   
   interface TagClient tagClient;
      interface Client reqTag;
         interface Get request = toGet(tagReqQ);
         interface Put response = toPut(freeTagQ);
      endinterface
      interface Get retTag = toGet(returnTagQ);
   endinterface
   
   interface FlashRawReadClient flashRawRdClient = toClient(flashReqQ, flashRespQ);
   
endmodule
