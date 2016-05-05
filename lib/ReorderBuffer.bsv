import Cntrs::*;
import Vector::*;
import FIFOVector::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import ControllerTypes::*;
import Connectable::*;
import ClientServer::*;
import Cntrs::*;
import ParameterTypes::*;

typedef 64 FifoDepth;
 
Bit#(21) fifoBytes = fromInteger(valueOf(FifoDepth) * 16);

interface ReorderBurstBuffer;
   //method Action enqReq(TagT tag, Bit#(21) nBytes);
   method Action enqReq(TagT tag, Bit#(21) nBytes);
   method ActionValue#(void) enqResp();
   interface Put#(Tuple2#(Bit#(128), Bool)) inPipe;
   method Action deqReq(TagT tag, Bit#(21) nBytes);
   interface Get#(Tuple2#(Bit#(128), Bool)) outPipe;
endinterface

//(*synthesize*)
module mkReorderBurstBuffer(ReorderBurstBuffer);
   //FIFOVector#(128, Bit#(7), 128) sndQIds <- mkBRAMFIFOVectorSafe();
   FIFOVectorSimple#(128, Bit#(7), 128, void) sndQIds <- mkBRAMFIFOVector();
   //FIFOVector#(128, Tuple2#(Bit#(128),Bool), 16) fifos <- mkBRAMFIFOVector();
   FIFOVectorSimple#(128, Tuple2#(Bit#(128),Bool), FifoDepth, TagT) fifos <- mkBRAMFIFOVector();
   FIFO#(Bit#(7)) freeSndQId <- mkSizedFIFO(128);

   Reg#(Bit#(7)) initCnt <- mkReg(0);
   Reg#(Bool) initialized <- mkReg(False);
   
   FIFO#(Tuple2#(TagT, Bit#(21))) enqReqQ  <- mkSizedFIFO(numStages);
   Count#(Bit#(8)) freeQCnt <- mkCount(128);
   
   rule init if (!initialized);
      freeSndQId.enq(initCnt);
      initCnt <= initCnt + 1;
      if ( initCnt == -1 ) begin
         initialized <= True;
      end
   endrule
   
   FIFO#(void) enqRespQ <- mkFIFO();
 
   Reg#(Bit#(21)) byteCnt_wr <- mkReg(0);
   FIFO#(Tuple2#(Bit#(128), Bool)) inDtaQ <- mkFIFO();
   

   
   rule doEnqData if ( initialized);
      let d <- toGet(inDtaQ).get();

      let v = enqReqQ.first();
      let tag_req = tpl_1(v);
      let nBytes = tpl_2(v);
      
      if ( byteCnt_wr == 0 ) enqRespQ.enq(?);

      let tag_fifo = freeSndQId.first();
      //Bool fifoIdQ_en =  (byteCnt_wr%256 == 240);
      Bool fifoIdQ_en =  (byteCnt_wr%fifoBytes == (fifoBytes - 16));

      //if ( byteCnt_wr%256 == 0 )
      if ( byteCnt_wr%fifoBytes == 0 )
         sndQIds.enq(tag_req, tag_fifo); 
      
      fifos.enq(tag_fifo, d);
      
      if (byteCnt_wr + 16 >= nBytes) begin
         enqReqQ.deq();
         fifoIdQ_en = True;
         byteCnt_wr <= 0;
      end
      else begin
         byteCnt_wr <= byteCnt_wr + 16;
      end
      $display("%m, doEnqData, tag_req = %d, tag_fifo = %d, byteCnt_wr = %d, nBytes = %d, fifoIdQ_en = %d", tag_req, tag_fifo, byteCnt_wr, nBytes, fifoIdQ_en);
      
      if ( fifoIdQ_en) begin
         freeSndQId.deq;
         $display("deq freeSndId tag = %d", tag_fifo);
      end
   endrule
   
   
   Reg#(Bit#(21)) bufCnt <- mkReg(0);
   FIFO#(Tuple2#(TagT, Bit#(21))) deqReqQ <- mkFIFO;
   rule doDeqReq if (initialized);
      let v = deqReqQ.first();
      let tag = tpl_1(v);
      let nBytes = tpl_2(v);
      //let nBufs = nBytes/256;
      let nBufs = nBytes/fifoBytes;
      //if ( nBytes%256 != 0) nBufs = nBufs + 1;
      if ( nBytes%fifoBytes != 0) nBufs = nBufs + 1;
      $display("%m, doDeqReq, bufCnt = %d, nBufs = %d", bufCnt, nBufs);
      //sndQIds.deqServer.request.put(tuple2(tag, True));
      sndQIds.deqServer.request.put(tuple3(tag, True, tagged Invalid));
      if ( bufCnt + 1 < nBufs ) begin
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

      //Bool fifoIdQ_en = (byteCnt_rd%256 == 240);
      Bool fifoIdQ_en =  (byteCnt_rd%fifoBytes == (fifoBytes - 16));

      Maybe#(Bit#(7)) returnTag = tagged Invalid;
      
      if (byteCnt_rd +16 >= nBytes) begin
         deqBytesQ.deq();
         fifoIdQ_en = True;
         byteCnt_rd <= 0;
      end
      else begin
         byteCnt_rd <= byteCnt_rd + 16;
      end
      $display("%m, doDeqData, tag_fifo = %d, byteCnt_rd = %d, nBytes = %d, fifoIdQ_en = %d", tag_fifo, byteCnt_rd, nBytes, fifoIdQ_en);           
      if ( fifoIdQ_en) begin
         //freeIdQ.deq;
         fifoIdQ.deq();
         //freeSndQId.enq(tag_fifo);
         returnTag = tagged Valid tag_fifo;
      end
      
      //fifos.deqServer.request.put(tuple2(tag_fifo, True));
      fifos.deqServer.request.put(tuple3(tag_fifo, True, returnTag));
   endrule
   
   rule connectTag if (initialized);
      let tag_fifo <- fifos.deqResp.get();
      freeSndQId.enq(tag_fifo);
   endrule
   
   
   
   method Action enqReq(TagT tag, Bit#(21) nBytes);
      enqReqQ.enq(tuple2(tag, nBytes));
   endmethod
   method ActionValue#(void) enqResp();
      let retval <- toGet(enqRespQ).get();
      return retval;
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
   interface Get#(TagT) deqReady;
   method Action deqReq(TagT tag, Bit#(21) nBytes);
   interface Get#(Tuple2#(Bit#(128), Bool)) outPipe;
endinterface

//(*synthesize*)
module mkReorderBuffer(ReorderBuffer);
   // FIFOVector#(128, Bit#(7), 128) enqIds <- mkBRAMFIFOVector();
   // FIFOVector#(128, Bit#(7), 128) deqIds <- mkBRAMFIFOVector();
   // FIFOVector#(128, Bit#(7), 128) enqIds <- mkBRAMFIFOVectorSafe();
   // FIFOVector#(128, Bit#(7), 128) deqIds <- mkBRAMFIFOVectorSafe();
   FIFOVectorSimple#(128, Bit#(7), 128, void) enqIds <- mkBRAMFIFOVector();
   FIFOVectorSimple#(128, Bit#(7), 128, void) deqIds <- mkBRAMFIFOVector();


   
   //FIFOVector#(128, Tuple2#(Bit#(128),Bool), 16) fifos <- mkBRAMFIFOVector();
   //FIFOVector#(128, Tuple2#(Bit#(128),Bool), 16) fifos <- mkBRAMFIFOVectorSafe();
   //FIFOVectorSimple#(128, Tuple2#(Bit#(128), Bool), 16, Bit#(7)) fifos <- mkBRAMFIFOVector();
   FIFOVectorSimple#(128, Tuple2#(Bit#(128), Bool), FifoDepth, Bit#(7)) fifos <- mkBRAMFIFOVector();
   
   FIFO#(Bit#(7)) freeReqIdQ <- mkSizedFIFO(128);
   FIFO#(Bit#(7)) freeFifoIdQ <- mkSizedFIFO(128);

   Reg#(Bit#(7)) initCnt <- mkReg(0);
   Reg#(Bool) initialized <- mkReg(False);
   

   FIFO#(Bit#(21)) bufMaxQ  <- mkFIFO();
   
   Count#(Bit#(8)) emptyQs <- mkCount(128);
   
   //(* descending_urgency = "init, 

   rule init if (!initialized);
      freeReqIdQ.enq(initCnt);
      freeFifoIdQ.enq(initCnt);
      initCnt <= initCnt + 1;
      if ( initCnt == -1 ) begin
         initialized <= True;
      end
   endrule
   
   FIFO#(Tuple2#(Bit#(21),Bit#(21))) reqQ <- mkFIFO();
   FIFO#(TagT) respQ <- mkFIFO();
   
   Reg#(Bit#(21)) bufCnt <- mkReg(0);
   
      
   FIFO#(Tuple2#(Bit#(128), Bool)) inDtaQ <- mkSizedFIFO(4);
   Vector#(128, Reg#(Bit#(21))) inDtaByteCnt <- replicateM(mkReg(0)); 
   Vector#(128, FIFOF#(Bit#(21))) inDtaByteMax <- replicateM(mkFIFOF);
   
   Reg#(Bit#(21)) deqByteCnt <- mkReg(0);
   //FIFO#(Bit#(21)) deqMaxByteQ <- mkFIFO;
   FIFO#(TagT) deqReadyQ <- mkSizedFIFO(128);                 
   rule doReq if ( tpl_1(reqQ.first) - bufCnt <= extend(emptyQs) || extend(emptyQs) + bufCnt >= 128);
      let nBytes = tpl_2(reqQ.first);
      let nBufs = tpl_1(reqQ.first);
     
      let tag_req = freeReqIdQ.first;
      
      if ( bufCnt == 0 ) begin
      //if ( truncate(nBufs) >= emptyQs + extend(bufCnt) || nBufs - bufCnt
         $display("%m:: enqueuing resp tag_req = %d", tag_req);
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
      emptyQs.decr(1);
      
      let tag_fifo <- toGet(freeFifoIdQ).get();
      $display("%m:: reorderbuf, doReq bufCnt = %d, nBufs = %d, emptyQs = %d, tag_req= %d, tag_fifo = %d, nBytes = %d", bufCnt, nBufs, emptyQs, tag_req, tag_fifo, nBytes);
      enqIds.enq(tag_req, tag_fifo);
      deqIds.enq(tag_req, tag_fifo);
   endrule
   
   FIFO#(Tuple3#(TagT, Bit#(128), Bool)) inDataReqQ <- mkFIFO;
   
   for (Integer tag = 0; tag < 128; tag = tag + 1) begin
      rule doEnq_0 if ( tpl_1(inDataReqQ.first) == fromInteger(tag) && inDtaByteMax[tag].notEmpty() );
         let v = inDataReqQ.first;
         inDataReqQ.deq();
         let data_0 = tpl_2(v);
         let data_1 = tpl_3(v);

         //Bool doDeq = (inDtaByteCnt[tag]%256 == (256 - 16));
         
         if (inDtaByteCnt[tag] == 0) deqReadyQ.enq(fromInteger(tag));
            
         Bool doDeq = (inDtaByteCnt[tag]%fifoBytes == (fifoBytes - 16));
         if ( inDtaByteCnt[tag] + 16 >= inDtaByteMax[tag].first ) begin
            inDtaByteMax[tag].deq();
            inDtaByteCnt[tag] <= 0;
            doDeq = True;
         end
         else begin
            inDtaByteCnt[tag] <= inDtaByteCnt[tag] + 16;
            //enqIds.deqServer.request.put(tuple2(tag,False));
         end
         //inDtaQ.enq(data);
         $display("%m:: reorderbuf, inData tag = %d, inDtaByteCnt = %d, inDtaByteMax = %d, doDeq = %d", tag, inDtaByteCnt[tag], inDtaByteMax[tag].first, doDeq); 
         //enqIds.deqServer.request.put(tuple2(tag,doDeq));
         enqIds.deqServer.request.put(tuple3(fromInteger(tag),doDeq,tagged Invalid));
         inDtaQ.enq(tuple2(data_0,data_1));
      endrule
   end
   
   
   // rule doEnq_0;
   //    let v = inDataReqQ.first;
   //    let tag = tpl_1(v);
   //    let data_0 = tpl_2(v);
   //    let data_1 = tpl_3(v);
   //    if (inDtaByteMax[tag].notEmpty) begin
   //       inDataReqQ.deq();
   //       Bool doDeq = (inDtaByteCnt[tag]%256 == (256 - 16));

   //       if ( inDtaByteCnt[tag] + 16 >= inDtaByteMax[tag].first ) begin
   //          inDtaByteMax[tag].deq();
   //          inDtaByteCnt[tag] <= 0;
   //          doDeq = True;
   //       end
   //       else begin
   //          inDtaByteCnt[tag] <= inDtaByteCnt[tag] + 16;
   //          //enqIds.deqServer.request.put(tuple2(tag,False));
   //       end
   //       //inDtaQ.enq(data);
   //       $display("%m:: reorderbuf, inData tag = %d, inDtaByteCnt = %d, inDtaByteMax = %d, doDeq = %d", tag, inDtaByteCnt[tag], inDtaByteMax[tag].first, doDeq); 
   //       //enqIds.deqServer.request.put(tuple2(tag,doDeq));
   //       enqIds.deqServer.request.put(tuple3(tag,doDeq,tagged Invalid));
   //       inDtaQ.enq(tuple2(data_0,data_1));
   //    end
   // endrule
   
   rule doEnq;
      let data <- toGet(inDtaQ).get();
      let tag <- enqIds.deqServer.response.get();
      $display("%m:: reorderbuf, doEnq fifo tag = %d, data = %h", tag, tpl_1(data));
      fifos.enq(tag, data);
   endrule
   
   
   FIFO#(Tuple2#(TagT, Bit#(21))) deqReqQ <- mkFIFO();
   FIFO#(Bool) returnTags <- mkSizedFIFO(4);
   Reg#(Bit#(32)) reqCnt_doDeq <- mkReg(0);
   rule doDeq;
      let v = deqReqQ.first();
      let tag_req = tpl_1(v);
      let byteMax = tpl_2(v);
      
      //Bool doDeqId = (deqByteCnt%256) == (256 - 16);
      Bool doDeqId = (deqByteCnt%fifoBytes) == (fifoBytes - 16);
      if ( deqByteCnt + 16 < byteMax ) begin
         deqByteCnt <= deqByteCnt + 16;
      end
      else begin
         reqCnt_doDeq <= reqCnt_doDeq + 1;
         deqByteCnt <= 0;
         deqReqQ.deq();
         doDeqId = True;
         freeReqIdQ.enq(tag_req);
      end
      $display("%m:: doDeq, tag_req = %d, deqByteCnt = %d, byteMax = %d, doDeqId = %d, reqCnt = %d", tag_req, deqByteCnt, byteMax, doDeqId, reqCnt_doDeq);
      //deqIds.deqServer.request.put(tuple2(tag_req, doDeqId));
      deqIds.deqServer.request.put(tuple3(tag_req, doDeqId, tagged Invalid));
      returnTags.enq(doDeqId);
   endrule
   
   rule doDeq_1;
      let tag_fifo <- deqIds.deqServer.response.get();
      let returnTag <- toGet(returnTags).get();
      $display("%m:: doDeq_1, tag_fifo = %d, returnTag = %d", tag_fifo, returnTag);
      Maybe#(Bit#(7)) tag = tagged Invalid;
      
      if ( returnTag ) begin
         // freeFifoIdQ.enq(tag_fifo);
         // emptyQs.incr(1);
         //$display("%m:: deDeq emptyQs = %d", emptyQs);
         tag = tagged Valid tag_fifo;
      end
      fifos.deqServer.request.put(tuple3(tag_fifo, True, tag));
   endrule
   
   rule doConn;
      let tag_fifo <- fifos.deqResp.get();
      freeFifoIdQ.enq(tag_fifo);
      emptyQs.incr(1);
   endrule
   
   Reg#(Bit#(32)) reqCnt_deqReq <- mkReg(0);
   interface Server reserveServer;
      interface Put request;// = toPut(reqQ);
         method Action put(Bit#(21) nBytes);
            //let nBufs = nBytes/256;
            let nBufs = nBytes/fifoBytes;
            //if ( nBytes%256 != 0)
            if ( nBytes%fifoBytes != 0)
               nBufs = nBufs + 1;
            reqQ.enq(tuple2(nBufs, nBytes));
            //reqQ.enq(nBufs);
         endmethod
      endinterface

      interface Get response = toGet(respQ);
   endinterface
   
   method Action inData(TagT tag, Tuple2#(Bit#(128), Bool) data);
      inDataReqQ.enq(tuple3(tag,tpl_1(data),tpl_2(data)));
   endmethod
   
   interface Get deqReady = toGet(deqReadyQ);
   
   method Action deqReq(TagT tag, Bit#(21) nBytes);
      reqCnt_deqReq <= reqCnt_deqReq + 1;
      $display("%m:: deqRequest, tag = %d, nBytes = %d, reqCnt = %d", tag, nBytes, reqCnt_deqReq);
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

//(*synthesize*)
module mkReorderBuffer_Flash(ReorderBuffer_Flash);
   
   // FIFOVector#(128, Bit#(6), 64) deqIds <- mkBRAMFIFOVector();
   // FIFOVector#(64, Bit#(128), 512) fifos <- mkBRAMFIFOVector();
   
   FIFOVectorSimple#(128, Bit#(6), 64, void) deqIds <- mkBRAMFIFOVector();
   FIFOVectorSimple#(64, Bit#(128), 512, Bit#(6)) fifos <- mkBRAMFIFOVector();
   
   
   // FIFOVector#(128, Bit#(6), 64) deqIds <- mkBRAMFIFOVectorSafe();   
   // FIFOVector#(64, Bit#(128), 512) fifos <- mkBRAMFIFOVectorSafe();
   // FIFOVector#(128, Bit#(7), 128) deqIds <- mkBRAMFIFOVector();
   
   // FIFOVector#(128, Bit#(128), 512) fifos <- mkBRAMFIFOVector();

   
   FIFO#(Bit#(7)) freeReqIdQ <- mkSizedFIFO(128);


   Reg#(Bit#(7)) initCnt <- mkReg(0);
   Reg#(Bool) initialized <- mkReg(False);
   

   FIFO#(Bit#(8)) bufMaxQ  <- mkFIFO();

   rule init if (!initialized);
      freeReqIdQ.enq(initCnt);
      initCnt <= initCnt + 1;
      if ( initCnt == -1 ) begin
         initialized <= True;
      end
   endrule


   Count#(Bit#(7)) emptyQs <- mkCount(64);
   
   Reg#(Bool) initialized_1 <- mkReg(False);
   Reg#(Bit#(6)) initCnt_1 <- mkReg(0);   
   FIFO#(Bit#(6)) freeFifoIdQ <- mkSizedFIFO(64);
   // Reg#(Bit#(7)) initCnt_1 <- mkReg(0);   
   // FIFO#(Bit#(7)) freeFifoIdQ <- mkSizedFIFO(64);

   
   rule init_1 if (!initialized_1);
      freeFifoIdQ.enq(initCnt_1);
      initCnt_1 <= initCnt_1 + 1;
      if ( initCnt_1 == -1 ) begin
         initialized_1 <= True;
      end
   endrule

   
   
   FIFO#(Bit#(8)) reqQ <- mkFIFO();
   FIFO#(Tuple2#(TagT, TagT)) respQ <- mkFIFO();
   
   Reg#(Bit#(8)) bufCnt <- mkReg(0);

   FIFO#(Tuple2#(TagT,Bit#(128))) inDtaQ <- mkFIFO();
                 
   rule doReq if ( reqQ.first - bufCnt <= extend(emptyQs) || extend(emptyQs) + bufCnt >= 64);

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
      emptyQs.decr(1);
      respQ.enq(tuple2(tag_req, extend(tag_fifo)));
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
      
      //deqIds.deqServer.request.put(tuple2(tag_req, doDeqId));
      deqIds.deqServer.request.put(tuple3(tag_req, doDeqId, tagged Invalid));
   endrule
   
   Reg#(Bit#(9)) pageWordCnt <- mkReg(0);
   rule doDeq_1;
      let tag_fifo <- deqIds.deqServer.response.get();
      Maybe#(Bit#(6)) tag = tagged Invalid;
      pageWordCnt <= pageWordCnt + 1;
      if ( pageWordCnt + 1 == 0) begin
         // freeFifoIdQ.enq(tag_fifo);
         // emptyQs.incr(1);
         tag = tagged Valid tag_fifo;
      end
      $display("%m reorderbuf do dequeue req for fifodata, enqTag = %d, pageWordCnt = %d", tag_fifo, pageWordCnt);
      //fifos.deqServer.request.put(tuple2(tag_fifo, True));
      fifos.deqServer.request.put(tuple3(tag_fifo, True, tag));
   endrule
   
   rule doConn;
      let tag_fifo <- fifos.deqResp.get();
      freeFifoIdQ.enq(tag_fifo);
      emptyQs.incr(1);
   endrule
         
   interface Server reserveServer;
      interface Put request = toPut(reqQ);
      interface Get response = toGet(respQ);
   endinterface
      
   method Action inData(TagT tag, Bit#(128) data);
      fifos.enq(truncate(tag), data);
   endmethod
   
   method Action deqReq(TagT tag, Bit#(8) nBufs);
      deqReqQ.enq(tuple2(tag, nBufs));
   endmethod
      
   interface Get outPipe = fifos.deqServer.response;

endmodule
