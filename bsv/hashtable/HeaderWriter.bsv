import FIFO::*;
import GetPut::*;
import Vector::*;

import HashtableTypes::*;
import Packet::*;
import HtArbiterTypes::*;
import HtArbiter::*;
import Time::*;
import Valuestr::*;

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
   method ActionValue#(Tuple2#(Bit#(64), Bit#(64))) getValAddr();
endinterface

module mkHeaderWriter#(DRAMWriteIfc dramEP, ValAlloc_ifc valAlloc)(HeaderWriterIfc);
   FIFO#(Tuple2#(Bit#(64), Bit#(64))) valAddrFifo <- mkFIFO();
   FIFO#(ItemHeader) newHeaderQ <- mkFIFO;
   
   Reg#(Bool) busy <- mkReg(False);
   
   FIFO#(KeyWrParas) immediateQ <- mkFIFO;
   FIFO#(KeyWrParas) finishQ <- mkFIFO;

   PacketIfc#(LineWidth, HeaderSz, 0) packetEng_hdr <- mkPacketEngine();
   //PacketIfc#(128, 232, 0) packetEng_hdr <- mkPacketEngine(); 

   rule prepWrite_1(busy);
      //$display("%h",old_header[ind]);
      let newValAddr <- valAlloc.newAddrResp();
      let args = immediateQ.first();
      newHeaderQ.enq(ItemHeader{idle: 0,
                                keylen : args.keyLen, // key length
                                clsid : 0 , // slab class id
                                valAddr : newValAddr,//zeroExtend(hv), 
                                refcount : 0,
                                exptime : 0, // expiration time
                                currtime : args.time_now,// last accessed time
                                nBytes : args.nBytes //
                                });
      valAddrFifo.enq(tuple2(newValAddr, args.nBytes));
      busy <= False;

      //state <= WriteHeader;
      //packetEng_hdr.start(1, fromInteger(valueOf(HeaderTokens)));
   endrule
   
   rule writeHeader_1;
      let newHeader <- toGet(newHeaderQ).get();
      packetEng_hdr.inPipe.put(pack(newHeader));
   endrule
   
   Reg#(Bit#(8)) hdrCnt <- mkReg(0);
   FIFO#(Bit#(8)) hdrMaxQ <- mkFIFO;
   rule writeHeader_2;
      let hdrMax = hdrMaxQ.first();
      let wrVal <- packetEng_hdr.outPipe.get();
      
      let v = immediateQ.first();
      let baseAddr = v.hdrAddr;
      let wrAddr = baseAddr + extend({hdrCnt,6'b0});
      
      Bit#(7) numOfBytes = fromInteger(valueOf(LineBytes));
           
      if (hdrCnt + 1 == hdrMax) begin
         numOfBytes = fromInteger(valueOf(HeaderRemainderBytes));
         hdrMaxQ.deq;
         immediateQ.deq;
         finishQ.enq(v);
         hdrCnt <= 0;
      end
      else begin
         hdrCnt <= hdrCnt + 1;
      end
      
      $display("HeaderWriter wrAddr = %d, wrVal = %h, bytes = %d", wrAddr, wrVal, numOfBytes);
      dramEP.request.put(DRAMWriteReq{addr:wrAddr, data:zeroExtend(wrVal), numBytes:numOfBytes});
   endrule
   
   method Action start(HdrWrParas args) if (!busy);
   
      $display("Fourth Stage: PrepWrite");      
      let old_header = args.oldHeaders;
      let cmpMask = args.cmpMask;
      let idleMask = args.idleMask;
      Bit#(TLog#(NumWays)) ind;
 
      $display("HeaderWriter: cmpMask = %b, idleMask = %b", cmpMask, idleMask);
      if ( cmpMask != 0 ) begin
         // update the timestamp in the header;
         ind = mask2ind(cmpMask);
         
         old_header[ind].refcount = old_header[ind].refcount + 1;
         old_header[ind].currtime = args.time_now;
                           
         valAddrFifo.enq(tuple2(old_header[ind].valAddr, old_header[ind].nBytes));
         newHeaderQ.enq(old_header[ind]);
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
            trade_in = True;
         end
         
         valAlloc.newAddrReq(args.nBytes, old_header[ind].valAddr, trade_in);
         /* more interesting stuff to do here */
         // update a new header if no hit
         
         busy <= True;
      end
   
      dramEP.start(args.hv, extend(args.hdrNreq));
      packetEng_hdr.start(1, fromInteger(valueOf(HeaderTokens)));
      hdrMaxQ.enq(args.hdrNreq);
   
      immediateQ.enq(KeyWrParas{hdrAddr: args.hdrAddr + (zeroExtend(ind) << valueOf(LgLineBytes)),
                                hdrNreq: args.hdrNreq,
                                keyAddr: args.keyAddr + (zeroExtend(ind) << valueOf(LgLineBytes)),
                                keyNreq: args.keyNreq,
                                keyLen: args.keyLen,
                                nBytes: args.nBytes,
                                time_now: args.time_now,
                                cmpMask: args.cmpMask,
                                idleMask: args.idleMask});
   endmethod
   
   method ActionValue#(KeyWrParas) finish();
      let v <- toGet(finishQ).get();
      return v;
   endmethod
   method ActionValue#(Tuple2#(Bit#(64), Bit#(64))) getValAddr();
      let v <- toGet(valAddrFifo).get;
      return v;
   endmethod
endmodule
