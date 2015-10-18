import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import GetPut::*;
import Vector::*;
import ClientServer::*;
import ClientServerHelper::*;

import MemcachedTypes::*;
import ParameterTypes::*;
import DRAMCommon::*;
import HashtableTypes::*;
import ValFlashCtrlTypes::*;
import Time::*;
import ValuestrCommon::*;

import ProtocolHeader::*;

import Fifo::*;
import CAM::*;

interface HeaderWriterIfc;
   interface Put#(HdrWrReqT) request;
   interface Get#(HashtableRespType) response;
   interface Get#(DRAMReq) dramClient;
   interface ValAllocClient valAllocClient;   
   
   interface Put#(HeaderUpdateReqT) hdrUpdateRequest;
   interface Client#(DRAMReq, Bool) hdrUpdDRAMClient;

endinterface


//(*synthesize*)
module mkHeaderWriter#(SFifo#(NUM_STAGES, HashValueT, HashValueT) sFifo)(HeaderWriterIfc);
   FIFO#(HashtableRespType) respQ <- mkSizedFIFO(numStages);
   FIFO#(ItemHeader) newHeaderQ <- mkFIFO;
   
   FIFO#(ValAllocReqT) valReqQ <- mkFIFO();
   FIFO#(ValAllocRespT) valRespQ <- mkFIFO();

   
   FIFO#(HeaderWriterPipeT) stageQ_0 <- mkSizedFIFO(numStages);
   FIFO#(Bit#(32)) hv_idxQ <- mkSizedFIFO(numStages);
   FIFO#(HeaderWriterPipeT) stageQ_1 <- mkFIFO;
   FIFO#(HeaderWriterPipeT) immediateQ <- mkFIFO;
   
   FIFO#(HeaderUpdateReqT) hdrUpdQ <- mkFIFO();
 
   FIFO#(Tuple3#(Bit#(64), Bit#(2), FlashAddrType)) flashReqQ <- mkFIFO;
   
   Vector#(2, FIFO#(DRAMReq)) dramReqQs <- replicateM(mkFIFO());
   FIFO#(Bool) dramRespQ <- mkFIFO();
   
   FIFO#(Bit#(32)) evictDramQ <- mkSizedFIFO(numStages);
   SFifo#(NUM_STAGES, Bit#(32), Bit#(32)) outstandingHdrUpdQ <- mkCFSFifo(eq);
   
   //CAM#(NUM_STAGES, HashValueT, Tuple2#(Bit#(2),FlashAddrType)) cam <- mkNonBlkCAM();
   CAM#(NUM_STAGES, HashValueT, Tuple2#(Bit#(2),FlashAddrType)) cam <- mkSnapCAM();
   rule doHdrUpdReq;
      let v <- toGet(hdrUpdQ).get();
      let hv = v.hv;
      let idx = v.idx;
      let wrAddr = (extend(hv) << 6) + (zeroExtend(idx) << valueOf(LgLineBytes));
      if ( sFifo.search(hv) ) begin
         cam.writePort.put(tuple2(hv, tuple2(idx,v.flashAddr)));
      end
      $display("Update Header of Evicted Value, hv = %h, idx = %d, new_addr = %d", hv, idx, v.flashAddr);
      dramReqQs[1].enq(DRAMReq{rnw:False, addr: wrAddr, data:extend(pack(ValAddrT{onFlash:True, valAddr: extend(pack(v.flashAddr))})), numBytes:fromInteger(valueOf(TDiv#(SizeOf#(ValAddrT), 8)))});
   endrule
   
   rule doHdrUpdResp;
      let v <- toGet(dramRespQ).get();
      outstandingHdrUpdQ.deq();
   endrule
   
   Reg#(Bit#(TLog#(NUM_STAGES))) evictCnt <- mkReg(0);
   
   rule prepWrite_1 if (!outstandingHdrUpdQ.search(hv_idxQ.first));
      $display("HeaderWriter:: Get ValAlloc Resp");
      //$display(
      let v <- toGet(stageQ_0).get();
      hv_idxQ.deq();

      let newValue = v.newValue;
      //let retval = v.retval;
      //let args = v.args;
              
      if ( newValue ) begin
         // handle write req
         let resp <- toGet(valRespQ).get();
         let valAddr = ValAddrT{onFlash:False, valAddr: zeroExtend(resp.newAddr)};
         v.newhdr.valAddr = valAddr;
                              
         //$display("valAddFifo.enq, addr = %d, nBytes = %d, hit = %b", resp.newAddr, args.nBytes, True);
         v.retval.value_size = extend(v.key_size) + extend(v.value_size);
         v.retval.value_addr = valAddr;
         v.retval.old_nBytes = truncate(resp.oldNBytes);
         v.retval.doEvict = resp.doEvict;
         v.retval.old_hv = resp.hv;
         v.retval.old_idx = resp.idx;
         //valAddrFifo.enq(retval);
         if ( resp.doEvict ) begin
            outstandingHdrUpdQ.enq({resp.hv, resp.idx});
         end
      end
      else begin
         // handle read req
         cam.readPort.request.put(v.hv);
         //newHeaderQ.enq(newhdr);
      end
      //sFifo.deq();
      stageQ_1.enq(v);
   endrule
   
   rule doOutput;
      sFifo.deq();
      $display("HeaderWriter:: Generate Output");
      let args <- toGet(stageQ_1).get();
      let ret = args.retval;
      let idx = args.idx;
      let newValue = args.newValue;
      if ( !newValue ) begin
         let readv <- cam.readPort.response.get();
         if ( isValid(readv) ) begin
            let v = fromMaybe(?, readv);
            if ( tpl_1(v) == idx ) begin
               let addr = ValAddrT{onFlash: True, valAddr: extend(pack(tpl_2(v)))};
               ret.value_addr = addr;
               args.newhdr.valAddr = addr;
            end
         end
      end
      newHeaderQ.enq(args.newhdr);
      respQ.enq(ret);
      immediateQ.enq(args);
   endrule



   
   rule writeHeader;
      let newHeader <- toGet(newHeaderQ).get();
      let wrVal = pack(newHeader);
      let v <- toGet(immediateQ).get();
      
      Bit#(64) wrAddr = (extend(v.hv) << 6) + (extend(v.idx) << fromInteger(valueOf(LgLineBytes)));
      
      if ( v.doWrite ) begin
         Bit#(7) numOfBytes = fromInteger(valueOf(LineBytes));
         $display("HeaderWriter wrAddr = %d, wrVal = %h, bytes = %d", wrAddr, wrVal, numOfBytes);
         dramReqQs[0].enq(DRAMReq{rnw: False, addr:wrAddr, data:zeroExtend(wrVal), numBytes:numOfBytes});
      end
      else begin
         dramReqQs[0].enq(DRAMReq{rnw: False, addr:wrAddr, data:zeroExtend(wrVal), numBytes:0});
      end
      
   endrule
   Reg#(Bit#(16)) reqCnt <- mkReg(0);
   
   interface Put request;
      method Action put(HdrWrReqT args);
        
         let old_header = args.oldHeaders;
         let cmpMask = args.cmpMask;
         let idleMask = args.idleMask;
   
         $display("(%t) HeaderWriter: cmpMask = %b, idleMask = %b, doWrite = %b, numBytes = %d, reqCnt = %d",$time,  cmpMask, idleMask, args.opcode, args.value_size, reqCnt);
   

         Bit#(TLog#(NumWays)) ind = ?;
 
         Bool doWrite = True;
   
         HashtableRespType retval = ?;
         ItemHeader newhdr = ItemHeader{hvKey: args.hvKey,
                                        keylen: args.key_size,
                                        currtime : args.time_now,
                                        valAddr: ?, 
                                        nBytes : truncate(args.value_size)
                                        };
         Bool newVal = False;
   

         reqCnt <= reqCnt + 1;
         if ( cmpMask != 0 ) begin
            // update the timestamp in the header;
            ind = mask2ind(cmpMask);
         
            old_header[ind].currtime = args.time_now;
                           
                     
            newhdr = old_header[ind];
            
            if ( args.opcode == PROTOCOL_BINARY_CMD_GET ) begin
               $display("Read Success");
               retval.status = PROTOCOL_BINARY_RESPONSE_SUCCESS;
            end
            else if ( args.opcode == PROTOCOL_BINARY_CMD_SET) begin
               $display("Write Fail");
               retval.status = PROTOCOL_BINARY_RESPONSE_KEY_EEXISTS;
               doWrite = False;
            end
            else if ( args.opcode == PROTOCOL_BINARY_CMD_DELETE ) begin
               $display("Delete Success");
               retval.status = PROTOCOL_BINARY_RESPONSE_SUCCESS;
               newhdr.keylen = 0;
               valReqQ.enq(ValAllocReqT{nBytes: extend(args.value_size) + extend(args.key_size),
                                        oldAddr: truncate(old_header[ind].valAddr.valAddr),
                                        oldNBytes: extend(old_header[ind].nBytes) + extend(old_header[ind].keylen),
                                        //trade_in: trade_in});
                                        rtn_old: True,
                                        req_new: False});
               newVal = True;

            end
         
         end
         else begin
            if ( args.opcode == PROTOCOL_BINARY_CMD_GET ) begin
               $display("Read fail");
               retval.status = PROTOCOL_BINARY_RESPONSE_NOT_STORED;
               doWrite = False;
            end
            else if ( args.opcode == PROTOCOL_BINARY_CMD_SET ) begin
               retval.status = PROTOCOL_BINARY_RESPONSE_SUCCESS;
               Bool trade_in = False;
               
               if ( idleMask != 0 ) begin
                  $display("HeaderWriter Bucket[%d]:: Insert into a empty slot", args.hv);
                  ind = mask2ind(idleMask);
               end
               else begin
                  $display("HeaderWriter Bucket[%d]::  Evict and insert into the smallest time stamp", args.hv);
                  Vector#(NumWays, Time_t) timestamps;
                  for (Integer i = 0; i < valueOf(NumWays); i = i + 1) begin
                     timestamps[i] = old_header[i].currtime;
                  end
                  ind = findLRU(timestamps);
                  if ( !old_header[ind].valAddr.onFlash )
                     trade_in = True;
               end
               
               valReqQ.enq(ValAllocReqT{nBytes: extend(args.value_size) + extend(args.key_size),
                                        oldAddr: truncate(old_header[ind].valAddr.valAddr),
                                        oldNBytes: extend(old_header[ind].nBytes) + extend(old_header[ind].keylen),
                                        //trade_in: trade_in});
                                        rtn_old: trade_in,
                                        req_new: True});
               newVal = True;
            end
            else if ( args.opcode == PROTOCOL_BINARY_CMD_DELETE ) begin
               $display("Deletion fail");
               retval.status = PROTOCOL_BINARY_RESPONSE_NOT_STORED;
               doWrite = False;
            end    
         end
   

         retval.value_addr = old_header[ind].valAddr;
         retval.value_size = extend(old_header[ind].nBytes) + extend(old_header[ind].keylen);
         retval.doEvict = False;
         retval.hv = args.hv;
         retval.idx = ind;
         
         hv_idxQ.enq({args.hv, ind});
         stageQ_0.enq(HeaderWriterPipeT{retval: retval,
                                        newhdr: newhdr,
                                        newValue: newVal,
                                        doWrite: doWrite,
                                        hv: args.hv,
                                        idx: ind,
                                        hvKey: args.hvKey,
                                        key_size: args.key_size,
                                        value_size: args.value_size,
                                        time_now: args.time_now
                                        });
      endmethod
   endinterface
   
   interface Get response = toGet(respQ);
   
   interface Get dramClient = toGet(dramReqQs[0]);
   
   interface Put hdrUpdateRequest = toPut(hdrUpdQ);
   
   interface Client hdrUpdDRAMClient = toClient(dramReqQs[1], dramRespQ);
   
   interface ValAllocClient valAllocClient = toClient(valReqQ, valRespQ);
   
endmodule
