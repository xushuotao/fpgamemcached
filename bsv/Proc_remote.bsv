import FIFO::*;
import FIFOF::*;
import BRAMFIFO::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;


import ProtocolHeader::*;

import RequestSplit::*;

import JenkinsHash::*;
import HashtableTypes::*;
import Hashtable::*;
import Valuestr::*;
import Time::*;
import DRAMArbiter::*;
import DRAMController::*;
import MyArbiter::*;
//import MemcachedServer::*;

import ParameterTypes::*;

`ifndef BSIM
import AuroraEndpointHelper::*;
`else
import AuroraEndpointHelper_Verifier::*;
`endif
import ProcTypes::*;

//interface ProcIfc;
//   interface Put request;

import DMAHelper::*;



interface MemServerIfc;
   interface Put#(Bit#(64)) request;// = toPut(reqs);
   interface Get#(Bit#(64)) response;// = toGet(resps);
endinterface
         

interface MemCachedIfc;
   //method Action start(Protocol_Binary_Request_Header cmd);
   method Action start(Protocol_Binary_Request_Header cmd, Bit#(32) rp, Bit#(32) wp, Bit#(64) nBytes, Bit#(32) id);
   //method ActionValue#(Protocol_Binary_Response_Header) done();
   method ActionValue#(Tuple2#(Protocol_Binary_Response_Header,Bit#(32))) done();
   //method Action start(Bit#(ReqHeaderSz) cmd);
   //method ActionValue#(Bit#(RespHeaderSz)) done();
   interface MemServerIfc server;
   interface HashtableInitIfc htableInit;
   interface ValInit_ifc valInit;
   method Action setNetId(Bit#(32) netId);
endinterface

module mkMemCached#(DRAMControllerIfc dram, DMAReadIfc rdIfc, DMAWriteIfc wrIfc, RemoteIfc auroraIfc)(MemCachedIfc);
   Reg#(Bit#(32)) myNetId <- mkRegU();
   Reg#(Bool) init <- mkReg(False);
   

   let splitter <- mkReqSplit(rdIfc, auroraIfc.requestPort.recvPort);
   FIFO#(Bit#(64)) resps <- mkFIFO;   
   
   
   /***********Processing Reqs************/
   
   DRAMArbiterIfc#(3) arbiter <- mkDRAMArbiter;
   
   let clk <- mkLogicClock;
   
   //let valstr_acc <- mkValRawAccess(clk, dram);
   let valstr_acc <- mkValRawAccess;//(clk);
   
   //let valstr_mng <- mkValManager(dram);
   let valstr_mng <- mkValManager;
   
   //let htable <- mkAssocHashtb(dram, clk, valstr_mng.valAlloc);
   let htable <- mkAssocHashtb(clk, valstr_mng.valAlloc);
   
   let hash <- mkJenkinsHash;
   
   
   mkConnection(htable.dramClient, arbiter.dramServers[0]);
   mkConnection(valstr_acc.dramClient, arbiter.dramServers[1]);
   mkConnection(valstr_mng.dramClient, arbiter.dramServers[2]);
   
   mkConnection(arbiter.dramClient, dram);
  
   FIFO#(Bit#(64)) keyBuf <- mkSizedBRAMFIFO(512);
   
   
   FIFO#(MemcacheReqType) hash2table <- mkSizedFIFO(numStages);
   FIFO#(Tuple2#(MemcacheReqType,Bool)) table2valstr <- mkSizedFIFO(numStages);
   
   rule doHash;
      //let v <- toGet(cmd2hash).get();
      let v <- splitter.nextRequest.get();
      let cmd = v.header;//tpl_1(v);
      let keylen = cmd.keylen;
      $display("hash calculation is bypassed = %b", isValid(v.nodeId));
      if ( !isValid(v.nodeId)) begin
         hash.start(extend(keylen));
      end
      hash2table.enq(v);
   endrule
   
   rule key2Hash;
      //let v <- toGet(keyFifo).get();
      let v <- splitter.nextKey.get();
      $display("Memcached Get key: %h, byPass hash %b", tpl_1(v), tpl_2(v));
      if (tpl_2(v))
         hash.putKey(tpl_1(v));
      keyBuf.enq(tpl_1(v));
   endrule
   

   FIFO#(Tuple3#(Bit#(32), Bool, Bool)) keylenMaxQ <- mkSizedFIFO(numStages);
   FIFO#(Tuple2#(Bit#(64), Bool)) vallenMaxQ <- mkSizedFIFO(numStages);
   FIFO#(State_Val) val_stateQ <- mkSizedFIFO(numStages);
   
   rule doTable;
      let v <- toGet(hash2table).get();
      let cmd = v.header;//tpl_1(v);     
            
      let keylen = cmd.keylen;
      let nBytes = cmd.bodylen - extend(cmd.keylen);
      Bit#(32) hv;
      
      let toRemote = False;
      
      if (isValid(v.nodeId)) begin
         hv = v.hv;
      end
      else begin
         hv <- hash.getHash();
         let netId = hv&32'b1;
         if ( myNetId == 0) begin
            $display("Sending hashtable request to a remote node");
            
            auroraIfc.requestPort.sendPort.sendCmd(MemReqType{opcode:cmd.opcode, keylen:truncate(cmd.keylen), vallen: truncate(nBytes), hv: hv}, 1);
            
            toRemote = True;
         end
      end
         
      $display("Memcached Calc hash val:%h", hv);
      

      if ( !toRemote ) begin
         $display("Memached accessing hashtable, keylen = %d, nBytes = %d, hv = %d", keylen, nBytes, hv);
         Bool rnw = False;
         if (cmd.opcode == PROTOCOL_BINARY_CMD_GET)
            rnw = True;
         htable.readTable(truncate(keylen), hv, extend(nBytes), rnw);
         //val_stateQ.enq(DoVal);
      end
      /*else begin
         //val_stateQ.enq(DoRemote);
      end*/
      
      $display("table2valstr v.nodeId is valid = ?????? %b", isValid(v.nodeId));
      table2valstr.enq(tuple2(v, toRemote));
      
      Bool routeVals = False;
      
      if ( cmd.opcode == PROTOCOL_BINARY_CMD_SET ) begin
         vallenMaxQ.enq(tuple2(extend(nBytes), toRemote));
         routeVals = True;
      end
      
      keylenMaxQ.enq(tuple3(extend(keylen), toRemote, routeVals));
   endrule
   
   Reg#(Bit#(32)) lenCnt <- mkReg(0);
   
   Reg#(Bool) routeKeys <- mkReg(True);
   rule key2Table (routeKeys);
      let v = keylenMaxQ.first();
      let lenMax = tpl_1(v);
      let toRemote = tpl_2(v);
      let routeVals = tpl_3(v);
      if (lenCnt + 8 >= lenMax) begin
         keylenMaxQ.deq();
         lenCnt <= 0;
         routeKeys <= !routeVals;
         $display("Server:: key2Table reset, routeKeys == %d", !routeVals);
      end
      else begin
         lenCnt <= lenCnt + 8;
      end
      let d <- toGet(keyBuf).get();
      if (toRemote) begin
         $display("Server:: sending the keys to remote, value = %h, cnt = %d, cntMax = %d", d, lenCnt, lenMax);
         auroraIfc.requestPort.sendPort.inPipe.put(d);
      end
      else begin
         $display("Server:: sening the keys to local htable, value = %h, cnt = %d, cntMax = %d", d, lenCnt, lenMax);
         htable.keyTokens(d);
      end
   endrule
   
   Reg#(Bit#(64)) valcnt <- mkReg(0);
   rule val2Valstr (!routeKeys);
      let v = vallenMaxQ.first();
      let valMax = tpl_1(v);
      let toRemote = tpl_2(v);
      if ( valcnt + 8 >= valMax ) begin
         vallenMaxQ.deq();
         valcnt <= 0;
         routeKeys <= True;
      end
      else begin
         valcnt <= valcnt + 8;
      end
      
      //let d <- toGet(valFifo).get();
      let d <- splitter.nextVal.get();
      if (toRemote) begin
         $display("Server:: sending Val to Remote Node, value = %h, valCnt = %d, valCntMax = %d", d, valcnt, valMax);
         auroraIfc.requestPort.sendPort.inPipe.put(d);
      end
      else begin
         $display("Server:: Received Data = %h", v);
         valstr_acc.writeVal(d);
      end
   endrule
   
   
   FIFO#(MemcacheRespType) respHeaderQ <- mkSizedFIFO(numStages);
   FIFO#(Bit#(64)) respDataQ <- mkFIFO;

   Reg#(Bit#(16)) reqCnt <- mkReg(0);
   
   Reg#(State_Val) val_state <- mkReg(Idle);
   
   /*rule doState if (val_state == Idle);
      let v <- toGet(val_stateQ).get();
      val_state <= v;
   endrule*/
   
   
   
   Reg#(Tuple2#(MemcacheReqType,Bool)) buff <- mkRegU();
   rule waitRemote if ( tpl_2(table2valstr.first()) );// if (val_state == DoRemote);

      let dd <- toGet(table2valstr).get();
         
      $display("send remote thing hears back from other queue");
      let d = tpl_1(dd);
      let vv <- auroraIfc.responsePort.recvPort.recvCmd;
      let cmd = tpl_1(vv);
      let nodeid = tpl_2(vv);
      
      respHeaderQ.enq(MemcacheRespType{header: Protocol_Binary_Response_Header{magic: PROTOCOL_BINARY_RES,
                                                                               opcode: cmd.opcode,
                                                                               keylen: 0,
                                                                               extlen: 0,
                                                                               datatype: 0,
                                                                               status: PROTOCOL_BINARY_RESPONSE_SUCCESS,
                                                                               bodylen: extend(cmd.vallen),
                                                                               opaque: 0,
                                                                               cas: 0
                                                                               },
                                       reqId:d.reqId,
                                       nodeId:d.nodeId,
                                       fromRemote:True});
      if ( cmd.opcode == PROTOCOL_BINARY_CMD_GET && cmd.vallen > 0)
         wrIfc.writeReq(d.wp, extend(cmd.vallen));
      

      //val_state <= Idle;
   endrule
   
   rule doVal if (!tpl_2(table2valstr.first()));// if (val_state == DoVal);
      $display("remote node do val");
      val_state <= Idle;
      let d <- toGet(table2valstr).get();
      let vv = tpl_1(d);
      let toRemote = tpl_2(d);
      let cmd = vv.header;//tpl_1(vv);
      let wp = vv.wp;//tpl_2(vv);
      let id = vv.reqId;//tpl_3(vv);
      let isLocal = !isValid(vv.nodeId);
      
      let opcode = cmd.opcode;
      let v <- htable.getValAddr();
      
      //let addr = tpl_1(v);
      //let nBytes = tpl_2(v);
      //let success = tpl_3(v);
      let addr = v.addr;
      let nBytes = v.nBytes;
      let success = v.hit;
      let hv = v.hv;
      let idx = v.idx;
      
      let respBytes = nBytes; 
      $display("doVal: opcode = %h, addr = %d, nBytes = %d, nodeId is valid = %b", opcode, addr, nBytes, isValid(vv.nodeId));
      
      reqCnt <= reqCnt + 1;
      Protocol_Binary_Response_Status responseCode = ?; 
      if (success) begin
         responseCode = PROTOCOL_BINARY_RESPONSE_SUCCESS;
         if (opcode == PROTOCOL_BINARY_CMD_GET) begin
            $display("doVal: Get Cmd, reqCnt = %d", reqCnt);
            valstr_acc.readReq(addr, nBytes);
            if ( isLocal )
               wrIfc.writeReq(wp, nBytes);
         end
         else if (opcode == PROTOCOL_BINARY_CMD_SET) begin
            $display("doVal: Set Cmd, reqCnt = %d", reqCnt);
            valstr_acc.writeReq(addr, nBytes, hv, idx);
            respBytes = 0;
         end 
      end
      else begin
         responseCode = PROTOCOL_BINARY_RESPONSE_KEY_EEXISTS;
         respBytes = 0;
         //$finish;
         $display("doVal: Keys not found in htable, reqCnt = %d", reqCnt);
      end
      
      //if ( !isLocal ) begin
      respHeaderQ.enq(MemcacheRespType{header: Protocol_Binary_Response_Header{magic: PROTOCOL_BINARY_RES,
                                                                               opcode: cmd.opcode,
                                                                               keylen: 0,
                                                                               extlen: 0,
                                                                               datatype: 0,
                                                                               status: responseCode,
                                                                               bodylen: truncate(respBytes),
                                                                               opaque: 0,
                                                                               cas: 0
                                                                               },
                                       reqId:id,
                                       nodeId:vv.nodeId,
                                       fromRemote:False});
     // end
      //else begin
        // auroraIfc.responsePort.sendPort.send
      //val_state <= Idle;
   endrule
   
   
   rule doVal_3;
      let v <- valstr_acc.readVal();
      //$display("Valstr received val = %h", v);
      respDataQ.enq(v);
   endrule
   
   /*****output streaming processing******/
   //Reg#(State_Output) state_output <- mkReg(Idle);
   
  // Reg#(Bit#(64)) vallen_reg_Resp <- mkRegU();
   Reg#(Bit#(64)) val_cnt_Resp <- mkReg(0);

  // Reg#(Bool) localResp_flag <- mkReg(True);
   FIFO#(Tuple2#(Protocol_Binary_Response_Header, Bit#(32))) doneQ <- mkFIFO();
   
  // Reg#(Bool) frRemote <- mkRegU();
   
   FIFO#(Tuple3#(Bit#(64), Bool, Bool)) procValQ <- mkSizedFIFO(numStages);
   rule idle_resp;// if (state_output == Idle);
      
      let d <- toGet(respHeaderQ).get();
      let remote = d.fromRemote;
      let cmd = d.header;//tpl_1(v);
      let isLocal = !isValid(d.nodeId);
      //localResp_flag <= isLocal;

      $display("Process output, state == Idle, opcode = %h", cmd.opcode);      
      if ( isLocal ) begin
         doneQ.enq(tuple2(cmd,d.reqId));
      end
      else begin
         $display("sending response back to sender");
         let node = fromMaybe(?, d.nodeId);
         auroraIfc.responsePort.sendPort.sendCmd(MemReqType{opcode: cmd.opcode, vallen: truncate(cmd.bodylen)-extend(cmd.keylen)}, node);
      end
      
      if (cmd.opcode == PROTOCOL_BINARY_CMD_GET) begin
         /*
         state_output <= ProcVals;
    
         val_cnt_Resp <= 0;
         vallen_reg_Resp <= extend(cmd.bodylen - extend(cmd.keylen));
      
         frRemote <= remote;
         */
         procValQ.enq(tuple3(extend(cmd.bodylen - extend(cmd.keylen)), isLocal, remote));
      end
   endrule
  
   
   rule procVal_resp;// if (state_output == ProcVals);
      let args = procValQ.first;
      let vallen_reg_Resp = tpl_1(args);
      let localResp_flag = tpl_2(args);
      let frRemote = tpl_3(args);
     
      if ( vallen_reg_Resp > 0 ) begin
         Bit#(64) v = ?;
         if (frRemote) begin
            let v <- auroraIfc.responsePort.recvPort.outPipe.get();
            $display("Response Port Remote Node d = %h, val_cnt = %d, val_cnt_max = %d", v, val_cnt_Resp, vallen_reg_Resp);
            //v = tpl_1(d);
         end
         else
            v <- toGet(respDataQ).get();
         
         if (localResp_flag)
            resps.enq(v);
         else
            auroraIfc.responsePort.sendPort.inPipe.put(v);
      end
      else begin
         $display("Here I just got a miss");
      end
      
      //$display("Trying to put data into MemEngs, data = %h", v);
      if ( val_cnt_Resp + 8 >= vallen_reg_Resp) begin
         //state_output <= Idle;
         val_cnt_Resp <= 0;
         procValQ.deq();
      end
      else begin
         val_cnt_Resp <= val_cnt_Resp + 8;
      end
   endrule

   Reg#(Bit#(16)) reqCnt_done <- mkReg(0);
   
   method Action start(Protocol_Binary_Request_Header cmd, Bit#(32) rp, Bit#(32) wp, Bit#(64) nBytes, Bit#(32) id) if (init);
      splitter.localRequest.put(MemcacheReqType{header: cmd, rp: rp, wp: wp, nBytes: nBytes, reqId: id, nodeId: Invalid});
   endmethod
   
   method ActionValue#(Tuple2#(Protocol_Binary_Response_Header,Bit#(32))) done();
      //   method ActionValue#(Bit#(RespHeaderSz)) done();
      $display("request done: reqCnt = %d", reqCnt_done);
      reqCnt_done <= reqCnt_done + 1;
      let v <- toGet(doneQ).get();
      $display("Memcached doneQ dequeued");
      let cmd = tpl_1(v);
      if (cmd.opcode == PROTOCOL_BINARY_CMD_GET && cmd.bodylen - extend(cmd.keylen) > 0)
         wrIfc.done();
      return v;
   endmethod
      
   
   interface MemServerIfc server;
      interface Put request = splitter.inPipe;//toPut(reqs);
      interface Get response = toGet(resps);
   endinterface
   
   interface ValInit_ifc valInit = valstr_mng.valInit;
   
   interface HashtableInitIfc htableInit = htable.init;
   
   method Action setNetId(Bit#(32) netId);
      myNetId <= netId;
      init <= True;
   endmethod

   
endmodule
