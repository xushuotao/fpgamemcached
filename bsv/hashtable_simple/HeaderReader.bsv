import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import GetPut::*;
import ClientServer::*;
import ClientServerHelper::*;
import Vector::*;

import DRAMCommon::*;
import MemcachedTypes::*;
import HashtableTypes::*;

import ParameterTypes::*;

import Fifo::*;


interface HeaderReaderIfc;
   interface Put#(HdrRdReqT) request;
   interface Get#(HdrWrReqT) response;
   interface Put#(Bool) wrAck;
   //interface SFifo#(NUM_STAGES, HashValueT, HashValueT) sFifoPort;
   interface DRAMClient dramClient;
endinterface
 
(*synthesize*)
module mkHeaderReader(HeaderReaderIfc);
   Reg#(Bit#(16)) reqCnt <- mkReg(0);
   
   //FIFO#(HdrRdReqT) reqQ <- mkFIFO();
   FIFO#(HdrRdReqT) immQ <- mkSizedFIFO(numStages);
   FIFO#(HdrWrReqT) respQ <- mkFIFO;
   
   FIFO#(DRAMReq) dramCmdQ <- mkFIFO();
   FIFO#(Bit#(512)) dramDtaQ <- mkFIFO();
   FIFO#(Bool) wrAckQ <- mkBypassFIFO;
   
   
   SFifo#(NUM_STAGES, HashValueT, HashValueT) sFifo <- mkCFSFifo(eq);
   FIFO#(HashValueT) reqQ <- mkSizedFIFO(numStages);
   //rule doDRAMCmd if ( !sFifo.search(reqQ.first.hv) );
   rule doDRAMCmd if ( !sFifo.search(reqQ.first) );
      //let args <- toGet(reqQ).get();
      //let hv = args.hv;
      let hv <- toGet(reqQ).get();
      $display("Header Reader Starts for hv = %h, addr = %d, ReqCnt = %d", hv, hv << 6, reqCnt);
      reqCnt <= reqCnt + 1;
      dramCmdQ.enq(DRAMReq{rnw: True, addr: extend(hv << 6), numBytes:64});
      sFifo.enq(hv);
      //immQ.enq(args);
   endrule

   
   rule procHeader;
      let d <- toGet(dramDtaQ).get();
      let args <- toGet(immQ).get();
      //if ( d == ? ) d = 0;
      Vector#(NumWays, Bit#(TDiv#(512, NumWays))) dataV = unpack(d);
      //$display("HeaderReader got: %h", d);
      //d = 0;
      Vector#(NumWays, ItemHeader) headers;
      for (Integer i = 0; i < 4; i = i + 1) begin
         headers[i] = unpack(dataV[i]);
      end
      
      
      Bit#(NumWays) cmpMask_temp = 0;
      Bit#(NumWays) idleMask_temp = 0;
      for (Integer i = 0; i < valueOf(NumWays); i=i+1) begin
         ItemHeader v = headers[i];
         if (v.keylen == args.key_size && v.hvKey == args.hvKey )
            cmpMask_temp[i] = 1;
         if (v.keylen == 0)
            idleMask_temp[i] = 1;
      end
      
      
      respQ.enq(HdrWrReqT{hv: args.hv,
                          hvKey: args.hvKey,
                          key_size: args.key_size,
                          value_size: args.value_size,
                          time_now: args.time_now,
                          opcode: args.opcode,
                          cmpMask: cmpMask_temp,
                          idleMask: idleMask_temp,
                          oldHeaders: headers,
                          reqId: args.reqId
                          });
   endrule

   Reg#(Bit#(32)) ackCnt <- mkReg(0);
   rule doWrAck;
      ackCnt <= ackCnt + 1;
      $display("HeaderReader:: wrAck = %d", ackCnt);
      wrAckQ.deq();
      sFifo.deq();
   endrule
   
   
   //interface Put request = toPut(reqQ);
   interface Put request;// = toPut(reqQ);
      method Action put(HdrRdReqT v);
         reqQ.enq(v.hv);
         immQ.enq(v);
         endmethod
      endinterface
   interface Get response = toGet(respQ);
   interface Put wrAck = toPut(wrAckQ);
   interface DRAMClient dramClient = toClient(dramCmdQ, dramDtaQ);
endmodule
