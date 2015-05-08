`include "ProtocolHeader.bsv"

import JenkinsHash::*;
import Hashtable::*;
import Valuestr::*;
import Time::*;
import DRAMController::*;

import FIFO::*;
import BRAMFIFO::*;
import Vector::*;

interface ServerIndication;
   method Action ready4dta();
   method Action initRdBuf(Bit#(64) nBytes);
   method Action valData(Bit#(64) v);
   //method Action hexdump(Bit#(32) v);
endinterface

interface ServerRequest;
   /*** initialize ****/
   method Action initValDelimit(Bit#(64) lgSz1, Bit#(64) lgSz2, Bit#(64) lgSz3);
   method Action initAddrDelimit(Bit#(64) lgOffset1, Bit#(64) lgOffset2, Bit#(64) lgOffset3);
   
   /*** cmd key dta request ***/
   method Action receive_cmd(Protocol_Binary_Request_Header cmd);
   // method Action receive_cmd(Bit#(64) packet);
   method Action receive_key(Bit#(64) key);
   method Action receive_dta(Bit#(64) dta);
   
   /*** flow control ***/
   method Action rdBuf_ready();
endinterface

module mkServerRequest#(ServerIndication indication, DRAMControllerIfc dram)(ServerRequest);
/* 
   FIFO#(Bit#(64)) keyBuf <- mkSizedBRAMFIFO(32);
   
   FIFO#(Tuple3#(Bit#(16), Bit#(32), Protocol_Binary_Command)) cmd2Hash <- mkFIFO;
   FIFO#(Tuple3#(Bit#(16), Bit#(32), Protocol_Binary_Command)) hash2Table <- mkFIFO;
   FIFO#(Tuple3#(Bit#(16), Bit#(32), Protocol_Binary_Command)) table2Val <- mkFIFO;
   
   FIFO#(Bit#(64)) keyFifo <- mkFIFO;
   FIFO#(Bit#(64)) dtaFifo <- mkFIFO;
   
      
   //Reg#(Bit#(7)) keyBufDelimit <- mkRegU();
   Reg#(Bool) rdBufRdy <- mkReg(False);

   
   let clk <- mkLogicClock;
   
   let valstr_acc <- mkValRawAccess(clk, dram);
   
   let valstr_mng <- mkValManager(dram);
   
   let htable <- mkAssocHashtb(dram, clk, valstr_mng.valAlloc);
   
   let hash <- mkJenkinsHash;
   
   
   
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
      hash.putKey(v);
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
   
   //Reg#(Bool) initRdBufDone <- mkReg(False);
   //FIFO#(Tuple2#(Bit#(64), Bit#(64))) valRdReqQ <- mkFIFO();
   
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
         rdBufRdy <= False;
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
   

   FIFO#(Bit#(64)) valDataQ <- mkFIFO();
   Reg#(Bit#(32)) debugCnt <- mkReg(0);
   rule doVal_3 if (rdBufRdy);
      let v <- valstr_acc.readVal();
      //$display("Server:: [%d] Sending Data = %h", debugCnt, v);
      //debugCnt <= debugCnt + 1;
      //indication.valData(v);
      valDataQ.enq(v);
   endrule
      
   rule doVal_4;
      valDataQ.deq();
      let v = valDataQ.first();
      //debugCnt <= debugCnt + 1;
      indication.valData(v);//extend(debugCnt));
   endrule

 */
   
   FIFO#(Tuple3#(Bit#(16), Bit#(32), Protocol_Binary_Command)) cmd2Hash <- mkFIFO;
   
   Reg#(Protocol_Binary_Request_Header) cmdBuf <- mkRegU();
   Reg#(Bit#(64)) keyBuf <- mkRegU();
   Reg#(Bit#(64)) valBuf <- mkRegU();
   Vector#(3,Reg#(Bit#(64))) sizeBuf <- replicateM(mkRegU());
   Reg#(Bit#(64)) bytes <- mkRegU();
   Reg#(Bool) rdBufRdy <- mkRegU();
   
   Reg#(Bit#(64)) debugCnt <- mkReg(0);
   Reg#(Bit#(64)) valReg <- mkReg(0);
   
   FIFO#(Bit#(64)) keyFifo <- mkFIFO();
   Reg#(Bit#(32)) keyLen <- mkRegU();
   Reg#(Bit#(32)) keyCnt <- mkReg(0);
   Reg#(Bool) keyRdy <- mkReg(False);
   
   rule doKey if (keyRdy);
      if (keyCnt < keyLen) begin
         let v = keyFifo.first;
         keyFifo.deq;
         keyBuf <= v;
         
         keyCnt <= keyCnt + 8;
      end
      else begin
         cmd2Hash.deq;
         let v = cmd2Hash.first;
         let keylen = tpl_1(v);
         
         let opcode = tpl_3(v);

         if (opcode == PROTOCOL_BINARY_CMD_GET) begin
            $display("doVal: Get Cmd");
            indication.initRdBuf(bytes);
            rdBufRdy <= False;
         end
         else if (opcode == PROTOCOL_BINARY_CMD_SET) begin
            $display("doVal: Set Cmd");
            indication.ready4dta();
         end
         
         keyCnt <= 0;
         keyRdy <= False;
      end

   endrule

   rule doVal_4 if (rdBufRdy);
      if (debugCnt < bytes) begin
         indication.valData(valReg);
         valReg <= valReg + 1;
         debugCnt <= debugCnt + 8;
      end
      else begin
         rdBufRdy <= False;
         debugCnt <= 0;
         valReg <= 0;
      end
   endrule
   
   method Action receive_cmd(Protocol_Binary_Request_Header cmd);
      //indication.hexdump(cmd);
   
      $display("Magic Size: %d", valueOf(MagicSz));
      $display("Opcode Size: %d", valueOf(OpcodeSz));
      $display("Header Size: %d", valueOf(ReqHeaderSz));
      $display("Server received: %h",cmd);
      //$display(cmd);
     
      cmd2Hash.enq(tuple3(cmd.keylen, cmd.bodylen - extend(cmd.keylen), cmd.opcode));
   
      let opcode = cmd.opcode;
   
      Bit#(64) nBytes = extend(cmd.bodylen - extend(cmd.keylen));
     
      if (opcode == PROTOCOL_BINARY_CMD_GET) begin
         $display("doVal: Get Cmd");
      end
      else if (opcode == PROTOCOL_BINARY_CMD_SET) begin
         $display("doVal: Set Cmd");
         bytes <= nBytes;
      end
      

      keyRdy <= True;
      keyLen <= extend(cmd.keylen);
   endmethod
   
   method Action receive_key(Bit#(64) key);
      $display("got key");
      keyFifo.enq(key);
      //keyBuf <= key;
   endmethod
      
   method Action receive_dta(Bit#(64) dta);
      //dtaFifo.enq(dta);
      $display("got data");
      valBuf <= dta;
   endmethod
   
   method Action rdBuf_ready();
      $display("Ack rdBuf is ready");
      rdBufRdy <= True;
   endmethod

   method Action initValDelimit(Bit#(64) lgSz1, Bit#(64) lgSz2, Bit#(64) lgSz3);
      $display("Server initializing val store size delimiter");
//      valstr_mng.valInit.initValDelimit(lgSz1, lgSz2, lgSz3);
      sizeBuf[0] <= lgSz1;
      sizeBuf[1] <= lgSz2;
      sizeBuf[2] <= lgSz3;
      /*
      if (paraPtr0 == 2) begin
         valstr_mng.valInit.initValDelimit(lgSz[0], lgSz[1], lgSzPara);
         paraPtr0 <= 0;
      end
      else begin
         lgSz[paraPtr0] <= lgSzPara;
         paraPtr0 <= paraPtr0 + 1;
      end
      */
   endmethod
  
   method Action initAddrDelimit(Bit#(64) lgOffset1, Bit#(64) lgOffset2, Bit#(64) lgOffset3);
      $display("Server initializing val store addr delimiter");
      //valstr_mng.valInit.initAddrDelimit(lgOffset1, lgOffset2, lgOffset3);
      //htable.initTable(lgOffset1);
      sizeBuf[0] <= lgOffset1;
      sizeBuf[1] <= lgOffset1;
      sizeBuf[2] <= lgOffset1;
      
      /*
      if (paraPtr1 == 2) begin
         paraPtr1 <= 0;
         valstr_mng.valInit.initAddrDelimit(lgOffset[0], lgOffset[1], lgOffsetPara);
         htable.initTable(lgOffset[0]);
      end
      else begin
         lgOffset[paraPtr1] <= lgOffsetPara;
         paraPtr1 <= paraPtr1 + 1;
      end
       */
   endmethod
   
endmodule
