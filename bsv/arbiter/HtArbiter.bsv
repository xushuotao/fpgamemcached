package HtArbiter;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;

import HtArbiterTypes::*;
import DRAMCommon::*;
import DRAMArbiter::*;
import Scoreboard::*;
import MyArbiter::*;

import ParameterTypes::*;


interface DRAMReadIfc;
   method Action start(Bit#(32) hv, Bit#(8) idx, Bit#(32) numReqs);
   method ActionValue#(Bit#(8)) getReqId();
   interface Put#(HtDRAMReq) request;
   interface Get#(Bit#(512)) response;
endinterface

interface DRAMWriteIfc;
   method Action start(Bit#(32) hv, Bit#(8) idx, Bit#(32) numReqs);
   interface Put#(HtDRAMReq) request;
endinterface


interface HtArbiterIfc;
   interface DRAMReadIfc hdrRd;
   interface DRAMReadIfc keyRd;
   interface DRAMWriteIfc hdrWr;
   interface DRAMWriteIfc keyWr;
   interface DRAMClient dramClient;
   interface Server#(DRAMReq, Bool) hdrUpdServer;
endinterface

module mkHtArbiter(HtArbiterIfc);
   Arbiter_IFC#(4) arbiter <- mkArbiter(False);
   
   
   /* request fifos */
   Vector#(4, FIFO#(Tuple3#(Bit#(32), Bit#(8), Bit#(32)))) reqFifos <- replicateM(mkFIFO);
   //Vector#(4, FIFO#(Tuple3#(Bit#(32), Bit#(8), Bit#(32)))) reqFifos <- replicateM(mkBypassFIFO);
   let hdrRd_reqs = reqFifos[0];
   let keyRd_reqs = reqFifos[2];
   let hdrWr_reqs = reqFifos[1];
   let keyWr_reqs = reqFifos[3];
   
   /* dram req fifos */
   Vector#(4, FIFOF#(HtDRAMReq)) ddrReqFifos <- replicateM(mkFIFOF);
   let hdrRd_ddrReqs = ddrReqFifos[0];
   let keyRd_ddrReqs = ddrReqFifos[1];
   let hdrWr_ddrReqs = ddrReqFifos[2];
   let keyWr_ddrReqs = ddrReqFifos[3];
   
   /* dram resp fifos */
   //Vector#(2, FIFO#(Bit#(512))) ddrRespFifos <- replicateM(mkFIFO);
   Vector#(2, FIFO#(Bit#(512))) ddrRespFifos <- replicateM(mkSizedFIFO(32));
   let hdrRd_ddrResps = ddrRespFifos[0];
   let keyRd_ddrResps = ddrRespFifos[1];

   
   Vector#(4, FIFO#(DRAMReq)) ddrCmdQs <- replicateM(mkFIFO());
   FIFO#(Bit#(2)) selQ <- mkFIFO();
   
   FIFOF#(DRAMReq) dramCmdQ <- mkFIFOF;
   FIFO#(Bit#(1)) tagQ <- mkSizedFIFO(32);
   FIFO#(Bit#(512)) dramDataQ <- mkSizedFIFO(32);
   
   FIFO#(Bit#(8)) reqIdQ <- mkSizedFIFO(numStages);

   
   
   //ScoreboardIfc#(8) sb <- mkScoreboard;
   ScoreboardIfc#(NUM_STAGES) sb <- mkScoreboard;
   
   //* arbitration things *
   
   Vector#(4, PulseWire) grant_vector <- replicateM(mkPulseWire);
   
   //////////read header rules///////////
   //Reg#(Bool) busy_hdrRd <- mkReg(False);
   
   Reg#(Bit#(32)) reqCnt_hdrRd <- mkReg(0);
   FIFOF#(Bit#(32)) reqMax_hdrRdQ <- mkFIFOF();
   //FIFOF#(Bit#(32)) reqMax_hdrRdQ <- mkBypassFIFOF();
   
   
   
   rule doStart_hdrRd;
      let v = hdrRd_reqs.first();
      let hv = tpl_1(v);
      let numReqs = tpl_3(v);
      
      sb.hdrRequest(hv);
      
   endrule
  
   rule doStart_hdrRd_1 (reqMax_hdrRdQ.notFull);
      let v = hdrRd_reqs.first();
      let hv = tpl_1(v);
      let numReqs = tpl_3(v);
  
      let val = sb.hdrGrant();
      //$display("hdrRequest get grant is valid =%b, idx = %d", isValid(val), fromMaybe(?,val));
      if ( isValid(val) ) begin
         let idx = fromMaybe(?, val);
         reqIdQ.enq(extend(idx));
         sb.insert(hv, idx);
         reqMax_hdrRdQ.enq(numReqs);
         hdrRd_reqs.deq;
      end
   endrule
      
      
   rule issueCmd_hdrRd if (hdrRd_ddrReqs.notEmpty && reqMax_hdrRdQ.notEmpty);
      arbiter.clients[0].request();
   endrule
   
   rule issueCmd_hdrRd_1 if (grant_vector[0]);
      let args <- toGet(ddrReqFifos[0]).get();
      //dramCmdQ.enq(DRAMReq{rnw:args.rnw, addr: args.addr, data: args.data, numBytes: args.numBytes});
      //tagQ.enq(0);
      ddrCmdQs[0].enq(DRAMReq{rnw:args.rnw, addr: args.addr, data: args.data, numBytes: args.numBytes});
      selQ.enq(0);
      
      let reqMax_hdrRd = reqMax_hdrRdQ.first();
      if ( reqCnt_hdrRd + 1 >= reqMax_hdrRd ) begin
         reqMax_hdrRdQ.deq();
         reqCnt_hdrRd <= 0;
      end
      else begin
         reqCnt_hdrRd <= reqCnt_hdrRd + 1;
      end
   endrule
   
   //////////read key rules///////////
   
   Reg#(Bit#(32)) reqCnt_keyRd <- mkReg(0);
   Reg#(Bit#(32)) reqCnt_keyWr <- mkReg(0);
   
   FIFO#(Tuple2#(Bit#(32),Bit#(8))) currCmd_keyRd <- mkFIFO();
   FIFO#(Bit#(32)) reqMax_keyRdQ <- mkFIFO();

   //FIFO#(Tuple2#(Bit#(32),Bit#(8))) currCmd_keyRd <- mkBypassFIFO();
   //FIFO#(Bit#(32)) reqMax_keyRdQ <- mkBypassFIFO();
   
   rule doStart_keyRd;
      let v = keyRd_reqs.first();
      let hv = tpl_1(v);
      let idx = tpl_2(v);
      let numReqs = tpl_3(v);
      if (numReqs > 0) begin
         currCmd_keyRd.enq(tuple2(hv,idx));
         reqMax_keyRdQ.enq(numReqs);
      end
      keyRd_reqs.deq();
   endrule
   
   rule issueCmd_keyRd if (keyRd_ddrReqs.notEmpty);
      let v = currCmd_keyRd.first();
      let hv = tpl_1(v);
      let idx = tpl_2(v);
      sb.keyRequest(hv, truncate(idx));
   endrule

   rule issueCmd_keyRd_1;
      //$display("sb.keyGrant() = %b, reqCnt_keyRd = %d, reqCnt_keyWr = %d",sb.keyGrant(), reqCnt_keyRd, reqCnt_keyWr);
      if (sb.keyGrant()) begin
         arbiter.clients[1].request();
      end
      else if (reqCnt_keyRd < reqCnt_keyWr) begin
         arbiter.clients[1].request();
      end
   endrule
   Reg#(Bit#(16)) reqCnt <- mkReg(8);
   rule issueCmd_keyRd_2 if (grant_vector[1]);
      let args <- toGet(ddrReqFifos[1]).get();
      $display("HtArbiter enqueuing dramReq addr=%d, reqCnt = %d", args.addr, reqCnt);
      
      //dramCmdQ.enq(DRAMReq{rnw:args.rnw, addr: args.addr, data: args.data, numBytes: args.numBytes});
      //tagQ.enq(1);
      ddrCmdQs[1].enq(DRAMReq{rnw:args.rnw, addr: args.addr, data: args.data, numBytes: args.numBytes});
      selQ.enq(1);
     
      let reqMax_keyRd = reqMax_keyRdQ.first();
      let v = keyRd_reqs.first();
      let hv = tpl_1(v);
      let idx = tpl_2(v);
  
      if ( reqCnt_keyRd + 1 >= reqMax_keyRd ) begin
         if ((reqCnt & 15) == 15)
            reqCnt <= reqCnt + 9;
         else
            reqCnt <= reqCnt + 1;
         reqMax_keyRdQ.deq();
         currCmd_keyRd.deq();
         reqCnt_keyRd <= 0;
      end
      else begin
         reqCnt_keyRd <= reqCnt_keyRd + 1;
      end
   endrule


   //////////write header rules///////////
   
   Reg#(Bit#(32)) reqCnt_hdrWr <- mkReg(0);
   FIFO#(Bit#(32)) reqMax_hdrWrQ <- mkFIFO();
   FIFO#(Bit#(8)) idxQ_hdrWr <- mkFIFO();

   //FIFO#(Bit#(32)) reqMax_hdrWrQ <- mkBypassFIFO();
   //FIFO#(Bit#(8)) idxQ_hdrWr <- mkBypassFIFO();
   
   rule doStart_hdrWr;
      let v = hdrWr_reqs.first();
      let hv = tpl_1(v);
      let idx = tpl_2(v);
      let numReqs = tpl_3(v);
      
      reqMax_hdrWrQ.enq(numReqs);
      idxQ_hdrWr.enq(idx);
      hdrWr_reqs.deq;
   endrule
   
   rule issueCmd_hdrWr if (hdrWr_ddrReqs.notEmpty);
      arbiter.clients[2].request;
   endrule
   
   rule issueCmd_hdrWr_2 if (grant_vector[2]);
      let args <- toGet(ddrReqFifos[2]).get();
      //dramCmdQ.enq(DRAMReq{rnw:args.rnw, addr: args.addr, data: args.data, numBytes: args.numBytes});
      ddrCmdQs[2].enq(DRAMReq{rnw:args.rnw, addr: args.addr, data: args.data, numBytes: args.numBytes});
      selQ.enq(2);
      
      let idx = idxQ_hdrWr.first();
      let reqMax_hdrWr = reqMax_hdrWrQ.first();
      if ( reqCnt_hdrWr + 1 >= reqMax_hdrWr ) begin
         idxQ_hdrWr.deq();
         reqMax_hdrWrQ.deq();
         reqCnt_hdrWr <= 0;
         sb.doneHdrWrite(truncate(idx));
      end
      else begin
         reqCnt_hdrWr <= reqCnt_hdrWr + 1;
      end
   endrule
            
   //////////write key rules///////////
   
   FIFO#(Bit#(32)) reqMax_keyWrQ <- mkFIFO();
   FIFO#(Bit#(8)) idxQ_keyWr <- mkFIFO();
   
   //FIFO#(Bit#(32)) reqMax_keyWrQ <- mkBypassFIFO();
   //FIFO#(Bit#(8)) idxQ_keyWr <- mkBypassFIFO();
   
   
   rule doStart_keyWr;
      let v = keyWr_reqs.first();
      let hv = tpl_1(v);
      let idx = tpl_2(v);
      let numReqs = tpl_3(v);
      
      //$display("doStart_keyWr, hv = %h, idx = %d, numReqs = %d", hv, idx, numReqs);
      if (numReqs > 0) begin
         reqMax_keyWrQ.enq(numReqs);
         idxQ_keyWr.enq(idx);
      end
      else begin
         sb.doneKeyWrite(truncate(idx));
      end
      keyWr_reqs.deq;
   endrule
   
   rule issueCmd_keyWr if (keyWr_ddrReqs.notEmpty);
      //$display("here");
      arbiter.clients[3].request;
   endrule
   
   rule issueCmd_keyWr_2 if (grant_vector[3]);
      let args <- toGet(ddrReqFifos[3]).get();
      //dramCmdQ.enq(DRAMReq{rnw:args.rnw, addr: args.addr, data: args.data, numBytes: args.numBytes});
      ddrCmdQs[3].enq(DRAMReq{rnw:args.rnw, addr: args.addr, data: args.data, numBytes: args.numBytes});
      selQ.enq(3);
      
      let v = keyWr_ddrReqs.first;
      let idx = idxQ_keyWr.first;
      let reqMax_keyWr = reqMax_keyWrQ.first();
      //$display("issueCmd_keyWr_2, idx = %d, reqCnt_keyWr = %d, keyMax_keyWr = %d", idx, reqCnt_keyWr, reqMax_keyWr);
      if ( reqCnt_keyWr + 1 >= reqMax_keyWr ) begin
         idxQ_keyWr.deq();
         reqMax_keyWrQ.deq();
         reqCnt_keyWr <= 0;
         sb.doneKeyWrite(truncate(idx));
      end
      else begin
         reqCnt_keyWr <= reqCnt_keyWr + 1;
      end
   endrule
            
   /*
   for (Integer i = 0; i < 4; i = i + 1) begin
      rule doRequest if (ddrReqFifos[i].notEmpty);
         arbiter.clients[i].request;
      endrule
   end
   */
   /*
   rule doGrant;
      let grant = arbiter.grant_id;
      let args <- toGet(ddrReqFifos[grant]).get;
      grant_vector[grant].send();
      $display("\x1b[31m(%t)HtArbiter issue request from %d\x1b[0m", $time, grant);
      dramCmdQ.enq(DRAMReq{rnw:args.rnw, addr: args.addr, data: args.data, numBytes: args.numBytes});
      if (args.rnw)
         tagQ.enq(truncate(grant));
      
   endrule
   */
   
   rule doDDRCmd;
      let sel <- toGet(selQ).get();
      let args <- toGet(ddrCmdQs[sel]).get();
      dramCmdQ.enq(args);
      if (args.rnw)
         tagQ.enq(truncate(sel));
   endrule
      
   
   for ( Integer i = 0; i < 4; i = i + 1) begin
      rule doDDRReq if ( arbiter.grant_id == fromInteger(i) );
         let grant = arbiter.grant_id;
         //if ( grant == fromInteger(i)) begin
         grant_vector[i].send();
         /*
         let args <- toGet(ddrReqFifos[i]).get();
         $display("\x1b[31m(%t)HtArbiter issue request from %d\x1b[0m", $time, grant);
         dramCmdQ.enq(DRAMReq{rnw:args.rnw, addr: args.addr, data: args.data, numBytes: args.numBytes});
         if (args.rnw)
            tagQ.enq(truncate(grant));
         //end
          */
      endrule
   end
      
         
      
   /*rule dereturn;
      let tag <- toGet(tagQ).get;
      ddrRespFifos[tag].enq(0);
   endrule*/
   /*
   rule doRecv;
      let data <- toGet(dramDataQ).get;
      let tag <- toGet(tagQ).get;
      ddrRespFifos[tag].enq(data);
   endrule
   */
   
   for (Integer i = 0; i < 2; i = i + 1) begin
      rule doDDRResp if ( tagQ.first() == fromInteger(i));
         //let tag = tagQ.first();
         let data = dramDataQ.first();
         //if ( tag == fromInteger(i)) begin
         tagQ.deq();
         dramDataQ.deq();
         //$display("ddrRespFifo[%d] enqueuing data = %h", i, data);
         ddrRespFifos[i].enq(data);
         //end
      endrule
   end
         
   FIFOF#(DRAMReq) hdrUpdDRAMReqQ <- mkBypassFIFOF;
   FIFO#(Bool) hdrUpdRespQ <- mkFIFO;
   
   FIFO#(DRAMReq) dramReqQ <- mkFIFO;
   Vector#(2, FIFOF#(DRAMReq)) dramReqQs;
   dramReqQs[0] = dramCmdQ;
   dramReqQs[1] = hdrUpdDRAMReqQ;
   
   Arbiter_IFC#(2) arbiter <- myArbiter#(False);
   for ( Integer i = 0; i < 2; i = i + 1) begin
      rule doReq if ( dramReqQs.notFull );
         arbiters.clients[i].request();
      endrule
      
      rule doReq_1 if (arbiter.clients[i].grant);
         let v <- toGet(dramReqQs[i]).get();
         dramReqQ.enq(v);
         if ( i = 1 ) hdrUpdRespQ.enq(True);
      endrule
   end
      
   
   interface DRAMReadIfc hdrRd;
      method Action start(Bit#(32) hv, Bit#(8) idx, Bit#(32) numReqs);
         hdrRd_reqs.enq(tuple3(hv, idx, numReqs));
      endmethod
      method ActionValue#(Bit#(8)) getReqId();
         let v <- toGet(reqIdQ).get();
         return v;
      endmethod
      interface Put request = toPut(hdrRd_ddrReqs);
      interface Get response = toGet(hdrRd_ddrResps);
   endinterface
  
   interface DRAMReadIfc keyRd;
      method Action start(Bit#(32) hv, Bit#(8) idx, Bit#(32) numReqs);
         keyRd_reqs.enq(tuple3(hv, idx, numReqs));
      endmethod
      method ActionValue#(Bit#(8)) getReqId();
         return ?;
      endmethod
      interface Put request = toPut(keyRd_ddrReqs);
      interface Get response = toGet(keyRd_ddrResps);
   endinterface
   
   interface DRAMWriteIfc hdrWr;
      method Action start(Bit#(32) hv, Bit#(8) idx, Bit#(32) numReqs);
         hdrWr_reqs.enq(tuple3(hv, idx, numReqs));
      endmethod
      interface Put request = toPut(hdrWr_ddrReqs);
   endinterface
      
   interface DRAMWriteIfc keyWr;
      method Action start(Bit#(32) hv, Bit#(8) idx, Bit#(32) numReqs);
         keyWr_reqs.enq(tuple3(hv, idx, numReqs));
      endmethod
      interface Put request = toPut(keyWr_ddrReqs);
   endinterface
  
   interface DRAMClient dramClient;
      interface Get request = toGet(dramReqQ);
      interface Put response = toPut(dramDataQ);
   endinterface

   interface Server hdrUpdServer;
      interface Put request = toPut(hdrUpdDRAMReqQ);
      interface Get response = toGet(hdrUpdRespQ);
   endinterface
endmodule


endpackage
