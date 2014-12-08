import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import GetPut::*;
import ClientServer::*;
import Vector::*;

import HtArbiterTypes::*;
import HtArbiter::*;
import HashtableTypes::*;


interface HeaderReaderIfc;
   method Action start(HdrRdParas hdrRdParas);
   method ActionValue#(KeyRdParas) finish();
endinterface

module mkHeaderReader#(DRAMReadIfc dramEP)(HeaderReaderIfc);
   FIFO#(KeyRdParas) immediateQ <- mkSizedFIFO(16);
   FIFO#(KeyRdParas) finishQ <- mkBypassFIFO;
   
   /*rule shit;
      let d <- dramEP.response.get();
   endrule*/
   
   rule procHeader;
      let d <- dramEP.response.get();
      Vector#(NumWays, ItemHeader) headers = unpack(d);
      Bit#(NumWays) cmpMask_temp = 0;
      Bit#(NumWays) idleMask_temp = 0;
      
      let args <- toGet(immediateQ).get();
      
      for (Integer i = 0; i < valueOf(NumWays); i=i+1) begin
         ItemHeader v = headers[i];
         if (v.keylen == args.keyLen )
            cmpMask_temp[i] = 1;
         
         if (v.keylen == 0)
            idleMask_temp[i] = 1;
      end
      
      let idx <- dramEP.getReqId();
      args.idx = idx;
      args.cmpMask = cmpMask_temp;
      args.idleMask = idleMask_temp;
      args.oldHeaders = headers;
      
      finishQ.enq(args);
      
   endrule
   
   Reg#(Bit#(64)) cnt <- mkReg(0);
      
   method Action start(HdrRdParas args);// if (!busy);
      $display("Header Reader Starts for hv = %h, ReqCnt = %d", args.hv, cnt);
      cnt <= cnt + 1;
  
      dramEP.start(args.hv, ?, extend(args.hdrNreq));
      dramEP.request.put(HtDRAMReq{rnw: True, addr: args.hdrAddr, numBytes:64});
   
      immediateQ.enq(KeyRdParas{hv: args.hv,
                                idx: ?,
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
