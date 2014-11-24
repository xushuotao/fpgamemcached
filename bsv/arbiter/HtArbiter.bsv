package HtArbiter;

import FIFO::*;
import FIFOF::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;

import HtArbiterTypes::*;
import DRAMArbiterTypes::*;
import DRAMArbiter::*;


interface DRAMReadIfc;
   method Action start(Bit#(32) hv, Bit#(32) numReqs);
   interface Put#(DRAMReadReq) request;
   interface Get#(Bit#(512)) response;
endinterface

interface DRAMWriteIfc;
   method Action start(Bit#(32) hv, Bit#(32) numReqs);
   interface Put#(DRAMWriteReq) request;
endinterface


interface HtArbiterIfc;
   interface DRAMReadIfc hdrRd;
   interface DRAMReadIfc keyRd;
   interface DRAMWriteIfc hdrWr;
   interface DRAMWriteIfc keyWr;
   interface DRAMClient dramClient;
endinterface

module mkHtArbiter(HtArbiterIfc);
   DRAMArbiterIfc#(4) arbiter <- mkDRAMArbiter(False);
   
   
   /* request fifos */
   FIFO#(Tuple2#(Bit#(32), Bit#(32))) hdrRd_reqs <- mkFIFO;
   FIFO#(Tuple2#(Bit#(32), Bit#(32))) keyRd_reqs <- mkFIFO;
   FIFO#(Tuple2#(Bit#(32), Bit#(32))) hdrWr_reqs <- mkFIFO;
   FIFO#(Tuple2#(Bit#(32), Bit#(32))) keyWr_reqs <- mkFIFO;
   
   /* dram req fifos */
   FIFO#(DRAMReadReq) hdrRd_ddrReqs <- mkFIFO;
   FIFO#(DRAMWriteReq) hdrWr_ddrReqs <- mkFIFO;
   FIFO#(DRAMReadReq) keyRd_ddrReqs <- mkFIFO;
   FIFO#(DRAMWriteReq) keyWr_ddrReqs <- mkFIFO;
   
   /* dram resp fifos */
   FIFO#(Bit#(512)) hdrRd_ddrResps <- mkFIFO;
   FIFO#(Bit#(512)) keyRd_ddrResps <- mkFIFO;
   
   mkConnection(arbiter.dramServers[0].response, toPut(hdrRd_ddrResps));
   mkConnection(arbiter.dramServers[2].response, toPut(keyRd_ddrResps));
   
   /* inflight commands */
   FIFOF#(Bit#(32)) hdrRd_inflight <- mkSizedFIFOF(1);
   FIFOF#(Bit#(32)) keyRd_inflight <- mkSizedFIFOF(1);
   FIFOF#(Bit#(32)) hdrWr_inflight <- mkSizedFIFOF(1);
   FIFOF#(Bit#(32)) keyWr_inflight <- mkSizedFIFOF(1);
   
   /* outstanding commands */
   /*Reg#(Bit#(5)) nextReqId <- mkReg(0);
   FIFOF#(Bit#(5)) hdrRd_reqIds <- mkSizedFIFOF(32);
   FIFOF#(Bit#(5)) keyRd_reqIds <- mkSizedFIFOF(32);
   Reg#(Bit#(5)) currRespId <- mkReg(0);*/
   
   /* dram things */
   FIFO#(DRAMReq) dramCmdQ <- mkFIFO();
   FIFO#(Bit#(512)) dramDataQ <- mkFIFO();
   
   //////////read header rules///////////
   Reg#(Bool) busy_hdrRd <- mkReg(False);
   
   Reg#(Bit#(32)) reqCnt_hdrRd <- mkReg(-1);
   Reg#(Bit#(32)) reqMax_hdrRd <- mkReg(0);
   
   
   rule doStart_hdrRd if (!busy_hdrRd);
      let v = hdrRd_reqs.first();
      let hv = tpl_1(v);
      let numReqs = tpl_2(v);
      if (hdrWr_inflight.notEmpty()) begin
         let inflight = hdrWr_inflight.first();
         if ( inflight != hv ) begin
            reqCnt_hdrRd <= 0;
            reqMax_hdrRd <= numReqs;
            hdrRd_reqs.deq;
            hdrRd_inflight.enq(hv);
            busy_hdrRd <= True;
         end
      end
      else begin
         reqCnt_hdrRd <= 0;
         reqMax_hdrRd <= numReqs;
         hdrRd_reqs.deq;
         hdrRd_inflight.enq(hv);
         busy_hdrRd <= True;
      end
   endrule
   
   rule issueCmd_hdrRd if (busy_hdrRd);
      if ( reqCnt_hdrRd >= reqMax_hdrRd ) begin
         busy_hdrRd <= False;
         hdrRd_inflight.deq();
      end
      else begin
         let req <- toGet(hdrRd_ddrReqs).get();
         arbiter.dramServers[0].request.put(DRAMReq{rnw:True, addr: req.addr, data:?, numBytes: req.numBytes});
         reqCnt_hdrRd <= reqCnt_hdrRd + 1;
      end
   endrule
   
   //////////write header rules///////////
   
   Reg#(Bool) busy_hdrWr <- mkReg(False);
   
   Reg#(Bit#(32)) reqCnt_hdrWr <- mkReg(-1);
   Reg#(Bit#(32)) reqMax_hdrWr <- mkReg(0);
   
   rule doStart_hdrWr if (!busy_hdrWr);
      let v = hdrWr_reqs.first();
      let hv = tpl_1(v);
      let numReqs = tpl_2(v);
      if (hdrRd_inflight.notEmpty()) begin
         let inflight = hdrRd_inflight.first();
         if ( inflight != hv ) begin
            reqCnt_hdrWr <= 0;
            reqMax_hdrWr <= numReqs;
            hdrWr_reqs.deq;
            hdrWr_inflight.enq(hv);
            busy_hdrWr <= True;
         end
      end
      else begin
         reqCnt_hdrWr <= 0;
         reqMax_hdrWr <= numReqs;
         hdrWr_reqs.deq;
         hdrWr_inflight.enq(hv);
         busy_hdrWr <= True;
      end
   endrule
   
   rule issueCmd_hdrWr if (busy_hdrWr);
      if ( reqCnt_hdrWr >= reqMax_hdrWr ) begin
         busy_hdrWr <= False;
         hdrWr_inflight.deq();
      end
      else begin
         let req <- toGet(hdrWr_ddrReqs).get();
         arbiter.dramServers[1].request.put(DRAMReq{rnw:False, addr: req.addr, data:req.data, numBytes: req.numBytes});
         reqCnt_hdrWr <= reqCnt_hdrWr + 1;
      end
   endrule
   
   //////////read key rules///////////
   Reg#(Bool) busy_keyRd <- mkReg(False);
   
   Reg#(Bit#(32)) reqCnt_keyRd <- mkReg(-1);
   Reg#(Bit#(32)) reqMax_keyRd <- mkReg(0);
   
   rule doStart_keyRd if (!busy_keyRd);
      let v = keyRd_reqs.first();
      let hv = tpl_1(v);
      let numReqs = tpl_2(v);
      if (keyWr_inflight.notEmpty()) begin
         let inflight = keyWr_inflight.first();
         if ( inflight != hv ) begin
            reqCnt_keyRd <= 0;
            reqMax_keyRd <= numReqs;
            keyRd_reqs.deq;
            keyRd_inflight.enq(hv);
            busy_keyRd <= True;
         end
      end
      else begin
         reqCnt_keyRd <= 0;
         reqMax_keyRd <= numReqs;
         keyRd_reqs.deq;
         keyRd_inflight.enq(hv);
         busy_keyRd <= True;
      end
   endrule
   
   rule issueCmd_keyRd if (busy_keyRd);
      if ( reqCnt_keyRd >= reqMax_keyRd ) begin
         busy_keyRd <= False;
         keyRd_inflight.deq();
      end
      else begin
         let req <- toGet(keyRd_ddrReqs).get();
         arbiter.dramServers[2].request.put(DRAMReq{rnw:True, addr: req.addr, data:?, numBytes: req.numBytes});
         reqCnt_keyRd <= reqCnt_keyRd + 1;
      end
   endrule
   
   //////////write key rules///////////
   
   Reg#(Bool) busy_keyWr <- mkReg(False);
   
   Reg#(Bit#(32)) reqCnt_keyWr <- mkReg(-1);
   Reg#(Bit#(32)) reqMax_keyWr <- mkReg(0);
   
   rule doStart_keyWr if (!busy_keyWr);
      let v = keyWr_reqs.first();
      let hv = tpl_1(v);
      let numReqs = tpl_2(v);
      if (keyRd_inflight.notEmpty()) begin
         let inflight = keyRd_inflight.first();
         if ( inflight != hv ) begin
            reqCnt_keyWr <= 0;
            reqMax_keyWr <= numReqs;
            keyWr_reqs.deq;
            keyWr_inflight.enq(hv);
            busy_keyWr <= True;
         end
      end
      else begin
         reqCnt_keyWr <= 0;
         reqMax_keyWr <= numReqs;
         keyWr_reqs.deq;
         keyWr_inflight.enq(hv);
         busy_keyWr <= True;
      end
   endrule
   
   rule issueCmd_keyWr if (busy_keyWr);
      if ( reqCnt_keyWr >= reqMax_keyWr ) begin
         busy_keyWr <= False;
         keyWr_inflight.deq();
      end
      else begin
         let req <- toGet(keyWr_ddrReqs).get();
         arbiter.dramServers[3].request.put(DRAMReq{rnw:False, addr: req.addr, data:req.data, numBytes: req.numBytes});
         reqCnt_keyWr <= reqCnt_keyWr + 1;
      end
   endrule
   
   
   interface DRAMReadIfc hdrRd;
      method Action start(Bit#(32) hv, Bit#(32) numReqs);
         hdrRd_reqs.enq(tuple2(hv, numReqs));
      endmethod
      interface Put request = toPut(hdrRd_ddrReqs);
      interface Get response = toGet(hdrRd_ddrResps);
   endinterface
  
   interface DRAMReadIfc keyRd;
      method Action start(Bit#(32) hv, Bit#(32) numReqs);
         keyRd_reqs.enq(tuple2(hv, numReqs));
      endmethod
      interface Put request = toPut(keyRd_ddrReqs);
      interface Get response = toGet(keyRd_ddrResps);
   endinterface
   
   interface DRAMWriteIfc hdrWr;
      method Action start(Bit#(32) hv, Bit#(32) numReqs);
         hdrWr_reqs.enq(tuple2(hv, numReqs));
      endmethod
      interface Put request = toPut(hdrWr_ddrReqs);
   endinterface
      
   interface DRAMWriteIfc keyWr;
      method Action start(Bit#(32) hv, Bit#(32) numReqs);
         keyWr_reqs.enq(tuple2(hv, numReqs));
      endmethod
      interface Put request = toPut(keyWr_ddrReqs);
   endinterface
  
   interface dramClient = arbiter.dramClient;

endmodule


endpackage
