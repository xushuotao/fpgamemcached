import Cntrs::*;
import Vector::*;
import FIFOVector::*;
import FIFO::*;
import GetPut::*;
import ControllerTypes::*;
import Connectable::*;
import ClientServer::*;

interface ReorderBurstBuffer;
   method Action enqReq(TagT tag, Bit#(21) nBytes);
   interface Put#(Tuple2#(Bit#(128), Bool)) inPipe;
   method Action deqReq(TagT tag, Bit#(21) nBytes);
   interface Get#(Tuple2#(Bit#(128), Bool)) outPipe;
endinterface

(*synthesize*)
module mkReorderBurstBuffer(ReorderBurstBuffer);
   FIFOVector#(128, Bit#(7), 128) sndQIds <- mkBRAMFIFOVector();
   FIFOVector#(128, Tuple2#(Bit#(128),Bool), 16) fifos <- mkBRAMFIFOVector();
   FIFO#(Bit#(7)) freeSndQId <- mkSizedFIFO(128);

   Reg#(Bit#(7)) initCnt <- mkReg(0);
   Reg#(Bool) initialized <- mkReg(False);
   
   FIFO#(Tuple2#(TagT, Bit#(21))) enqReqQ  <- mkFIFO();
   Count#(Bit#(8)) freeQCnt <- mkCount(128);
   
   rule init if (!initialized);
      freeSndQId.enq(initCnt);
      initCnt <= initCnt + 1;
      if ( initCnt == -1 ) begin
         initialized <= True;
      end
   endrule
 
   Reg#(Bit#(21)) byteCnt_wr <- mkReg(0);
   FIFO#(Tuple2#(Bit#(128), Bool)) inDtaQ <- mkFIFO();
   
   rule doEnqData if ( initialized);
      let d <- toGet(inDtaQ).get();

      let v = enqReqQ.first();
      let tag_req = tpl_1(v);
      let nBytes = tpl_2(v);

      let tag_fifo = freeSndQId.first();
      Bool fifoIdQ_en =  (byteCnt_wr%256 == 240);

      if ( byteCnt_wr%256 == 0 )
         sndQIds.enq(tag_req, tag_fifo); 
      
      fifos.enq(tag_fifo, d);
      
      if (byteCnt_wr +16 >= nBytes) begin
         enqReqQ.deq();
         fifoIdQ_en = True;
         byteCnt_wr <= 0;
      end
      else begin
         byteCnt_wr <= byteCnt_wr + 16;
      end
      $display("%m, doEnqData, byteCnt_wr = %d, fifoIdQ_en = %b", byteCnt_wr, fifoIdQ_en);
      
      if ( fifoIdQ_en) begin
         freeSndQId.deq;
         $display("deq freeSndId tag = %d", tag_fifo);
      end
   endrule
   
   
   Reg#(Bit#(8)) bufCnt <- mkReg(0);
   FIFO#(Tuple2#(TagT, Bit#(21))) deqReqQ <- mkFIFO;
   rule doDeqReq if (initialized);
      let v = deqReqQ.first();
      let tag = tpl_1(v);
      let nBytes = tpl_2(v);
      let nBufs = nBytes/256;
      if ( nBytes%256 != 0) nBufs = nBufs + 1;

      sndQIds.deqServer.request.put(tuple2(tag, True));
      if ( extend(bufCnt) + 1 < nBufs ) begin
         bufCnt <= bufCnt + 1;
      end
      else begin
         bufCnt <= 0;
         deqReqQ.deq();
      end
   endrule
   
   FIFO#(Bit#(7)) fifoIdQ <- mkFIFO();
   mkConnection(toPut(fifoIdQ), sndQIds.deqServer.response);
   
   Reg#(Bit#(21)) byteCnt_rd <- mkReg(0);
   FIFO#(Bit#(21)) deqBytesQ <- mkFIFO();
   rule doDeqData if (initialized);
      let nBytes = deqBytesQ.first;

      let tag_fifo = fifoIdQ.first();

      Bool fifoIdQ_en = (byteCnt_rd%256 == 240);
     
      fifos.deqServer.request.put(tuple2(tag_fifo, True));
      
      if (byteCnt_rd +16 >= nBytes) begin
         deqBytesQ.deq();
         fifoIdQ_en = True;
         byteCnt_rd <= 0;
      end
      else begin
         byteCnt_rd <= byteCnt_rd + 16;
      end
      
      if ( fifoIdQ_en) begin
         //freeIdQ.deq;
         fifoIdQ.deq();
         freeSndQId.enq(tag_fifo);
      end
   endrule
   
   
   
   method Action enqReq(TagT tag, Bit#(21) nBytes);
      enqReqQ.enq(tuple2(tag, nBytes));
   endmethod
   interface Put inPipe = toPut(inDtaQ);
   method Action deqReq(TagT tag, Bit#(21) nBytes);
      deqReqQ.enq(tuple2(tag, nBytes));
      deqBytesQ.enq(nBytes);
   endmethod
   interface Get outPipe = fifos.deqServer.response;
endmodule



interface ReorderBuffer;
   interface Server#(Bit#(21), TagT) reserveServer;
   method Action inData(TagT tag, Tuple2#(Bit#(128), Bool) data);
   method Action deqReq(TagT tag, Bit#(21) nBytes);
   interface Get#(Tuple2#(Bit#(128), Bool)) outPipe;
endinterface

(*synthesize*)
module mkReorderBuffer(ReorderBuffer);
   FIFOVector#(128, Bit#(7), 128) enqIds <- mkBRAMFIFOVector();
   FIFOVector#(128, Bit#(7), 128) deqIds <- mkBRAMFIFOVector();
   
   FIFOVector#(128, Tuple2#(Bit#(128),Bool), 16) fifos <- mkBRAMFIFOVector();
   
   FIFO#(Bit#(7)) freeReqIdQ <- mkSizedFIFO(128);
   FIFO#(Bit#(7)) freeFifoIdQ <- mkSizedFIFO(128);

   Reg#(Bit#(7)) initCnt <- mkReg(0);
   Reg#(Bool) initialized <- mkReg(False);
   

   FIFO#(Bit#(21)) bufMaxQ  <- mkFIFO();

   rule init if (!initialized);
      freeReqIdQ.enq(initCnt);
      freeFifoIdQ.enq(initCnt);
      initCnt <= initCnt + 1;
      if ( initCnt == -1 ) begin
         initialized <= True;
      end
   endrule
   
   FIFO#(Bit#(21)) reqQ <- mkFIFO();
   FIFO#(TagT) respQ <- mkFIFO();
   
   Reg#(Bit#(21)) bufCnt <- mkReg(0);
   
      
   FIFO#(Tuple2#(Bit#(128), Bool)) inDtaQ <- mkFIFO();
   Vector#(128, Reg#(Bit#(21))) inDtaByteCnt <- replicateM(mkReg(0)); 
   Vector#(128, FIFO#(Bit#(21))) inDtaByteMax <- replicateM(mkFIFO);
   
   Reg#(Bit#(21)) deqByteCnt <- mkReg(0);
   //FIFO#(Bit#(21)) deqMaxByteQ <- mkFIFO;
                 
   rule doReq;
      let nBytes = reqQ.first;
      let nBufs = nBytes/256;
      if ( nBytes%256 != 0) 
         nBufs = nBufs + 1;

      let tag_req = freeReqIdQ.first;
      
      if ( bufCnt == 0 ) begin
         respQ.enq(tag_req);
         inDtaByteMax[tag_req].enq(nBytes);
         //deqMaxByteQ[tag_req].enq(nBufs);
      end
      
      if ( bufCnt + 1 >=  nBufs) begin
         reqQ.deq();
         bufCnt <= 0;
         freeReqIdQ.deq();
      end
      else begin
         bufCnt <= bufCnt + 1;
      end
      
      let tag_fifo <- toGet(freeFifoIdQ).get();
      enqIds.enq(tag_req, tag_fifo);
      deqIds.enq(tag_req, tag_fifo);
   endrule
   
   rule doEnq;
      let data <- toGet(inDtaQ).get();
      let tag <- enqIds.deqServer.response.get();
      fifos.enq(tag, data);
   endrule
   
   
   FIFO#(Tuple2#(TagT, Bit#(21))) deqReqQ <- mkFIFO();
   rule doDeq;
      let v = deqReqQ.first();
      let tag_req = tpl_1(v);
      let byteMax = tpl_2(v);
      
      Bool doDeqId = (deqByteCnt%256) == (256 - 16);
      if ( deqByteCnt + 16 < byteMax ) begin
         deqByteCnt <= deqByteCnt + 16;
         doDeqId = True;
      end
      else begin
         deqByteCnt <= 0;
         deqReqQ.deq();
      end
      
      deqIds.deqServer.request.put(tuple2(tag_req, doDeqId));
   endrule
   
   rule doDeq_1;
      let tag_fifo <- deqIds.deqServer.response.get();
      fifos.deqServer.request.put(tuple2(tag_fifo, True));
   endrule
      
   interface Server reserveServer;
      interface Put request = toPut(reqQ);
      interface Get response = toGet(respQ);
   endinterface
      
   method Action inData(TagT tag, Tuple2#(Bit#(128), Bool) data);
      if ( inDtaByteCnt[tag]%256 == (256 - 16) || inDtaByteCnt[tag] + 16 >= inDtaByteMax[tag].first ) begin
         enqIds.deqServer.request.put(tuple2(tag,True));
         inDtaByteMax[tag].deq();
         inDtaByteCnt[tag] <= 0;
      end
      else begin
         inDtaByteCnt[tag] <= inDtaByteCnt[tag] + 16;
         enqIds.deqServer.request.put(tuple2(tag,False));
      end
      inDtaQ.enq(data);
   endmethod
   
   method Action deqReq(TagT tag, Bit#(21) nBytes);
      deqReqQ.enq(tuple2(tag, nBytes));
   endmethod
      
   interface Get outPipe = fifos.deqServer.response;

endmodule
   

interface ReorderBuffer_Flash;
   interface Server#(Bit#(8), Tuple2#(TagT, TagT)) reserveServer;
   method Action inData(TagT tag, Bit#(128) data);
   method Action deqReq(TagT tag, Bit#(8) nBytes);
   interface Get#(Bit#(128)) outPipe;
endinterface

(*synthesize*)
module mkReorderBuffer_Flash(ReorderBuffer_Flash);
   FIFOVector#(128, Bit#(7), 128) enqIds <- mkBRAMFIFOVector();
   FIFOVector#(128, Bit#(7), 128) deqIds <- mkBRAMFIFOVector();
   
   FIFOVector#(128, Bit#(128), 512) fifos <- mkBRAMFIFOVector();
   
   FIFO#(Bit#(7)) freeReqIdQ <- mkSizedFIFO(128);
   FIFO#(Bit#(7)) freeFifoIdQ <- mkSizedFIFO(128);

   Reg#(Bit#(7)) initCnt <- mkReg(0);
   Reg#(Bool) initialized <- mkReg(False);
   

   FIFO#(Bit#(8)) bufMaxQ  <- mkFIFO();

   rule init if (!initialized);
      freeReqIdQ.enq(initCnt);
      freeFifoIdQ.enq(initCnt);
      initCnt <= initCnt + 1;
      if ( initCnt == -1 ) begin
         initialized <= True;
      end
   endrule
   
   FIFO#(Bit#(8)) reqQ <- mkFIFO();
   FIFO#(Tuple2#(TagT, TagT)) respQ <- mkFIFO();
   
   Reg#(Bit#(8)) bufCnt <- mkReg(0);

   FIFO#(Tuple2#(TagT,Bit#(128))) inDtaQ <- mkFIFO();
                 
   rule doReq;

      let nBufs = reqQ.first;

      let tag_req = freeReqIdQ.first;
      
      if ( bufCnt + 1 ==  nBufs) begin
         reqQ.deq();
         bufCnt <= 0;
         freeReqIdQ.deq();
      end
      else begin
         bufCnt <= bufCnt + 1;
      end
      
      let tag_fifo <- toGet(freeFifoIdQ).get();
      respQ.enq(tuple2(tag_req, tag_fifo));
      $display("%m reorderbuf do reserve bufs, bufCnt = %d, nBufs = %d", bufCnt, nBufs);
      $display("%m reorderbuf do reserve bufs, deqTag = %d, enqTag = %d", tag_req, tag_fifo);

      deqIds.enq(tag_req, tag_fifo);
   endrule
   
   FIFO#(Tuple2#(TagT, Bit#(8))) deqReqQ <- mkSizedFIFO(128);
   Reg#(Bit#(21)) deqByteCnt <- mkReg(0);
   rule doDeq;
      let v = deqReqQ.first();
      let tag_req = tpl_1(v);
      let bufMax = tpl_2(v);
      Bit#(21) byteMax = extend(bufMax) << 13;
      
      Bool doDeqId = (deqByteCnt%8192) == (8192 - 16);
      if ( deqByteCnt + 16 < byteMax ) begin
         deqByteCnt <= deqByteCnt + 16;
         //doDeqId = True;
      end
      else begin
         deqByteCnt <= 0;
         deqReqQ.deq();
         freeReqIdQ.enq(tag_req);
      end
      
      $display("%m reorderbuf do dequeue req for fifoids, deqTag = %d, deqByteCnt = %d, pageMax = %d, byteMax = %d, doDeqId = %d", tag_req, deqByteCnt, bufMax, byteMax, doDeqId);
      
      deqIds.deqServer.request.put(tuple2(tag_req, doDeqId));
   endrule
   
   Reg#(Bit#(9)) pageWordCnt <- mkReg(0);
   rule doDeq_1;
      let tag_fifo <- deqIds.deqServer.response.get();
      fifos.deqServer.request.put(tuple2(tag_fifo, True));
      pageWordCnt <= pageWordCnt + 1;
      if ( pageWordCnt + 1 == 0)
         freeFifoIdQ.enq(tag_fifo);
      $display("%m reorderbuf do dequeue req for fifodata, enqTag = %d, pageWordCnt = %d", tag_fifo, pageWordCnt);
   endrule
      
   interface Server reserveServer;
      interface Put request = toPut(reqQ);
      interface Get response = toGet(respQ);
   endinterface
      
   method Action inData(TagT tag, Bit#(128) data);
      fifos.enq(tag, data);
   endmethod
   
   method Action deqReq(TagT tag, Bit#(8) nBufs);
      deqReqQ.enq(tuple2(tag, nBufs));
   endmethod
      
   interface Get outPipe = fifos.deqServer.response;

endmodule
