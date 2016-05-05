import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import GetPut::*;
import Vector::*;
import ClientServer::*;
import ClientServerHelper::*;

import HashtableTypes::*;
import HtArbiterTypes::*;
import HtArbiter::*;
import Time::*;
import ValueManager::*;

import ParameterTypes::*;

function Bit#(TLog#(NumWays)) mask2ind (Bit#(NumWays) mask);
   Bit#(TLog#(NumWays)) retval = ?;
  
   for (Integer i = 0; i < valueOf(NumWays); i = i + 1) begin
      if ((mask >> fromInteger(i))[0] == 1) begin
         retval = fromInteger(i);
      end
   end
   return retval;
endfunction

function Bit#(TLog#(NumWays)) findLRU (Vector#(NumWays, Time_t) timestamps);
   Integer retval = ?;
   Vector#(NumWays, Bit#(NumWays)) maskVec = replicate(1);
   for (Integer i = 0; i < valueOf(NumWays); i = i + 1) begin
      //let time_i = timestamps[i];
      for (Integer j = 0; j < valueOf(NumWays); j = j + 1) begin
         if ( timestamps[i] > timestamps[j] ) begin
            maskVec[i][j] = 0;
         end
      end
   end
   for (Integer k = 0; k < valueOf(NumWays); k = k + 1) begin
      if ( maskVec[k] != 0 ) begin
         retval = k;
      end
   end
   return fromInteger(retval);
endfunction

interface HeaderWriterIfc;
   method Action start(HdrWrParas hdrRdParas);
   method ActionValue#(KeyWrParas) finish();
   method ActionValue#(HtRespType) getValAddr();

   interface Put#(HeaderUpdateReqT) hdrUpdateRequest;
   interface Client#(DRAMReq, Bool) hdrUpdDramClient;
   
   interface ValAllocClient valAllocClient;
   

endinterface

typedef struct{
   HtRespType retval;
   
   ItemHeader newhdr;
   Bool newValue;
   KeyWrParas args;
   
   } HeaderWriterPipeT deriving (Bits, Eq);

module mkHeaderWriter#(DRAMWriteIfc dramEP)(HeaderWriterIfc);
   //FIFO#(Tuple3#(Bit#(64), Bit#(64), Bool)) valAddrFifo <- mkSizedFIFO(8);
   //FIFO#(Tuple3#(Bit#(64), Bit#(64), Bool)) valAddrFifo <- mkSizedFIFO(numStages);
   FIFO#(HtRespType) valAddrFifo <- mkSizedFIFO(numStages);
   FIFO#(ItemHeader) newHeaderQ <- mkFIFO;
   
   FIFO#(ValAllocReqT) valReqQ <- mkFIFO();
   FIFO#(ValAllocRespT) valRespQ <- mkFIFO();

   
   //FIFO#(Tuple3#(Bit#(64), Bit#(64), Bool)) pre_valAddrFifo <- mkFIFO();
   //FIFO#(HtRespType) pre_valAddrFifo <- mkFIFO();
   //FIFO#(ItemHeader) pre_hdr <- mkFIFO();
   //FIFO#(Bool) new_val <- mkFIFO();
   //FIFO#(KeyWrParas) pre_immediateQ <- mkFIFO;
   FIFO#(HeaderWriterPipeT) stageQ <- mkFIFO;
   FIFO#(KeyWrParas) immediateQ <- mkFIFO;
   FIFO#(KeyWrParas) finishQ <- mkFIFO;
   
   //FIFOF#(Bit#(32)) currhv <- mkLFIFOF();
   
   FIFO#(HeaderUpdateReqT) hdrUpdQ <- mkFIFO();

   //PacketIfc#(LineWidth, HeaderSz, 0) packetEng_hdr <- mkPacketEngine();
   //PacketIfc#(128, 232, 0) packetEng_hdr <- mkPacketEngine(); 

   //(*descending_urgency = "prepWrite_1, start"*)
   
   FIFO#(Tuple3#(Bit#(64), Bit#(2), FlashAddrType)) flashReqQ <- flashReq;
   
   FIFO#(DRAMReq) dramReqQ <- mkFIFO();
   FIFO#(Bool) dramRespQ <- mkFIFO();
   
   FIFOF#(PhyAddr) outstandingHdrUpdQ <- mkFIFOF;
   rule doHdrUpdQ;
      let v <- toGet(hdrUpdQ).get();
      let hv = v.hv;
      let idx = v.idx;
      PhyAddr baseAddr = (unpack(zeroExtend(hv)) * fromInteger(valueOf(ItemOffset))) << 6;
      let wrAddr = baseAddr + (zeroExtend(ind) << valueOf(LgLineBytes));
      
      dramReqQ.enq(DRAMReq{rnw:False, addr: wrAddr, data:extend(ValAddrT{onFlash:True, valAddr: extend(v.flashAddr)}), numBytes:fromInteger(TDiv#(SizeOf#(ValAddrT), 8))});
      
      outstandintHdrUpdQ.enq(wrAddr);
   endrule
   
   rule doHdrUpdResp;
      let v <- toGet(dramRespQ).get();
      outstandingHdrUpdQ.deq();
   endrule
   
   rule prepWrite_1;
      Bool proceed = True;
      if ( outstandingHdrUpdQ.notEmpty) begin
         if ( outstandingHdrUpdQ.first == stageQ.first.args.wrAddr )
            proceed = False;
      end

      if ( proceed) begin
         let v <- toGet(stageQ).get();
         let newValue = v.newValue;
         let retval = v.retval;
         let args = v.args;
         
         immediateQ.enq(args);
         
         if ( newValue ) begin
            let newValAddr <- toGet(valRespQ).get();
            newHeaderQ.enq(ItemHeader{keylen : args.keyLen, // key length
                                      valAddr : ValAddrT{onFlash:False, valAddr: zeroExtend(newValAddr.newAddr)},//zeroExtend(hv), 
                                      currtime : args.time_now,// last accessed time
                                      nBytes : truncate(args.nBytes) //
                                      });
            $display("valAddFifo.enq, addr = %d, nBytes = %d, hit = %b", newValAddr.newAddr, args.nBytes, True);
            //valAddrFifo.enq(tuple3(newValAddr, args.nBytes, True));
            retval.addr = newValAddr.newAddr;
            retval.nBytes = args.nBytes;
            retval.oldNbytes = newValAddr.oldNBytes;
            retval.hit = True;
            retval.doEvict = newValAddr.doEvict;
            outstandingHdrUpdQ.enq(args.wrAddr);
         end
         else begin
            //valAddrFifo.enq(retval);
            newHeaderQ.enq(newhdr);
         end
         valAddrFifo.enq(retval);
      end
   endrule
   
   rule writeHeader;
      let newHeader <- toGet(newHeaderQ).get();
      let wrVal = pack(newHeader);
      let v <- toGet(immediateQ).get();
      let wrAddr = v.hdrAddr;
      
      if ( !v.byPass ) begin
         Bit#(7) numOfBytes = fromInteger(valueOf(LineBytes));
         $display("HeaderWriter wrAddr = %d, wrVal = %h, bytes = %d", wrAddr, wrVal, numOfBytes);
         dramEP.request.put(HtDRAMReq{rnw: False, addr:wrAddr, data:zeroExtend(wrVal), numBytes:numOfBytes});
      end
      finishQ.enq(v);     
   endrule
   Reg#(Bit#(16)) reqCnt <- mkReg(0);
   method Action start(HdrWrParas args);
   
      //$display("Fourth Stage: PrepWrite");      
      let old_header = args.oldHeaders;
      let cmpMask = args.cmpMask;
      let idleMask = args.idleMask;
      Bit#(TLog#(NumWays)) ind = ?;
 
      Bool doWrite = True;
   
      HtRespType retval = ?;
      ItemHeader newhdr = ?;
      Bool newVal = False;
   
      $display("HeaderWriter: cmpMask = %b, idleMask = %b, doWrite = %b, numBytes = %d, reqCnt = %d", cmpMask, idleMask, args.rnw, args.nBytes, reqCnt);
      reqCnt <= reqCnt + 1;
      if ( cmpMask != 0 ) begin
         // update the timestamp in the header;
         ind = mask2ind(cmpMask);
         
         old_header[ind].currtime = args.time_now;
                           
         retval.addr = old_header[ind].valAddr;
         retval.nBytes = old_header[ind].nBytes;
         retval.hit = True;
         
         newhdr = old_header[ind];
         
      end
      else if (args.rnw) begin
         retval.hit = False;
         doWrite = False;
      end
      else begin
         Bool trade_in = False;
         if ( idleMask != 0 ) begin
            ind = mask2ind(idleMask);
            $display("Foruth Stage: idleMask = %b, ind = %d", idleMask, ind);
         end
         else begin
            // choose the smallest time stamp, and update the header and the key;
            Vector#(NumWays, Time_t) timestamps;
            for (Integer i = 0; i < valueOf(NumWays); i = i + 1) begin
               timestamps[i] = old_header[i].currtime;
            end
            ind = findLRU(timestamps);
            if ( !old_header[i].valAddr.onFlash )
               trade_in = True;
         end
         
         //valAlloc.newAddrReq(args.nBytes, old_header[ind].valAddr, trade_in);
         valReqQ.enq(ValAllocReqT{nBytes: extend(args.nBytes),
                                  oldAddr: truncate(old_header[ind].valAddr),
                                  oldNBytes: extend(old_header[ind].nBytes),
                                  trade_in: trade_in});
         /* more interesting stuff to do here */
         // update a new header if no hit
         newVal = True;
      end
      
      retval.doEvict = False;
      retval.hv = truncate(args.hv);
      retval.idx = ind;
   
      if (doWrite)
         dramEP.start(args.hv, args.idx, extend(args.hdrNreq));
   
      pre_valAddrFifo.enq(retval);
      pre_hdr.enq(newhdr);
      new_val.enq(newVal);
   
      stageQ.enq(HeaderWriterPipeT{retval: retval,
                                   newhdr: newhdr,
                                   newValue: newVal,
                                   args: KeyWrParas{hv: args.hv,
                                                    idx: args.idx,
                                                    hdrAddr: args.hdrAddr + (zeroExtend(ind) << valueOf(LgLineBytes)),
                                                    hdrNreq: args.hdrNreq,
                                                    keyAddr: args.keyAddr + (zeroExtend(ind) << valueOf(LgLineBytes)),
                                                    keyNreq: args.keyNreq,
                                                    keyLen: args.keyLen,
                                                    nBytes: args.nBytes,
                                                    time_now: args.time_now,
                                                    cmpMask: args.cmpMask,
                                                    idleMask: args.idleMask,
                                                    byPass: !doWrite}});
   endmethod
   
   method ActionValue#(KeyWrParas) finish();
      let v <- toGet(finishQ).get();
      return v;
   endmethod
   method ActionValue#(HtRespType) getValAddr();
      let v <- toGet(valAddrFifo).get;
      return v;
   endmethod

   interface Put hdrUpdateRequest = toPut(hdrUpdQ);
   
   //interface Get dramRequest = toGet(dramReqQ);
   interface Client hdrUpdDRAMClient = toClient(dramReqQ, dramRespQ);
   
   interface ValAllocClient valAllocClient = toClient(valReqQ, valRespQ);
   
endmodule
