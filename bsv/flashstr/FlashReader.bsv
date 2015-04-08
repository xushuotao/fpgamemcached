import ControllerTypes::*;
import ValFlashCtrlTypes::*;
import DRAMArbiterTypes::*;
import ValDRAMCtrlTypes::*;
import TagAlloc::*;
import Shifter::*;
import MyArbiter::*;
import Align::*;

import FIFO::*;
import FIFOF::*;
import Vector::*;
import GetPut::*;
import BRAM::*;
import ClientServer::*;
import Connectable::*;

typedef struct{
   TagT reqId;
   FlashAddrType baseAddr;
   ValSizeT numBytes;
   Bit#(TLog#(NumPagesPerSuperPage)) numPages;
   } ReadPipeT deriving (Bits, Eq);


typedef Server#(FlashReadReqT, Tuple2#(Bit#(128), TagT)) FlashReaderServer;

interface FlashReaderIFC;
   interface FlashReaderServer readServer;
   interface TagClient tagClient;

endinterface


module mkFlashReader#(FlashCtrlUser flash)(FlashReaderIFC);
   FIFO#(FlashReadReqT) reqQ <- mkFIFO();
   Vector#(NUM_BUSES, FIFOF#(Tuple2#(Bit#(128), TagT))) respQs <- replicateM(mkFIFOF());
   FIFO#(Tuple2#(Bit#(128), TagT)) respQ <- mkFIFO;
   
   FIFO#(ReadPipeT) immQ <- mkSizedFIFO(valueOf(NumTags));
   
      
   FIFO#(TagT) freeTagQ <- mkFIFO();
   FIFO#(TagT) returnTagQ <- mkFIFO();

   
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
      end
      else begin
         $display("Num of pages is out of bounds");
      end
   endrule
      
   
   BRAM_Configure cfg = defaultValue;
   BRAM2Port#(TagT, Tuple4#(TagT, BusT, PageOffsetT, ValSizeT)) tag2reqIdTable <- mkBRAM2Server(cfg);
   

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

      $display("doFlashCmd cmdCnt = %d, numPages = %d", cmdCnt, numPages);      
      RawFlashAddrT addr = unpack(truncateLSB(pack(v.baseAddr)) + truncate(cmdCnt));
   
      flash.sendCmd(FlashCmd{tag: nextTag, op: READ_PAGE, bus: addr.channel, chip: addr.way, block: extend(addr.block), page: extend(addr.page)});
      
      tag2reqIdTable.portA.request.put(BRAMRequest{write: True,
                                                   responseOnWrite: False,
                                                   address: nextTag,
                                                   datain: tuple4(v.reqId, addr.channel, truncate(pack(v.baseAddr)), v.numBytes)});
      
   endrule

   FIFO#(Tuple2#(Bit#(128), TagT)) immDtaQ <- mkFIFO;
   Vector#(NUM_BUSES,FIFO#(Tuple2#(Bit#(128), TagT))) dataQs <- replicateM(mkFIFO());
   
  
   rule doFlashRead;
      let v <- flash.readWord();
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
      let data <- toGet(immDtaQ).get();
      let reqId = tpl_1(v);
      let channel = tpl_2(v);
      let pgOffset = tpl_3(v);
      let numBytes = tpl_4(v);
      
      //dataQs[channel].enq(data);
      
      for (Integer i = 0; i < valueOf(NUM_BUSES); i = i + 1) begin
         if ( channel == fromInteger(i) ) begin
           //            pgByteCnts[i] <= pgByteCnts[i] + 1;
            
            if (pgByteCnts[i] == 0 ) begin
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
   
   for (Integer i = 0; i < valueOf(NUM_BUSES); i = i + 1 ) begin
      Reg#(Bit#(TSub#(SizeOf#(PageOffsetT),4))) wordCnt_page <- mkReg(0);

      Reg#(Bit#(TSub#(SizeOf#(PageOffsetT),3))) wordCnt_resp <- mkReg(0);
      FIFO#(Bit#(128)) wordQ <- mkFIFO;
      
      ByteAlignIfc#(Bit#(128), TagT) byteAlign <- mkByteAlignPipeline();
      mkConnection(byteAlign.inPipe, toGet(wordQ));
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
         
         if (wordCnt_page == 0) begin
            byteAlign.align(wordOffset, extend(numBytes), reqId);
         end
         
         let d <- toGet(dataQs[i]).get();
         let tag = tpl_2(d);
         let data = tpl_1(d);
         
         //$display("wordCnt_page == %d, wordCnt_resp = %d, numWords = %d", wordCnt_page, wordCnt_resp, numWords);
         if ( wordCnt_page >= wordIdx ) begin
            if (wordCnt_resp >= numWords && wordCnt_page + 1 == 0) begin
               wordCnt_resp <= 0;
            end
            else if (wordCnt_resp < numWords) begin
               wordCnt_resp <= wordCnt_resp + 1;
            end
            
            if ( wordCnt_resp < numWords ) begin
               wordQ.enq(data);
            end

         end
      endrule
      
      rule doConn;
         let v <- byteAlign.outPipe.get();
         respQs[i].enq(tuple2(tpl_1(v), tpl_3(v)));
      endrule
   end

   Arbiter_IFC#(NUM_BUSES) arbiter <- mkArbiter(False);

   for (Integer i = 0; i < valueOf(NUM_BUSES); i = i + 1) begin
      rule doReqs_0 if (respQs[i].notEmpty);
         arbiter.clients[i].request;
      endrule
      
      rule doReqs_1 if (arbiter.grant_id == fromInteger(i));
         let v <- toGet(respQs[i]).get();
         respQ.enq(v);
      endrule
   end
         
              
   interface FlashReaderServer readServer;      
      interface Put request = toPut(reqQ);
      interface Get response = toGet(respQ);
   endinterface   
   
   interface TagClient tagClient;
      interface Get retTag = toGet(returnTagQ);
      interface Put reqTag = toPut(freeTagQ);
   endinterface
endmodule
