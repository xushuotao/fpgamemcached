import FIFO::*;
import GetPut::*;
import Vector::*;

import Packet::*;
import HtArbiterTypes::*;
import HtArbiter::*;
import HashtableTypes::*;


interface HeaderReaderIfc;
   method Action start(HdrRdParas hdrRdParas);
   method ActionValue#(KeyRdParas) finish();
endinterface

module mkHeaderReader#(DRAMReadIfc dramEP)(HeaderReaderIfc);
   Reg#(Bool) busy <- mkReg(False);
  
   Reg#(PhyAddr) rdAddr_hdr <- mkRegU();
   Reg#(Bit#(8)) reqCnt_hdr <- mkRegU();
  
   Vector#(NumWays, DepacketIfc#(LineWidth, HeaderSz, 0)) depacketEngs_hdr <- replicateM(mkDepacketEngine());
   
   FIFO#(KeyRdParas) immediateQ <- mkFIFO;
   FIFO#(KeyRdParas) finishQ <- mkFIFO;
   
   rule driveRd_header (busy);
      if (reqCnt_hdr > 0 ) begin
         $display("Sending ReadReq for Header, rdAddr_hdr = %d", rdAddr_hdr);
         dramEP.request.put(DRAMReadReq{addr: rdAddr_hdr, numBytes:64});
         rdAddr_hdr <= rdAddr_hdr + 64;
         reqCnt_hdr <= reqCnt_hdr - 1;
      end
      else begin
         busy <= False;
      end
   endrule
        
   rule procHeader_2;
      let v <- dramEP.response.get();//toGet(dataFifo).get();
      Vector#(NumWays, Bit#(LineWidth)) vector_v = unpack(v);
      for (Integer i = 0; i < valueOf(NumWays); i=i+1) begin
         depacketEngs_hdr[i].inPipe.put(vector_v[i]);
      end
   endrule
   
   rule procHeader_3;
      Vector#(NumWays, ItemHeader) headers;
      Bit#(NumWays) cmpMask_temp = 0;
      Bit#(NumWays) idleMask_temp = 0;
      
      let args <- toGet(immediateQ).get();
      
      for (Integer i = 0; i < valueOf(NumWays); i=i+1) begin
         let v_ <- depacketEngs_hdr[i].outPipe.get;
         ItemHeader v = unpack(v_);
         headers[i] = v;
         if (v.idle != 0 ) begin
            idleMask_temp[i] = 1;
         end
         else if (v.keylen == args.keyLen ) begin
            cmpMask_temp[i] = 1;
         end
      end
      
      args.cmpMask = cmpMask_temp;
      args.idleMask = idleMask_temp;
      args.oldHeaders = headers;
      
      finishQ.enq(args);
      
   endrule

   method Action start(HdrRdParas args) if (!busy);
      $display("Header Reader Starts");
      for (Integer i = 0; i < valueOf(NumWays); i=i+1) begin
         depacketEngs_hdr[i].start(1, fromInteger(valueOf(HeaderTokens)));
      end
      dramEP.start(args.hv, extend(args.hdrNreq));
      rdAddr_hdr <= args.hdrAddr;
      reqCnt_hdr <= args.hdrNreq;
      busy <= True;
   
      immediateQ.enq(KeyRdParas{hv: args.hv,
                                hdrAddr: args.hdrAddr,
                                hdrNreq: args.hdrNreq,
                                keyAddr: args.keyAddr,
                                keyNreq: args.keyNreq,
                                keyLen: args.keyLen,
                                nBytes: args.nBytes,
                                time_now: args.time_now,
                                cmpMask: ?,
                                idleMask: ?,
                                oldHeaders: ?});
   endmethod
   
   method ActionValue#(KeyRdParas) finish();
      let v <- toGet(finishQ).get();
      return v;
   endmethod
endmodule
