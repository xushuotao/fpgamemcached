
import FIFO::*;
import FIFOF::*;
import Arbiter::*;
import GetPut::*;
import Vector::*;
import DMAHelper::*;
import ProtocolHeader::*;
import BRAMFIFO::*;


`ifndef BSIM
import AuroraEndpointHelper::*;
`else
import AuroraEndpointHelper_Verifier::*;
`endif

import MyArbiter::*;
import ProcTypes::*;

interface SplitIfc;
   //interface Put#(MemcacheReqType) remoteRequest;
   interface Put#(MemcacheReqType) localRequest;
   interface Put#(Bit#(64)) inPipe;
   interface Get#(MemcacheReqType) nextRequest;
   interface Get#(Tuple2#(Bit#(64),Bool)) nextKey;
   interface Get#(Bit#(64)) nextVal;
endinterface


module mkReqSplit#(DMAReadIfc rdIfc, RecvPort recvPort)(SplitIfc);
   Vector#(2,FIFOF#(MemcacheReqType)) reqHeaderQs <- replicateM(mkFIFOF);
   let localHeaderQ = reqHeaderQs[0];
   let remoteHeaderQ = reqHeaderQs[1];
   /*****input streaming processing******/

   FIFO#(Bit#(64)) reqs <- mkFIFO;
   //FIFO#(Bit#(64)) resps <- mkFIFO;
   
   Reg#(State_Input) state_input <- mkReg(ProcKeys);
   
   Reg#(Protocol_Binary_Command) opcode_reg <- mkReg(PROTOCOL_BINARY_CMD_GET);
   
   Reg#(Bit#(32)) keylen_reg <- mkReg(0);
   Reg#(Bit#(32)) key_cnt <- mkReg(0);
   
   Reg#(Bit#(64)) vallen_reg <- mkReg(0);
   Reg#(Bit#(64)) val_cnt <- mkReg(0);
   
   
   
   FIFO#(MemcacheReqType) cmd2hash <- mkFIFO();
   FIFO#(Tuple2#(Bit#(64),Bool)) keyFifo <- mkFIFO;
   
   /*1MB valFifo*/
   //FIFO#(Bit#(64)) valFifo <- mkSizedBRAMFIFO(131072);
   //FIFO#(Bit#(64)) valFifo <- mkFIFO();//mkSizedBRAMFIFO(131072);
   FIFO#(Bit#(64)) valFifo <- mkSizedBRAMFIFO(512);
   //FIFO#(Bit#(64)) valFifo <- mkSizedBRAMFIFO(65536);
   
   rule recvRemoteReq;
      let v <- recvPort.recvCmd;
      let req = tpl_1(v);
      let node = tpl_2(v);
      Protocol_Binary_Request_Header header = ?;
      header.opcode = req.opcode;
      header.keylen = extend(req.keylen);
      header.bodylen = extend(req.keylen) + extend(req.vallen);
      $display("Memached receive request from a remote node, keylen = %d, bodylen = %d", header.keylen, header.bodylen);
      
      remoteHeaderQ.enq(MemcacheReqType{header:header, rp: ?, wp: ?, nBytes:?, reqId:?, hv: req.hv, nodeId: tagged Valid node});
   endrule
      
   FIFOF#(MemcacheReqType) reqHeaderQ <- mkFIFOF;
   
   Arbiter_IFC#(2) req_arbiter <- mkArbiter(False);
    
   for ( Integer i = 0; i < 2; i = i + 1) begin
      rule doRequest if (reqHeaderQs[i].notEmpty);
         //$display("reqHeaderQ[%d] asks for grants", i);
         req_arbiter.clients[i].request;
      endrule
      
      rule doGrant (req_arbiter.grant_id == fromInteger(i));
         //$display("reqHeaderQ[%d] get grants", i);
         let v <- toGet(reqHeaderQs[i]).get();
         reqHeaderQ.enq(v);
         if ( i == 0 )
            rdIfc.readReq(v.rp, v.nBytes);
      endrule
   end
      
   
   Reg#(Bool) localReq_flag <- mkReg(True);
   rule procKey if (state_input == ProcKeys);
      if ( key_cnt + 8 >=  keylen_reg ) begin
         if (opcode_reg == PROTOCOL_BINARY_CMD_SET) begin
            state_input <= ProcVals;
         end
         else begin
            if ( reqHeaderQ.notEmpty() ) begin
               let v <- toGet(reqHeaderQ).get();

               let header = v.header;//tpl_1(v);
               //  state_input <= ProcKeys;
               cmd2hash.enq(v);
               let keylen = header.keylen;
               let bodylen = header.bodylen;
               key_cnt <= 0;
               val_cnt <= 0;
               opcode_reg <= header.opcode;
               keylen_reg <= extend(keylen);
               vallen_reg <= extend(bodylen) - extend(keylen);
               localReq_flag <= !isValid(v.nodeId);
               $display("Memcached start process request, the request is from remote ?= %b, keylen = %d, vallen = %d", !isValid(v.nodeId), keylen, bodylen - extend(keylen));
            end
            else begin
               //$display("Here!!!!");
               key_cnt <= 0;
               val_cnt <= 0;
               keylen_reg <= 0;
               vallen_reg <= 0;
               opcode_reg <= PROTOCOL_BINARY_CMD_GET;
            end
         end
      end
      else
         key_cnt <= key_cnt + 8;
      
      if ( keylen_reg > 0) begin
         Bit#(64) word;
         if ( localReq_flag ) begin
            word <- toGet(reqs).get();
         end
         else begin
            word <- recvPort.outPipe.get();
            $display("Remote Node got keys = %h, cnt = %d, cntMax = %d", word, key_cnt, keylen_reg);
         end
         keyFifo.enq(tuple2(word, localReq_flag));
      end
   endrule
   
   rule procVal if (state_input == ProcVals);
      $display("procVals");
      Bit#(64) word;
      if ( localReq_flag ) begin
         word <- toGet(reqs).get();
      end
      else begin
         word <- recvPort.outPipe.get();
         $display("Remote Node got Value = %h, cnt = %d, cntMax = %d", word, val_cnt, vallen_reg);
      end

      valFifo.enq(word);
      if ( val_cnt + 8 >= vallen_reg) begin
         //state_input <= Idle;
         if ( reqHeaderQ.notEmpty() ) begin
            let v <- toGet(reqHeaderQ).get();
            $display("Memcached start process request, the request is from remote ?= %b", !isValid(v.nodeId));
            let header = v.header;//tpl_1(v);
            //  state_input <= ProcKeys;
            cmd2hash.enq(v);
            let keylen = header.keylen;
            let bodylen = header.bodylen;
            key_cnt <= 0;
            val_cnt <= 0;
            opcode_reg <= header.opcode;
            keylen_reg <= extend(keylen);
            vallen_reg <= extend(bodylen) - extend(keylen);
            localReq_flag <= !isValid(v.nodeId);
         end
         else begin
            key_cnt <= 0;
            val_cnt <= 0;
            keylen_reg <= 0;
            vallen_reg <= 0;
            opcode_reg <= PROTOCOL_BINARY_CMD_GET;
         end
         state_input <= ProcKeys;
      end
      else
         val_cnt <= val_cnt + 8;
   endrule
   
   //interface Put remoteRequest = toPut(remoteHeaderQ);
   interface Put localRequest = toPut(localHeaderQ);
   interface Put inPipe = toPut(reqs);
   interface Get nextRequest = toGet(cmd2hash);
   interface Get nextKey = toGet(keyFifo);
   interface Get nextVal = toGet(valFifo);

   
endmodule
   
