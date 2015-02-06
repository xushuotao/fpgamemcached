import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import GetPut::*;
import Vector::*;

import HashtableTypes::*;
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
   method ActionValue#(Tuple3#(Bit#(64), Bit#(64), Bool)) getValAddr();
endinterface

module mkHeaderWriter#(ValAlloc_ifc valAlloc, DRAMWriteIfc dramEP)(HeaderWriterIfc);
   //FIFO#(Tuple3#(Bit#(64), Bit#(64), Bool)) valAddrFifo <- mkSizedFIFO(8);
   FIFO#(Tuple3#(Bit#(64), Bit#(64), Bool)) valAddrFifo <- mkSizedFIFO(16);
   FIFO#(ItemHeader) newHeaderQ <- mkFIFO;
   
   
   FIFO#(Tuple3#(Bit#(64), Bit#(64), Bool)) pre_valAddrFifo <- mkFIFO();
   FIFO#(ItemHeader) pre_hdr <- mkFIFO();
   FIFO#(Bool) new_val <- mkFIFO();
   FIFO#(KeyWrParas) immediateQ <- mkFIFO;
   FIFO#(KeyWrParas) finishQ <- mkFIFO;
   
   //FIFOF#(Bit#(32)) currhv <- mkLFIFOF();
   


   //PacketIfc#(LineWidth, HeaderSz, 0) packetEng_hdr <- mkPacketEngine();
   //PacketIfc#(128, 232, 0) packetEng_hdr <- mkPacketEngine(); 

   //(*descending_urgency = "prepWrite_1, start"*)
   
   rule prepWrite_1;
      //$display("%h",old_header[ind]);
      let newValue <- toGet(new_val).get();
      let retval <- toGet(pre_valAddrFifo).get();
      let newhdr <- toGet(pre_hdr).get();
      
      if ( newValue ) begin
         let newValAddr <- valAlloc.newAddrResp();
         let args = immediateQ.first();
         newHeaderQ.enq(ItemHeader{keylen : args.keyLen, // key length
                                   valAddr : newValAddr,//zeroExtend(hv), 
                                   currtime : args.time_now,// last accessed time
                                   nBytes : truncate(args.nBytes) //
                                   });
         $display("valAddFifo.enq, addr = %d, nBytes = %d, hit = %b", newValAddr, args.nBytes, True);
         valAddrFifo.enq(tuple3(newValAddr, args.nBytes, True));
      end
      else begin
         valAddrFifo.enq(retval);
         newHeaderQ.enq(newhdr);
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
   
      Tuple3#(Bit#(64), Bit#(64), Bool) retval = ?;
      ItemHeader newhdr = ?;
      Bool newVal = False;
   
      $display("HeaderWriter: cmpMask = %b, idleMask = %b, doWrite = %b, numBytes = %d, reqCnt = %d", cmpMask, idleMask, args.rnw, args.nBytes, reqCnt);
      reqCnt <= reqCnt + 1;
      if ( cmpMask != 0 ) begin
         // update the timestamp in the header;
         ind = mask2ind(cmpMask);
         
         //old_header[ind].refcount = old_header[ind].refcount + 1;
         old_header[ind].currtime = args.time_now;
                           
         retval = tuple3(old_header[ind].valAddr, extend(old_header[ind].nBytes), True);
         newhdr = old_header[ind];
         /*valAddrFifo.enq(tuple3(old_header[ind].valAddr, extend(old_header[ind].nBytes), True));
         newHeaderQ.enq(old_header[ind]);*/
      end
      else if (args.rnw) begin
         retval = tuple3(?,?,False);
         //valAddrFifo.enq(tuple3(?, ?, False));
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
            trade_in = True;
         end
         
         valAlloc.newAddrReq(args.nBytes, old_header[ind].valAddr, trade_in);
         /* more interesting stuff to do here */
         // update a new header if no hit
         newVal = True;
      end
   
      if (doWrite)
         dramEP.start(args.hv, args.idx, extend(args.hdrNreq));
   
      pre_valAddrFifo.enq(retval);
      pre_hdr.enq(newhdr);
      new_val.enq(newVal);
   
      immediateQ.enq(KeyWrParas{hv: args.hv,
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
                                byPass: !doWrite});
   endmethod
   
   method ActionValue#(KeyWrParas) finish();
      let v <- toGet(finishQ).get();
      return v;
   endmethod
   method ActionValue#(Tuple3#(Bit#(64), Bit#(64), Bool)) getValAddr();
      let v <- toGet(valAddrFifo).get;
      return v;
   endmethod
   
endmodule
