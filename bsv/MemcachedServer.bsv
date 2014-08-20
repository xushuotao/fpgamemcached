`include "ProtocolHeader.bsv"

import JenkinsHash::*;
import Hashtable::*;
import Valuestr::*;
import Time::*;
import DRAMController::*;

import FIFO::*;
import BRAMFIFO::*;

interface ServerIndication;
   method Action ready4dta();
   method Action initRdBuf(Bit#(64) nBytes);
   method Action valData(Bit#(64) v);
   method Action hexdump(Bit#(32) v);
endinterface

interface ServerRequest;
   /*** initialize ****/
   method Action initValDelimit(Bit#(64) lgSz1, Bit#(64) lgSz2, Bit#(64) lgSz3);
   method Action initAddrDelimit(Bit#(64) lgOffset1, Bit#(64) lgOffset2, Bit#(64) lgOffset3);
   
   /*** cmd key dta request ***/
   method Action receive_cmd(Protocol_Binary_Request_Header cmd);
   method Action receive_key(Bit#(64) key);
   method Action receive_dta(Bit#(64) dta);
endinterface

module mkServerRequest#(ServerIndication indication, DRAMControllerIfc dram)(ServerRequest);
   
   //let ddr3_ctrl_user <- mkDDR3Simulator;
   
  // let ddr3_ctrl_user_2 <- mkDDR3Simulator;
      
   //let dram <- mkDRAMController(ddr3_ctrl_user);
   
   //let dram_2 <- mkDRAMController(ddr3_ctrl_user_2);
   
   let clk <- mkLogicClock;
   
   let valstr_acc <- mkValRawAccess(clk, dram);
   
   let valstr_mng <- mkValManager(dram);
   
   let htable <- mkAssocHashtb(dram, clk, valstr_mng.valAlloc);
   
   let hash <- mkJenkinsHash;
   
   FIFO#(Bit#(64)) keyBuf <- mkSizedBRAMFIFO(32);
   
   FIFO#(Tuple3#(Bit#(16), Bit#(32), Protocol_Binary_Command)) cmd2Hash <- mkFIFO;
   FIFO#(Tuple3#(Bit#(16), Bit#(32), Protocol_Binary_Command)) hash2Table <- mkFIFO;
   FIFO#(Tuple3#(Bit#(16), Bit#(32), Protocol_Binary_Command)) table2Val <- mkFIFO;
   
   FIFO#(Bit#(64)) keyFifo <- mkFIFO;
   FIFO#(Bit#(64)) dtaFifo <- mkFIFO;
   
   //Reg#(Bit#(7)) keyBuf_wp <- mkRegU();
   
   //Reg#(Bit#(7)) keyBuf_rp <- mkRegU();
   
   Reg#(Bit#(7)) keyBufDelimit <- mkRegU();
   

   
   rule doHash;
      cmd2Hash.deq;
      let v = cmd2Hash.first;
      let keylen = tpl_1(v);
      hash.start(extend(keylen));
      hash2Table.enq(v);
   endrule
   
   rule key2Hash;
      let v = keyFifo.first;
      keyFifo.deq;
      $display("Memcached Get key: %h", v);
      hash.putKey(keyFifo.first);
      keyBuf.enq(v);
   endrule
   
   rule doTable;
      let d = hash2Table.first;
      hash2Table.deq();
      
      table2Val.enq(d);
      
      let keylen = tpl_1(d);
      let nBytes = tpl_2(d);
      let hv <- hash.getHash();
      $display("Memcached Calc hash val:%h", hv);
      
      htable.readTable(truncate(keylen), hv, extend(nBytes));
   endrule
   
   rule key2Table;
      let v = keyBuf.first();
      keyBuf.deq();
      htable.keyTokens(v);
   endrule
   
   rule doVal;
      let d = table2Val.first;
      table2Val.deq();
      
      let opcode = tpl_3(d);
      let v <- htable.getValAddr();
      
      let addr = tpl_1(v);
      let nBytes = tpl_2(v);
      
      $display("doVal: opcode = %h, addr = %d, nBytes = %d", opcode, addr, nBytes);
      
      if (opcode == PROTOCOL_BINARY_CMD_GET) begin
         $display("doVal: Get Cmd");
         valstr_acc.readReq(addr, nBytes);
         indication.initRdBuf(nBytes);
      end
      else if (opcode == PROTOCOL_BINARY_CMD_SET) begin
         $display("doVal: Set Cmd");
         valstr_acc.writeReq(addr, nBytes);
         indication.ready4dta();
      end
      

   endrule
   
   rule doVal_2;
      let v = dtaFifo.first();
      $display("Server:: Received Data = %h", v);
      dtaFifo.deq();
      valstr_acc.writeVal(v);
   endrule
   
   rule doVal_3;
      let v <- valstr_acc.readVal();
      $display("Server:: Sending Data = %h", v);
      indication.valData(v);
   endrule
      
      
   
//   let inputFIFO <- mkFIFO#(Bit#(32));
   method Action receive_cmd(Protocol_Binary_Request_Header cmd);
      //indication.hexdump(cmd);
      $display("Magic Size: %d", valueOf(MagicSz));
      $display("Opcode Size: %d", valueOf(OpcodeSz));
      $display("Header Size: %d", valueOf(ReqHeaderSz));
      $display("Server received: %h",cmd);
      //$display(cmd);

      cmd2Hash.enq(tuple3(cmd.keylen, cmd.bodylen - extend(cmd.keylen), cmd.opcode));
      //cmd.bodylen;
      
      //keyBuf_wp <= 0;
      if ( cmd.keylen[5:0] == 0 )
         keyBufDelimit <= truncate((cmd.keylen >> 6) - 1);
      else
         keyBufDelimit <= truncate(cmd.keylen >> 6);
   endmethod
   
   method Action receive_key(Bit#(64) key);
      keyFifo.enq(key);
   endmethod
      
   method Action receive_dta(Bit#(64) dta);
      dtaFifo.enq(dta);
   endmethod

   method Action initValDelimit(Bit#(64) lgSz1, Bit#(64) lgSz2, Bit#(64) lgSz3);
      valstr_mng.valInit.initValDelimit(lgSz1, lgSz2, lgSz3);
   endmethod
   
   method Action initAddrDelimit(Bit#(64) lgOffset1, Bit#(64) lgOffset2, Bit#(64) lgOffset3);
      valstr_mng.valInit.initAddrDelimit(lgOffset1, lgOffset2, lgOffset3);
      htable.initTable(lgOffset1);
   endmethod
   
endmodule
