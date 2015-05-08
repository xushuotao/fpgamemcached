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

typedef struct{
   TagT reqId;
   FlashAddrType baseAddr;
   ValSizeT numBytes;
   Bit#(TLog#(NumPagesPerSuperPage)) numPages;
   } ReadPipeT deriving (Bits, Eq);


//typedef Server#(FlashReadReqT, Tuple2#(WordT, TagT)) FlashReaderServer;
//typedef Client#(FlashReadReqT, Tuple2#(WordT, TagT)) FlashReaderClient;

interface FlashReaderIFC;
   interface FlashReadServer server;
   interface TagClient tagClient;
   interface FlashRawReadClient flashRawRdClient;
endinterface

(*synthesize*)
module mkFlashReader(FlashReaderIFC);
   FIFO#(FlashReadReqT) reqQ <- mkSizedFIFO(valueOf(NumTags));
   Vector#(NUM_BUSES, FIFOF#(Tuple2#(WordT, TagT))) respQs <- replicateM(mkFIFOF());
   FIFO#(Tuple2#(WordT, TagT)) respQ <- mkFIFO;
   
   FIFO#(ReadPipeT) immQ <- mkSizedFIFO(valueOf(NumTags));
   
      
   FIFO#(Bit#(32)) tagReqQ <- mkFIFO();
   FIFO#(TagT) freeTagQ <- mkFIFO();
   FIFO#(TagT) returnTagQ <- mkFIFO();
   
   FIFO#(Tuple2#(ValSizeT, TagT)) burstSzQ <- mkFIFO();

   FIFO#(FlashCmd) flashReqQ <- mkFIFO();
   FIFO#(Tuple2#(Bit#(128), TagT)) flashRespQ <- mkFIFO();
   
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
      
      if ( numPages == 1 ) begin
         immQ.enq(ReadPipeT{reqId: req.reqId, baseAddr: addr, numBytes: numBytes, numPages: truncate(numPages)});
         tagReqQ.enq(extend(numPages));
      end
      else begin
         $display("Num of pages is out of bounds");
      end
   endrule
      
   
   BRAM_Configure cfg = defaultValue;
   BRAM2Port#(TagT, Tuple4#(TagT, BusT, PageOffsetT, ValSizeT)) tag2reqIdTable <- mkBRAM2Server(cfg);
   
   //RegFile#(TagT, Tuple4#(TagT, BusT, PageOffsetT, ValSizeT)) tag2reqIdTable <- mkRegFileFull;
    
   

   Reg#(Bit#(32)) cmdCnt <- mkReg(0);
   rule doFlashCmd;
      //***** tag allocation
      let nextTag <- toGet(freeTagQ).get();


      let v = immQ.first();
      let numPages = v.numPages;
      if ( cmdCnt + 1 >= extend(numPages) ) begin
         immQ.deq();
         cmdCnt <= 0;
      end
      else begin
         cmdCnt <= cmdCnt + 1;
      end

      //$display("doFlashCmd cmdCnt = %d, numPages = %d", cmdCnt, numPages);      
      RawFlashAddrT addr = unpack(truncateLSB(pack(v.baseAddr)) + truncate(cmdCnt));
      $display("Flash Reader sends flash cmd, reqId = %d, addr = %d", v.reqId, addr);
      //flash.sendCmd(FlashCmd{tag: nextTag, op: READ_PAGE, bus: addr.channel, chip: addr.way, block: extend(addr.block), page: extend(addr.page)});
      flashReqQ.enq(FlashCmd{tag: nextTag, op: READ_PAGE, bus: addr.channel, chip: addr.way, block: extend(addr.block), page: extend(addr.page)});
      
      tag2reqIdTable.portA.request.put(BRAMRequest{write: True,
                                                   responseOnWrite: False,
                                                   address: nextTag,
                                                   datain: tuple4(v.reqId, addr.channel, truncate(pack(v.baseAddr)), v.numBytes)});
      //tag2reqIdTable.upd(nextTag, tuple4(v.reqId, addr.channel, truncate(pack(v.baseAddr)), v.numBytes));
      
   endrule

   FIFO#(Tuple2#(Bit#(128), TagT)) immDtaQ <- mkFIFO;
   Vector#(NUM_BUSES,FIFO#(Tuple2#(Bit#(128), TagT))) dataQs <- replicateM(mkFIFO());
   
  
   rule doFlashRead;
      //let v <- flash.readWord();
      let v <- toGet(flashRespQ).get();
      let tag = tpl_2(v);
      immDtaQ.enq(v);
      //if ( byteCnt_page == 0 )
      tag2reqIdTable.portB.request.put(BRAMRequest{write:False,
                                                   responseOnWrite: False,
                                                   address:tag,
                                                   datain: ?});
      
   endrule
   
   //tuple3 = {reqId, numBytes, offset}
   Vector#(NUM_BUSES,FIFO#(Tuple3#(TagT, ValSizeT, PageOffsetT))) cmdQs <- replicateM(mkFIFO);
   Vector#(NUM_BUSES, Reg#(Bit#(TLog#(PageSizeUser)))) pgByteCnts <- replicateM(mkReg(0));
   rule doDistributeData;
      let v <- tag2reqIdTable.portB.response.get();
      //let v = tag2reqIdTable.sub(tag);
      
      

      //let data <- flash.readWord();
      let data <- toGet(immDtaQ).get();
      
      let tag = tpl_2(data);
   
      let reqId = tpl_1(v);
      let channel = tpl_2(v);
      let pgOffset = tpl_3(v);
      let numBytes = tpl_4(v);
      
      //dataQs[channel].enq(data);
      
      for (Integer i = 0; i < valueOf(NUM_BUSES); i = i + 1) begin
         if ( channel == fromInteger(i) ) begin
           //            pgByteCnts[i] <= pgByteCnts[i] + 1;
            
            if (pgByteCnts[i] == 0 ) begin
               $display("Flash Read, got first token from reqid = %d", reqId);
               cmdQs[i].enq(tuple3(reqId, numBytes, pgOffset));
            end
            
            if (pgByteCnts[i] == fromInteger(pageSizeUser-16) ) begin
               pgByteCnts[i] <= 0;
               returnTagQ.enq(tpl_2(data));
               $display("tag is returned, tag = %d", tpl_2(data));
            end
            else begin
               pgByteCnts[i] <= pgByteCnts[i] + 16;
            end
            
            if (pgByteCnts[i] < fromInteger(pageSz)) begin
               dataQs[i].enq(data);
            end
         end
      end
      
   endrule
   

   Vector#(NUM_BUSES,FIFO#(Bit#(128))) wordQs <- replicateM(mkSizedBRAMFIFO(512));
   Vector#(NUM_BUSES,FIFOF#(Tuple3#(Bit#(4), ValSizeT, TagT))) alignCmdQs <- replicateM(mkFIFOF);
   
   for (Integer i = 0; i < valueOf(NUM_BUSES); i = i + 1 ) begin
      Reg#(Bit#(TSub#(SizeOf#(PageOffsetT),4))) wordCnt_page <- mkReg(0);

      Reg#(Bit#(TSub#(SizeOf#(PageOffsetT),3))) wordCnt_resp <- mkReg(0);

      
      //ByteAlignIfc#(Bit#(128), TagT) byteAlign <- mkByteAlignPipeline();
      //ByteAlignIfc#(Bit#(128), TagT) byteAlign <- mkByteAlignCombinational();
      //mkConnection(byteAlign.inPipe, toGet(wordQ));
      //mkConnection(byteAlign.outPipe, toPut(respQs[i]));
      
      rule doExtractData;
         let v = cmdQs[i].first;
         let reqId = tpl_1(v);
         let numBytes = tpl_2(v);
         let pgOffset = tpl_3(v);
         
         Bit#(TSub#(SizeOf#(PageOffsetT),4)) wordIdx = truncateLSB(pgOffset);
         Bit#(4) wordOffset = truncate(pgOffset);
         
         ValSizeT effectiveBytes = extend(wordOffset) + numBytes;
         Bit#(TSub#(SizeOf#(PageOffsetT), 3)) numWords = truncate(effectiveBytes >> 4);
         Bit#(4) remainder = truncate(effectiveBytes);
         if (remainder != 0) begin
            numWords = numWords + 1;
         end
         
      
         wordCnt_page <= wordCnt_page + 1;
      
         if (wordCnt_page + 1 == 0 )
            cmdQs[i].deq();
         
         
         let d <- toGet(dataQs[i]).get();
         let tag = tpl_2(d);
         let data = tpl_1(d);
         
         $display("Flash read: do extract data, reqId = %d, wordCnt_page == %d, wordCnt_resp = %d, numWords = %d", reqId, wordCnt_page, wordCnt_resp, numWords);
         if ( wordCnt_page >= wordIdx ) begin
            if ( wordCnt_page + 1 == 0) begin
               wordCnt_resp <= 0;
            end
            else if (wordCnt_resp < numWords) begin
               wordCnt_resp <= wordCnt_resp + 1;
            end
            
            if ( wordCnt_resp + 1 == numWords )
               alignCmdQs[i].enq(tuple3(wordOffset, numBytes, reqId));
      
            if ( wordCnt_resp < numWords ) begin
               wordQs[i].enq(data);
            end

         end
      endrule
      
   end
   
   FIFO#(Tuple4#(Bit#(4), ValSizeT, TagT, Bit#(TLog#(NUM_BUSES)))) alignCmd <- mkFIFO;
   Arbiter_IFC#(NUM_BUSES) arbiter <- mkArbiter(False);

   for (Integer i = 0; i < valueOf(NUM_BUSES); i = i + 1) begin
      rule doReqs_0 if (alignCmdQs[i].notEmpty);
         arbiter.clients[i].request;
      endrule
      
      rule doReqs_1 if (arbiter.grant_id == fromInteger(i));
         let v <- toGet(alignCmdQs[i]).get();
         alignCmd.enq(tuple4(tpl_1(v), tpl_2(v), tpl_3(v), fromInteger(i)));
      endrule
   end
   
   ByteAlignIfc#(Bit#(128), TagT) byteAlign <- mkByteAlignCombinational();
   Reg#(ValSizeT) byteCnt_align <- mkReg(0);
   rule doAlign;
      let v = alignCmd.first();
      let wordOffset = tpl_1(v);
      let nBytes = tpl_2(v);
      let reqId = tpl_3(v);
      let sel = tpl_4(v);
      
      if ( byteCnt_align == 0) begin
         byteAlign.align(wordOffset, extend(nBytes), reqId);
         burstSzQ.enq(tuple2(nBytes, reqId));
      end
   
      let d <- toGet(wordQs[sel]).get();
      byteAlign.inPipe.put(d);
      
      if (byteCnt_align + 16 < nBytes) begin
         byteCnt_align <= byteCnt_align + 16;
      end
      else begin
         byteCnt_align <= 0;
         alignCmd.deq();
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
