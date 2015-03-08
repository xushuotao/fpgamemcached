package Hashtable;

import Connectable::*;
import ClientServer::*;
import GetPut::*;
import FIFO::*;
import FIFOF::*;
import Vector::*;
import DRAMController::*;
import DDR3::*;
import Time::*;
import Valuestr::*;
import HtArbiterTypes::*;
import HtArbiter::*;
import DRAMArbiterTypes::*;
import DRAMArbiter::*;

//`define DEBUG
import HashtableTypes::*;
import HeaderReader::*;
import KeyReader::*;
import HeaderWriter::*;
import KeyWriter::*;

interface HashtableInitIfc;
   method Action initTable(Bit#(64) lgOffset);
   method Bool initialized;
endinterface

interface HashtableIfc;
   method Action readTable(Bit#(8) keylen, Bit#(32) hv, Bit#(64) nBytes, Bool rnw);
   method Action keyTokens(Bit#(64) keys);
   method ActionValue#(HtRespType) getValAddr();
   interface HashtableInitIfc init;
   interface DRAMClient dramClient;
   
endinterface


//(*synthesize*)
module mkAssocHashtb#(Clk_ifc real_clk, ValAlloc_ifc valAlloc)(HashtableIfc);
   Reg#(Bit#(64)) addrTop <- mkRegU();
  
   let htArbiter <- mkHtArbiter();
     
   let keyWriter <- mkKeyWriter(htArbiter.keyWr);
   
   let hdrWriter <- mkHeaderWriter(valAlloc, htArbiter.hdrWr);
   
   let keyReader <- mkKeyReader(htArbiter.keyRd);
   
   let hdrReader <- mkHeaderReader(htArbiter.hdrRd);
   
   /*
   mkConnection(hdrReader.dramEP, htArbiter.hdrRd);
   mkConnection(keyReader.dramEP, htArbiter.keyRd);
   mkConnection(hdrWriter.dramEP, htArbiter.hdrWr);
   mkConnection(keyWriter.dramEP, htArbiter.keyWr);
   */
      
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

   DRAMArbiterIfc#(2) dramSwitch <- mkDRAMArbiter;
   mkConnection(htArbiter.dramClient, dramSwitch.dramServers[0]);
   
   Reg#(PhyAddr) addr <- mkReg(0);
   FIFO#(PhyAddr) addrMaxQ <- mkFIFO;
   Reg#(Bool) initialized <- mkReg(False);
   rule doinit;
      let addrMax = addrMaxQ.first();
      if ( addr + (fromInteger(valueOf(ItemOffset)) << 6) >= addrMax ) begin
         addr <= 0;
         addrMaxQ.deq;
         initialized <= True;
      end
      else begin
         addr <= addr + (fromInteger(valueOf(ItemOffset)) << 6);
      end
      dramSwitch.dramServers[1].request.put(DRAMReq{rnw: False,
                                                    addr: addr, 
                                                    data: 0,
                                                    numBytes: 64});
   endrule
     
   Reg#(Bit#(32)) hvMax <- mkRegU();
         
      
   Reg#(Bit#(32)) hvCnt <- mkReg(0);
   method Action readTable(Bit#(8) keylen, Bit#(32) hv, Bit#(64) nBytes, Bool rnw) if (initialized);
      $display("Hashtable Request Received");
      //let hv = hvCnt;
      hvCnt <= hvCnt + 1;
      //hv = 0;
   
      PhyAddr baseAddr = (unpack(zeroExtend(hvMax & hv)) * fromInteger(valueOf(ItemOffset))) << 6;// & addrTop;
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
  
      //hv = 0;
      hdrReader.start(HdrRdParas{hv:hv & hvMax, hdrAddr: baseAddr, hdrNreq: reqCnt_hdr, keyAddr: rdAddr_key, keyNreq: reqCnt_key, keyLen: keylen, nBytes: nBytes, time_now: real_clk.get_time, rnw: rnw});
            
   endmethod
   
   method Action keyTokens(Bit#(64) keys);
      $display("Hashtable keytoken received");
      //Vector#(8, Bit#(8)) byteVec = unpack(keys);
      //keyTks.enq(pack(reverse(byteVec)));
      keyTks.enq(keys);
   endmethod
   
   method ActionValue#(HtRespType) getValAddr();
      //valAddrFifo.deq;
      let v <- hdrWriter.getValAddr();
      return v;
   endmethod

   interface HashtableInitIfc init;
      method Action initTable(Bit#(64) lgOffset);// if (state == Idle);
         //hvMax <= unpack((1 << lgOffset) - 1) / fromInteger(valueOf(ItemOffset));
         hvMax <= (1 << lgOffset) - 1;
         PhyAddr maxAddr = ((1 << lgOffset) * fromInteger(valueOf(ItemOffset))) << 6;
         //`ifndef BSIM
         addrTop <= maxAddr;
         addrMaxQ.enq(maxAddr);
         initialized <= False;
        // `else
        // initialized <= True;
         //`endif
      endmethod
   
      method Bool initialized;
         return initialized;
      endmethod
   endinterface
   
   interface DRAMClient dramClient = dramSwitch.dramClient;
endmodule

endpackage: Hashtable

