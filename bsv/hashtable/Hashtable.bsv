package Hashtable;

import Connectable::*;
import GetPut::*;
import FIFO::*;
import Vector::*;
import DRAMController::*;
import DDR3::*;
import Time::*;
import Valuestr::*;
import Packet::*;
import HtArbiter::*;
import DRAMArbiter::*;

//`define DEBUG
import HashtableTypes::*;
import HeaderReader::*;
import KeyReader::*;
import HeaderWriter::*;
import KeyWriter::*;

interface HashtableInitIfc;
   method Action initTable(Bit#(64) lgOffset);
endinterface

interface HashtableIfc;
   method Action readTable(Bit#(8) keylen, Bit#(32) hv, Bit#(64) nBytes);
   method Action keyTokens(Bit#(64) keys);
   method ActionValue#(Tuple2#(Bit#(64), Bit#(64))) getValAddr();
   interface HashtableInitIfc init;
   interface DRAMClient dramClient;
   
endinterface


//(*synthesize*)
module mkAssocHashtb#(Clk_ifc real_clk, ValAlloc_ifc valAlloc)(HashtableIfc);
   Reg#(Bit#(64)) addrTop <- mkRegU();
   
   let dramEPs <- mkHtArbiter;
   
   let hdrReader <- mkHeaderReader(dramEPs.hdrRd);
   
   let keyReader <- mkKeyReader(dramEPs.keyRd);
   
   let hdrWriter <- mkHeaderWriter(dramEPs.hdrWr, valAlloc);
   
   let keyWriter <- mkKeyWriter(dramEPs.keyWr);
   
   FIFO#(Bit#(64)) keyTks <- mkFIFO;
      
   mkConnection(toGet(keyTks), keyReader.inPipe);
   mkConnection(keyReader.outPipe, keyWriter.inPipe);
   
   rule proc0;
      let v <- hdrReader.finish();
      keyReader.start(v);
   endrule
   
   rule proc1;
      let v <- keyReader.finish();
      hdrWriter.start(v);
   endrule
   
   rule proc2;
      let v <- hdrWriter.finish();
      keyWriter.start(v);
   endrule

      
   method Action readTable(Bit#(8) keylen, Bit#(32) hv, Bit#(64) nBytes);
      $display("Hashtable Request Received");
   
      PhyAddr baseAddr = ((unpack(zeroExtend(hv)) * fromInteger(valueOf(ItemOffset))) << 6) & addrTop;
      Bit#(16) totalBits = (zeroExtend(keylen) << 3) + fromInteger(valueOf(HeaderSz));
      Bit#(16) totalCnt;
      if ( (totalBits & fromInteger(valueOf(TSub#(LineWidth,1)))) == 0) begin
         totalCnt = totalBits >> fromInteger(valueOf(LogLnWidth)); 
      end
      else begin
         totalCnt = (totalBits >> fromInteger(valueOf(LogLnWidth))) + 1; 
      end
      Bit#(8) reqCnt_hdr = fromInteger(valueOf(HeaderTokens));
      Bit#(8) reqCnt_key;
      if ( valueOf(HeaderSz)%valueOf(LineWidth) == 0) begin
         reqCnt_key = truncate(totalCnt - zeroExtend(reqCnt_hdr));
      end
      else begin
         reqCnt_key = truncate(totalCnt - zeroExtend(reqCnt_hdr)) + 1;
      end
   
      PhyAddr rdAddr_key;
      if ( valueOf(HeaderSz)%valueOf(LineWidth) == 0) begin
         rdAddr_key = baseAddr + extend(reqCnt_hdr << 6);
      end
      else begin
         rdAddr_key = baseAddr + extend((reqCnt_hdr-1) << 6);
      end
  
      hdrReader.start(HdrRdParas{hv:hv, hdrAddr: baseAddr, hdrNreq: reqCnt_hdr, keyAddr: rdAddr_key, keyNreq: reqCnt_key, keyLen: keylen, nBytes: nBytes, time_now: real_clk.get_time});
            
   endmethod
   
   method Action keyTokens(Bit#(64) keys);
      $display("Hashtable keytoken received");
      //Vector#(8, Bit#(8)) byteVec = unpack(keys);
      //keyTks.enq(pack(reverse(byteVec)));
      keyTks.enq(keys);
   endmethod
   
   method ActionValue#(Tuple2#(Bit#(64), Bit#(64))) getValAddr();
      //valAddrFifo.deq;
      let v <- hdrWriter.getValAddr();
      return v;
   endmethod

   interface HashtableInitIfc init;
      method Action initTable(Bit#(64) lgOffset);// if (state == Idle);
         //hvMax <= unpack((1 << lgOffset) - 1) / fromInteger(valueOf(ItemOffset));
         addrTop <= (1 << lgOffset) - 1;
      endmethod
   endinterface
   
   interface DRAMClient dramClient = dramEPs.dramClient;
endmodule

endpackage: Hashtable

