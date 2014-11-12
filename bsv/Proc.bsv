import ProtocolHeader::*;

import JenkinsHash::*;
import Hashtable::*;
import Valuestr::*;
import Time::*;
import DRAMController::*;
//import MemcachedServer::*;
import FIFO::*;
import BRAMFIFO::*;
import Vector::*;

import GetPut::*;
import ClientServer::*;
import Connectable::*;

//interface ProcIfc;
//   interface Put request;

import DMAHelper::*;

typedef enum{Idle, ProcKeys, ProcVals} State_Input deriving (Eq, Bits);
typedef enum{Idle, ProcVals} State_Output deriving (Eq, Bits); 
//typedef Server#(Bit#(64), Bit#(64)) MemServer;

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
endinterface

module mkMemCached#(DRAMControllerIfc dram, DMAReadIfc rdIfc, DMAWriteIfc wrIfc)(MemCachedIfc);
   
   
   /*****input streaming processing******/
   FIFO#(Tuple3#(Protocol_Binary_Request_Header, Bit#(32), Bit#(32))) reqHeaderQ <- mkFIFO();
   FIFO#(Bit#(64)) reqs <- mkFIFO;
   FIFO#(Bit#(64)) resps <- mkFIFO;
   
   Reg#(State_Input) state_input <- mkReg(Idle);
   
   Reg#(Protocol_Binary_Command) opcode_reg <- mkRegU();
   
   Reg#(Bit#(32)) keylen_reg <- mkRegU();
   Reg#(Bit#(32)) key_cnt <- mkReg(0);
   
   Reg#(Bit#(64)) vallen_reg <- mkRegU();
   Reg#(Bit#(64)) val_cnt <- mkReg(0);
   
   
   
   FIFO#(Tuple3#(Protocol_Binary_Request_Header, Bit#(32), Bit#(32))) cmd2hash <- mkFIFO();
   FIFO#(Bit#(64)) keyFifo <- mkFIFO;
   FIFO#(Bit#(64)) valFifo <- mkFIFO;

   rule procHeader if (state_input == Idle);
      let v <- toGet(reqHeaderQ).get();
      
      let header = tpl_1(v);
      
      state_input <= ProcKeys;
         
      cmd2hash.enq(v);
      
      let keylen = header.keylen;
      
      let bodylen = header.bodylen;
      
      key_cnt <= 0;
      val_cnt <= 0;
         
      opcode_reg <= header.opcode;
      keylen_reg <= extend(keylen);
      vallen_reg <= extend(bodylen) - extend(keylen);
   endrule
      
   rule procKey if (state_input == ProcKeys);
      let word <- toGet(reqs).get();
      keyFifo.enq(word);
      if ( key_cnt + 8 >=  keylen_reg ) begin
         if (opcode_reg == PROTOCOL_BINARY_CMD_SET) begin
            state_input <= ProcVals;
         end
         else begin
            state_input <= Idle;
         end
      end
      key_cnt <= key_cnt + 8;
   endrule
   
   rule procVal if (state_input == ProcVals);
      $display("procVals");
      let word <- toGet(reqs).get();
      valFifo.enq(word);
      if ( val_cnt + 8 >= vallen_reg) begin
         state_input <= Idle;
      end
      val_cnt <= val_cnt + 8;
   endrule
   
   
   /***********Processing Reqs************/
   
   let clk <- mkLogicClock;
   
   let valstr_acc <- mkValRawAccess(clk, dram);
   
   let valstr_mng <- mkValManager(dram);
   
   let htable <- mkAssocHashtb(dram, clk, valstr_mng.valAlloc);
   
   let hash <- mkJenkinsHash;
  
   FIFO#(Bit#(64)) keyBuf <- mkSizedBRAMFIFO(32);
   
   
   FIFO#(Tuple3#(Protocol_Binary_Request_Header, Bit#(32), Bit#(32))) hash2table <- mkFIFO;
   FIFO#(Tuple3#(Protocol_Binary_Request_Header, Bit#(32), Bit#(32))) table2valstr <- mkFIFO;
   
   rule doHash;
      let v <- toGet(cmd2hash).get();
      let cmd = tpl_1(v);
      let keylen = cmd.keylen;
      hash.start(extend(keylen));
      hash2table.enq(v);
   endrule
   
   rule key2Hash;
      let v <- toGet(keyFifo).get();
      $display("Memcached Get key: %h", v);
      hash.putKey(v);
      keyBuf.enq(v);
   endrule
   
   rule doTable;
      let v <- toGet(hash2table).get();
      let cmd = tpl_1(v);
      
      table2valstr.enq(v);
      
      let keylen = cmd.keylen;
      let nBytes = cmd.bodylen - extend(cmd.keylen);
      let hv <- hash.getHash();
      $display("Memcached Calc hash val:%h", hv);
      
      htable.readTable(truncate(keylen), hv, extend(nBytes));
   endrule
   
   rule key2Table;
      let v <- toGet(keyBuf).get();
      htable.keyTokens(v);
   endrule
   
   
   FIFO#(Tuple2#(Protocol_Binary_Response_Header, Bit#(32))) respHeaderQ <- mkFIFO;
   FIFO#(Bit#(64)) respDataQ <- mkFIFO;
      
   rule doVal;
      let vv <- toGet(table2valstr).get();
      let cmd = tpl_1(vv);
      let wp = tpl_2(vv);
      let id = tpl_3(vv);
      
      let opcode = cmd.opcode;
      let v <- htable.getValAddr();
      
      let addr = tpl_1(v);
      let nBytes = tpl_2(v);
      
      $display("doVal: opcode = %h, addr = %d, nBytes = %d", opcode, addr, nBytes);
      
      if (opcode == PROTOCOL_BINARY_CMD_GET) begin
         $display("doVal: Get Cmd");
         valstr_acc.readReq(addr, nBytes);
         wrIfc.writeReq(wp, nBytes);
      end
      else if (opcode == PROTOCOL_BINARY_CMD_SET) begin
         $display("doVal: Set Cmd");
         valstr_acc.writeReq(addr, nBytes);
         //wrIfc.writeReq(wp,);
      end 
      
      respHeaderQ.enq(tuple2(Protocol_Binary_Response_Header{magic: PROTOCOL_BINARY_RES,
                                                             opcode: cmd.opcode,
                                                             keylen: 0,
                                                             extlen: 0,
                                                             datatype: 0,
                                                             status: PROTOCOL_BINARY_RESPONSE_SUCCESS,
                                                             bodylen: truncate(nBytes),
                                                             opaque: 0,
                                                             cas: 0
                                                             },id));
      
   endrule
   
      
   rule doVal_2;
      let v <- toGet(valFifo).get();
      $display("Server:: Received Data = %h", v);
      valstr_acc.writeVal(v);
   endrule
   
   rule doVal_3;
      let v <- valstr_acc.readVal();
      respDataQ.enq(v);
   endrule
   
   /*****output streaming processing******/
   Reg#(State_Output) state_output <- mkReg(Idle);
   
   Reg#(Bit#(64)) vallen_reg_Resp <- mkRegU();
   Reg#(Bit#(64)) val_cnt_Resp <- mkReg(0);


   FIFO#(Tuple2#(Protocol_Binary_Response_Header, Bit#(32))) doneQ <- mkFIFO();
   rule idle_resp if (state_output == Idle);
      
      let v <- toGet(respHeaderQ).get();
      let cmd = tpl_1(v);
      $display("Process output, state == Idle, opcode = %h", cmd.opcode);
      doneQ.enq(v);
      if (cmd.opcode == PROTOCOL_BINARY_CMD_GET)
         state_output <= ProcVals;
    
      val_cnt_Resp <= 0;
      vallen_reg_Resp <= extend(cmd.bodylen - extend(cmd.keylen));
   endrule
  
   rule procVal_resp if (state_output == ProcVals);
      let v <- toGet(respDataQ).get();
      resps.enq(v);
      if ( val_cnt_Resp + 8 >= vallen_reg_Resp) begin
         state_output <= Idle;
      end
      val_cnt_Resp <= val_cnt_Resp + 8;
   endrule
      
   
   method Action start(Protocol_Binary_Request_Header cmd, Bit#(32) rp, Bit#(32) wp, Bit#(64) nBytes, Bit#(32) id);
 //  method Action start(Bit#(ReqHeaderSz) cmd);
      reqHeaderQ.enq(tuple3(cmd, wp, id));
      rdIfc.readReq(rp, nBytes);
   endmethod
   
   method ActionValue#(Tuple2#(Protocol_Binary_Response_Header,Bit#(32))) done();
//   method ActionValue#(Bit#(RespHeaderSz)) done();
      let v <- toGet(doneQ).get();
      $display("Memcached doneQ dequeued");
      let cmd = tpl_1(v);
      if (cmd.opcode == PROTOCOL_BINARY_CMD_GET)
         wrIfc.done();
      return v;
   endmethod
      
   
   interface MemServerIfc server;
      interface Put request = toPut(reqs);
      interface Get response = toGet(resps);
   endinterface
   
   interface ValInit_ifc valInit = valstr_mng.valInit;
   
   interface HashtableInitIfc htableInit = htable.init;
endmodule
