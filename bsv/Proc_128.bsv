import FIFO::*;
import FIFOF::*;
import BRAMFIFO::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;
import Cntrs::*;
import MyArbiter::*;

import MemTypes::*;
//import MemreadEngine::*;
//import MemwriteEngine::*;
import ControllerTypes::*;
import TagAlloc::*;

import DMAHelper::*;

import MemcachedTypes::*;
import HashtableTypes::*;
import ValuestrCommon::*;
import ValFlashCtrlTypes::*;

import ProtocolHeader::*;

import FlashServer::*;

import DRAMCommon::*;
import DRAMArbiter::*;
import DRAMSegment::*;
import DRAMController::*;
import Time::*;

import RequestParser::*;
import JenkinsHash::*;
import Hashtable::*;
import KVStoreCompletionBuffer::*;
import FlashValueStore::*;
import KeyValueSplitter::*;
import ResponseFormatter::*;

import HostFIFO::*;

import ParameterTypes::*;

//interface ProcIfc;
//   interface Put request;
`ifdef DRAMSize
Integer dramSize = `DRAMSize;
`else
Integer dramSize = valueOf(TExp#(30));
`endif


import DMAHelper::*;
import ProcTypes::*;

interface MemServerIfc;
   interface Put#(Bit#(128)) request;// = toPut(reqs);
   interface Get#(Bit#(128)) response;// = toGet(resps);
endinterface

         

interface MemCachedIfc;
   interface MemServerIfc server;
   interface Get#(Bool) initDone;
   interface Get#(Bit#(32)) rdDone;
   interface Get#(Bit#(32)) wrDone;
   interface Client#(MemengineCmd,Bool) dmaReadClient;
   interface Client#(MemengineCmd,Bool) dmaWriteClient;
   method Action initDMARefs(Bit#(32) rp, Bit#(32) wp);
   method Action startRead(Bit#(32) rp, Bit#(32) numBytes);
   method Action reset();
   method Action freeWriteBufId(Bit#(32) wp);
   method Action initDMABufSz(Bit#(32) bufSz);
   interface HashtableInitIfc htableInit;
   interface DRAMClient dramClient;
   interface FlashRawWriteClient flashRawWrClient;
   interface FlashRawReadClient flashRawRdClient;
   interface TagClient tagClient;
endinterface

(*synthesize*)
module mkMemCached(MemCachedIfc);
   Reg#(Bit#(32)) dmaBufSz <- mkRegU();
   FIFO#(Bit#(32)) readBaseQ <- mkSizedFIFO(128);
   Reg#(Bit#(32)) rdPtr <- mkRegU();
   Reg#(Bit#(32)) wrPtr <- mkRegU();
   let re <- mkDMAReader;
   let we <- mkDMAWriter;
   
   let reqParser <- mkMemReqParser;
   let hash_idx <- mkJenkinsHash_128();
   let htable <- mkAssocHashtb;
   let cmplBuf <- mkKVStoreCompletionBuffer;
   let flashstr <- mkFlashValueStore();
   let kvSplit <- mkKeyValueSplitter;
   let respformat <- mkResponseFormatter;
   DRAMSegmentIfc#(2) dramSeg <- mkDRAMSegments;

   mkConnection(htable.dramClient, dramSeg.dramServers[0]);
   mkConnection(flashstr.dramClient, dramSeg.dramServers[1]);
      
   // rule doInit;
   //    let v <- htable.init.initialized;
   //    initDoneQ.enq(v);
   // endrule
   Integer dramSz = valueOf(TExp#(30));
   Integer writeBufSz = valueOf(TMul#(2,TExp#(20)));
   Integer htableSz = (dramSz - writeBufSz);
   Reg#(Bool) initFlag <- mkReg(False);
   rule init if (!initFlag);
      dramSeg.initializers[0].put(fromInteger(htableSz));
      dramSeg.initializers[1].put(fromInteger(writeBufSz));
      initFlag <= True;
   endrule
 

   FIFO#(Protocol_Binary_Request_Header) hash2table <- mkSizedFIFO(numStages);
   FIFO#(Tuple2#(Protocol_Binary_Request_Header, TagT)) table2valstr <- mkSizedFIFO(numStages);
   
   Reg#(Bit#(32)) reqCnt_doHash <- mkReg(0);
   
   FIFO#(Bit#(16)) keylenQ <- mkSizedFIFO(numStages);
   
   Count#(Bit#(8)) inFlightCmds <- mkCount(0);
   
   Reg#(Bool) stall <- mkReg(False);
   
   let tagServer <- mkTagAlloc;
   
   //Reg#(Bit#(32)) numReqs <- mkReg(0);
   Reg#(Bit#(32)) numResps <- mkReg(0);
   rule doHash;
      if ( !stall) begin
         reqCnt_doHash <= reqCnt_doHash + 1;
         let cmd <- reqParser.reqHeader.get();
         $display("Received Header, reqCnt = %d, opcode = %d, keylen = %d, bodylen = %d, opaque = %d", reqCnt_doHash, cmd.opcode, cmd.keylen, cmd.bodylen, cmd.opaque);
         tagServer.reqTag.request.put(1);
         if ( cmd.opcode != PROTOCOL_BINARY_CMD_EOM) begin
            let keylen = cmd.keylen;
            hash_idx.start(extend(keylen));
            //hash_val.start(extend(keylen));
            keylenQ.enq(keylen);
            //inFlightCmds.incr(1);
         end
         else begin
            stall <= True;
         end
         hash2table.enq(cmd);
         inFlightCmds.incr(1);
         //numReqs <= numReqs + 1;
      end
      else begin
         if (inFlightCmds == 0 ) begin
            stall <= False;
         end
      end
   endrule
   
   
   //FIFO#(Tuple2#(Bit#(128), Bool)) keyValFifo <- mkSizedFIFO(256/16);
   FIFO#(Tuple2#(Bit#(128), Bool)) keyValFifo <- mkSizedBRAMFIFO(128);
     
   mkConnection(toPut(keyValFifo), reqParser.keyValPipe);
   
   Reg#(Bit#(16))  keyCnt <- mkReg(0);
   FIFO#(Bit#(32)) firstKeyTokenQ <- mkSizedFIFO(numStages);
   rule connectKeyPipe;
      let v <- reqParser.keyPipe.get();
      hash_idx.inPipe.put(v);
      
      if ( keyCnt == 0)
         firstKeyTokenQ.enq(truncate(v));
      
      if ( keyCnt + 16 >= keylenQ.first ) begin
         keyCnt <= 0;
         keylenQ.deq();
      end
      else begin
         keyCnt <= keyCnt + 16;
      end
      
   endrule
   
   FIFO#(TagT) nextTagQ <- mkSizedFIFO(numStages);
   mkConnection(toPut(nextTagQ), tagServer.reqTag.response);
   
   rule doTable;
      let cmd <- toGet(hash2table).get();
      let reqId <- toGet(nextTagQ).get();
      table2valstr.enq(tuple2(cmd, reqId));
      
      if ( cmd.opcode != PROTOCOL_BINARY_CMD_EOM) begin
         let keylen = cmd.keylen;
         let vallen = cmd.bodylen - extend(cmd.keylen);
         Bit#(32) hv_idx <- hash_idx.response.get();
         Bit#(32) hv_val <- toGet(firstKeyTokenQ).get();
                  
         $display("Memcached Calc hash_idx = %h, hash_val = %h, opaque = %d", hv_idx, hv_val, cmd.opaque);
      
         // Bool rnw = ?;
         // if ( cmd.opcode == PROTOCOL_BINARY_CMD_SET)
         //    rnw = False;
         // else
         //    rnw = True;
         
         htable.server.request.put(HashtableReqT{hv: truncate(hv_idx),
                                                 hvKey: truncate(hv_val),
                                                 key_size: truncate(keylen),
                                                 value_size: truncate(vallen),
                                                 opcode: cmd.opcode,
                                                 reqId: reqId});
      end
   endrule
   
   
   
   
      
      
   FIFO#(Tuple2#(Bool, Bit#(32))) deqKVReqQ <- mkSizedFIFO(numStages);
   
   FIFOF#(Tuple2#(Protocol_Binary_Response_Header,TagT)) inOrderResp <- mkSizedFIFOF(numStages);
   FIFOF#(Tuple2#(Protocol_Binary_Response_Header,TagT)) outOrderResp <- mkFIFOF();
   
   
   Reg#(Bit#(16)) reqCnt <- mkReg(0);
   rule doVal;
      let d <- toGet(table2valstr).get();
      let cmd = tpl_1(d);
      let reqId = tpl_2(d);
      
      let respHdr = Protocol_Binary_Response_Header{magic: PROTOCOL_BINARY_RES,
                                                    opcode: cmd.opcode,
                                                    keylen: 0,
                                                    extlen: 0,
                                                    datatype: 0,
                                                    status: ?,
                                                    bodylen: 0,
                                                    opaque: cmd.opaque,
                                                    cas: 0
                                                    };
      
      Bool checkKeys = False;
      
      if ( cmd.opcode != PROTOCOL_BINARY_CMD_EOM) begin
         
      
         let opcode = cmd.opcode;
         let v <- htable.server.response.get();
      
         let status = v.status;
         // let addr = v.value_addr;
         let nBytes = v.value_size;
         // let doEvict = v.doEvict;
         // let hv = v.hv;
         // let idx = v.idx;
         // let old_hv = v.old_hv;
         // let old_nBytes = v.old_nBytes;
         
         //$display("doVal: opcode = %h, addr = %d, nBytes = %d, reqId = %d, opaque = %d", opcode, addr.onFlash, addr.valAddr, nBytes, reqId, cmd.opaque);
         

         respHdr.bodylen = extend(nBytes);
         respHdr.status = status;
        
                  
         reqCnt <= reqCnt + 1;
         if (status == PROTOCOL_BINARY_RESPONSE_SUCCESS ) begin
            if (opcode == PROTOCOL_BINARY_CMD_GET) begin
               $display("doVal: Get Cmd, opaque = %d, reqCnt = %d", cmd.opaque, reqCnt);
               //valuestr.readUser.request.put(ValstrReadReqT{addr:addr, nBytes: nBytes, reqId: reqId});
               //kvSplit.server.request.put(tuple2(truncate(cmd.keylen), extend(nBytes)));
               cmplBuf.writeRequest.put(tuple3(truncate(cmd.keylen), cmd.opaque, reqId));
               checkKeys = True;
            end
            else if (opcode == PROTOCOL_BINARY_CMD_SET) begin
               $display("doVal: Set Cmd, opaque = %d, reqCnt = %d", cmd.opaque, reqCnt);
               // valuestr.writeUser.writeServer.request.put(ValstrWriteReqT{addr:extend(pack(addr.valAddr)),
               //                                                            nBytes: nBytes,
               //                                                            hv: hv,
               //                                                            idx: idx,
               //                                                            doEvict: doEvict,
               //                                                            old_hv: old_hv,
               //                                                            old_nBytes: old_nBytes,
               //                                                            reqId: reqId});
               respHdr.bodylen = 0;
            end 
            else if (opcode == PROTOCOL_BINARY_CMD_DELETE)  begin
               $display("doVal: Delete Cmd, reqCnt = %d", reqCnt);
               respHdr.bodylen = 0;
            end
            
         end
         else begin
            $display("Hashtable access failure");
            respHdr.bodylen = 0;
         end
         
         deqKVReqQ.enq(tuple2(status == PROTOCOL_BINARY_RESPONSE_SUCCESS && opcode != PROTOCOL_BINARY_CMD_DELETE, cmd.bodylen));
      end
      
      if ( !checkKeys )
         inOrderResp.enq(tuple2(respHdr, reqId));
      //value2kvSplit.enq(tuple2(respHdr, checkKeys));
      
   endrule
   
   rule doConnectFlash;
      let cmd <- htable.flashClient.request.get();
      if ( cmd.rnw ) begin
         flashstr.readServer.readServer.request.put(FlashReadReqT{addr: cmd.addr, numBytes: cmd.numBytes, reqId: cmd.reqId});
      end
      else begin
         flashstr.writeServer.writeServer.request.put(cmd.numBytes);
      end
   endrule
   
   mkConnection(flashstr.writeServer.writeServer.response, htable.flashClient.response);
   
   Reg#(Bit#(32)) byteCnt <- mkReg(0);
   rule deqKV;
      let v = deqKVReqQ.first();
      let bodylen = tpl_2(v);
      if ( byteCnt + 16 < bodylen) begin
         byteCnt <= byteCnt + 16;
      end
      else begin
         byteCnt <= 0;
         deqKVReqQ.deq();
      end
         
      let d <- toGet(keyValFifo).get();
      if (tpl_1(v)) begin
         if (!tpl_2(d)) begin
            //valuestr.writeUser.writeWord.put(tpl_1(d));
            flashstr.writeServer.writeWord.put(tpl_1(d));
         end
         else begin
            cmplBuf.inPipe.put(tpl_1(d));
         end
      end
   endrule
   
   FIFO#(Tuple2#(ValSizeT,TagT)) nextValSize <- mkFIFO();
   rule readCmplBuf;
      let v <- flashstr.readServer.burstSz.get();
      let nBytes = tpl_1(v);
      let reqId = tpl_2(v);
      //cmplBuf.readRequest.put(reqId);
      cmplBuf.readRequest.put(tuple2(reqId, False));
      nextValSize.enq(tuple2(nBytes, reqId));
   endrule
   
   FIFO#(Tuple2#(Protocol_Binary_Response_Header, TagT)) pendingResp <- mkSizedFIFO(numStages);
   rule reqkeyCmp;
      let v <- cmplBuf.readResponse.get();
      let keylen = tpl_1(v);
      let opaque = tpl_2(v);
      let d <- toGet(nextValSize).get();
      let bodylen = tpl_1(d);
      let reqId = tpl_2(d);
      kvSplit.server.request.put(tuple2(keylen, extend(bodylen)));
      pendingResp.enq(tuple2(Protocol_Binary_Response_Header{magic: PROTOCOL_BINARY_RES,
                                                             opcode: PROTOCOL_BINARY_CMD_GET,
                                                             keylen: 0,
                                                             extlen: 0,
                                                             datatype: 0,
                                                             status: PROTOCOL_BINARY_RESPONSE_SUCCESS,
                                                             bodylen: extend(bodylen) - extend(keylen),
                                                             opaque: opaque,
                                                             cas: 0
                                                             }, reqId));
   endrule
   
   rule dokvConn;
      let d <- flashstr.readServer.readServer.response.get();
      kvSplit.keyValInPipe.put(tpl_1(d));
   endrule
   
   mkConnection(kvSplit.keyInPipe, cmplBuf.outPipe);
   
   rule doCheckKeys;
      let v <- toGet(pendingResp).get();
      let hdr = tpl_1(v);
      let reqId = tpl_2(v);
      let d <- kvSplit.server.response.get();
      if ( !d ) begin
         hdr.status = PROTOCOL_BINARY_RESPONSE_NOT_STORED;
         hdr.bodylen = 0;
      end
      //end
      outOrderResp.enq(tuple2(hdr, reqId));
   endrule
   
   Vector#(2, FIFOF#(Tuple2#(Protocol_Binary_Response_Header, TagT))) respQs;
   respQs[0] = inOrderResp;
   respQs[1] = outOrderResp;
   
   Arbiter_IFC#(2) arbiter <- mkArbiter(False);

   for (Integer i = 0; i < 2; i = i + 1) begin
      if (i == 0 ) begin
         rule doReqs_0 if (tpl_1(respQs[0].first).opcode != PROTOCOL_BINARY_CMD_EOM || inFlightCmds == 1 );
            arbiter.clients[0].request;
         endrule
      end
      else begin
         rule doReqs_1 if (respQs[1].notEmpty );
            arbiter.clients[1].request;
         endrule
      end
      
      rule doResp if ( arbiter.grant_id == fromInteger(i));
         numResps <= numResps + 1;
         let v <- toGet(respQs[i]).get();
         let hdr = tpl_1(v);
         let reqId = tpl_2(v);
         respformat.hdrPipe.put(hdr);
         inFlightCmds.decr(1);
         tagServer.retTag.put(reqId);
         $display("Bluecache Pipeline responses from %d, respNum = %d, opaque = %d",i, numResps, hdr.opaque);
      endrule
   end
   
   mkConnection(kvSplit.outPipe, respformat.inPipe);
  
   
   FIFO#(Bit#(128)) outputQ <- mkFIFO;
   
   Reg#(Bit#(32)) byteCnt_dma <- mkReg(0);
   Reg#(Bit#(32)) burstCnt <- mkReg(0);
   FIFOF#(Bit#(32)) burstMaxQ <- mkFIFOF();
   
   FIFOF#(Bit#(32)) writeBaseQ <- mkSizedFIFOF(128);
   
   FIFO#(Bit#(32)) wrDoneQ <- mkSizedFIFO(128);
  
   Reg#(Bool) zeroPad <- mkReg(False);
   Reg#(Bit#(32)) padCnt <- mkReg(0);
   
   rule doDMAWrite;
      if (zeroPad) begin
         if ( padCnt + 16 == dmaBufSz ) begin
            zeroPad <= False;
            padCnt <= 0;
         end
         else begin
            padCnt <= padCnt + 16;
         end
         $display("doDMAWritePad, padCnt = %d",padCnt);
         outputQ.enq(0);
      end
      else begin
         let d <- respformat.outPipe.get();
         $display("doDMAWrite, byteCnt_dma = %d",byteCnt_dma);
         $display(fshow(d));
         outputQ.enq(tpl_1(d));
         if ( byteCnt_dma == 0 ) begin
            let base <-toGet(writeBaseQ).get();
            we.server.request.put(tuple3(wrPtr, base, extend(dmaBufSz)));
            wrDoneQ.enq(base);
         end
         
         if (tpl_2(d)) begin
            if ( byteCnt_dma + 16 < dmaBufSz ) begin
               zeroPad <= True;
               padCnt <= byteCnt_dma + 16;
            end
            byteCnt_dma <= 0;
         end
          else begin
            if ( byteCnt_dma + 16 == dmaBufSz ) begin
               byteCnt_dma <= 0;
            end
            else begin
               byteCnt_dma <= byteCnt_dma + 16;
            end
         end
      end
   endrule

   
   
   interface MemServerIfc server;
      interface Put request = reqParser.inPipe;
      interface Get response = toGet(outputQ);
   endinterface
    
   interface Get rdDone;
      method ActionValue#(Bit#(32)) get;
         let dummy <- re.server.response.get();
         let bufId <- toGet(readBaseQ).get();
         return bufId;
      endmethod
   endinterface
   
   interface Get wrDone;
      method ActionValue#(Bit#(32)) get;
         let dummy <- we.server.response.get();
         let bufId <- toGet(wrDoneQ).get();
         return bufId;
      endmethod
   endinterface
   
   method Action initDMARefs(Bit#(32) rp, Bit#(32) wp);
      rdPtr <= rp;
      wrPtr <= wp;
   endmethod
      
   method Action startRead(Bit#(32) readBase, Bit#(32) numBytes);
      re.server.request.put(tuple3(rdPtr,readBase, extend(numBytes)));
      readBaseQ.enq(readBase);
   endmethod

   method Action reset();
      writeBaseQ.clear();
   endmethod
      
   method Action freeWriteBufId(Bit#(32) writeBase);
      writeBaseQ.enq(writeBase);
   endmethod
   
   method Action initDMABufSz(Bit#(32) bufSz);
      dmaBufSz <= bufSz;
   endmethod
                    
   
   interface Client dmaReadClient = re.dmaClient;
   interface Client dmaWriteClient = we.dmaClient;
      
   interface HashtableInitIfc htableInit = htable.init;
   interface DRAMClient dramClient = dramSeg.dramClient;
   interface FlashRawWriteClient flashRawWrClient = flashstr.flashRawWrClient;
   interface FlashRawReadClient flashRawRdClient = flashstr.flashRawRdClient;
   interface TagClient tagClient = flashstr.tagClient;
endmodule
