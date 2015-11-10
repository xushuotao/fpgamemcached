import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import BRAMFIFO::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import ClientServerHelper::*;

import DRAMCommon::*;
import ValDRAMArbiter::*;

import Time::*;

import Connectable::*;

import MemcachedTypes::*;
//import HashtableTypes::*;
import ValuestrCommon::*;
import ValDRAMCtrlTypes::*;
import ValFlashCtrlTypes::*;

import ParameterTypes::*;
import SerDes::*;
import ByteSerDes::*;
import Shifter::*;
import Align::*;
/* interface defintions */

typedef 128 WordSz;
typedef Bit#(WordSz) WordT;
typedef TDiv#(WordSz, 8) WordBytes;

interface ValDRAMUser;
   method Action readReq(Bit#(64) startAddr, Bit#(64) nBytes);
   method ActionValue#(WordT) readVal();
   
   method Action writeReq(ValstrWriteReqT req);
   method Action writeVal(WordT wrVal);
endinterface


interface ValDRAMCtrlIFC;
   
   interface ValDRAMUser user;
   
   interface ValDRAMClient dramClient;
   
   interface FlashWriteClient flashWriteClient;
   
   interface Get#(HeaderUpdateReqT) htableRequest;

endinterface


(*synthesize*)
module mkValDRAMCtrl(ValDRAMCtrlIFC);
   
   Integer evictOffset = valueOf(BytesOf#(Time_t));
   Integer flashHeaderSz = valueOf(TSub#(BytesOf#(ValHeader),BytesOf#(Time_t)));
   Integer valHeaderBytes = valueOf(BytesOf#(ValHeader));

   
   Clk_ifc real_time <- mkLogicClock;
   
   Reg#(ValAcc_State) state <- mkReg(ProcHeader);
        
   FIFO#(WordT) readRespQ <- mkFIFO();
   
   //Vector#(2,FIFO#(DRAM_LOCK_Req)) dramCmdQs <- replicateM(mkSizedFIFO(32));
   //Vector#(2,FIFO#(Bit#(512))) dramDataQs <- replicateM(mkFIFO());
   
   FIFO#(Tuple2#(DRAM_ACK_Req,Bit#(1))) dramCmdQ <- mkFIFO();
   Vector#(2,FIFO#(Bit#(512))) dramDataQs <- replicateM(mkFIFO());
   
   FIFO#(DRAM_ACK_Req) dramRawCmdQ <- mkSizedFIFO(32);
   FIFO#(Bit#(1)) selQ <- mkSizedFIFO(32);
   FIFO#(Bit#(512)) dramRawDtaQ <- mkSizedFIFO(32);


   rule doReq;
      let v <- toGet(dramCmdQ).get();
      let cmd = tpl_1(v);
      let dst = tpl_2(v);
      dramRawCmdQ.enq(cmd);
      if ( cmd.rnw )
         selQ.enq(dst);
   endrule
   
   
   rule doResp;
      let v <- toGet(dramRawDtaQ).get();
      let sel <- toGet(selQ).get();
      dramDataQs[sel].enq(v);
   endrule
   // DRAM_LOCK_Arbiter_Bypass#(2) dramArb <- mkDRAM_LOCK_Arbiter_Bypass;
   
   // mkConnection(toClient(dramCmdQs[0], dramDataQs[0]), dramArb.dramServers[0]);
   // mkConnection(toClient(dramCmdQs[1], dramDataQs[1]), dramArb.dramServers[1]);
   
   
   FIFO#(CmdType) cmdQ <- mkFIFO();
   FIFO#(CmdType) cmdQ_Rd <- mkFIFO();
   FIFO#(CmdType) desCmdQ <- mkFIFO();
   FIFO#(CmdType) cmdQ_Wr <- mkFIFO();

   Reg#(Bit#(64)) reqCnt <- mkReg(0);
   
   FIFO#(Tuple2#(Bit#(30), Bit#(2))) hdrUpdQ_pre <- mkFIFO();
   FIFO#(HeaderUpdateReqT) hdrUpdQ <- mkFIFO();
   
  
   ByteAlignIfc#(Bit#(512), Bit#(0)) align_evict <- mkByteAlignPipeline;
   //ByteAlignIfc#(Bit#(512), void) align_evict <- mkByteAlignCombinational_regular;
   mkConnection(align_evict.inPipe, toGet(dramDataQs[1]));
   
   
   FIFO#(ValSizeT) flashReqQ <- mkFIFO();
   FIFO#(FlashAddrType) flashRespQ <- mkFIFO();
   
   let flashWrCli = (interface FlashWriteClient;
                        interface Client writeClient = toClient(flashReqQ, flashRespQ);
                        interface Get writeWord;
                           method ActionValue#(Bit#(512)) get();
                              let v <- align_evict.outPipe.get();
                              return tpl_1(v);
                           endmethod
                        endinterface
                     endinterface);
   
   rule doFlashResp;
      let v <- toGet(hdrUpdQ_pre).get();
      let addr <- toGet(flashRespQ).get();
      $display("%m:: got writebuf resp hv = %h, idx = %d, addr = %d", tpl_1(v), tpl_2(v), addr);
      hdrUpdQ.enq(HeaderUpdateReqT{hv: tpl_1(v), idx: tpl_2(v), flashAddr: addr});
   endrule
   

   //ByteDeAlignIfc#(Bit#(512), Bit#(0)) deAlign <- mkByteDeAlignPipeline();
   //ByteDeAlignIfc#(Bit#(512), Bit#(0)) deAlign <- mkByteDeAlignCombinational();
   //ByteDeAlignIfc#(Bit#(128), Bit#(0)) deAlign <- mkByteDeAlignCombinational();
   ByteAlignIfc#(Bit#(128), void) align <- mkByteAlignCombinational;
   ByteDeAlignIfc#(Bit#(128), void) deAlign <- mkByteDeAlignCombinational_regular();
   
   
   Reg#(ValSizeT) byteCnt_Evict <- mkReg(0);
   rule doHeader if (state == ProcHeader);
      let cmd = cmdQ.first();
      if (cmd.rnw) begin
         //dramCmdQs[0].enq(DRAM_ACK_Req{initlock: False, ignoreLock: True, lock: False, rnw:False, addr: cmd.currAddr, data:extend(pack(real_time.get_time)), numBytes:fromInteger(valueOf(BytesOf#(Time_t)))});
         dramCmdQ.enq(tuple2(DRAM_ACK_Req{ack: False, initlock: False, ignoreLock: True, lock: False, rnw:False, addr: cmd.currAddr, data:extend(pack(real_time.get_time)), numBytes:fromInteger(valueOf(BytesOf#(Time_t)))}, 0));
         cmdQ.deq();
         cmd.currAddr = cmd.currAddr + fromInteger(valHeaderBytes);
         cmdQ_Rd.enq(cmd);
         state <= Proc;
      end
      else begin
         if ( !cmd.doEvict || byteCnt_Evict >= cmd.old_nBytes + fromInteger(flashHeaderSz)) begin
            $display("Update Header, reqId = %d", cmd.reqId);
            //dramCmdQs[0].enq(DRAM_ACK_Req{initlock: False, ignoreLock: True, lock: False, rnw:False, addr: cmd.currAddr, data:extend(pack(ValHeader{timestamp: real_time.get_time, hv: cmd.hv, idx: cmd.idx, nBytes: cmd.numBytes})), numBytes: fromInteger(valHeaderBytes)});
            Bool ack = True;//cmd.doEvict;
            //Bool ack = cmd.doEvict;
            
            dramCmdQ.enq(tuple2(DRAM_ACK_Req{ack: ack, initlock: False, ignoreLock: True, lock: False, rnw:False, addr: cmd.currAddr, data:extend(pack(ValHeader{timestamp: real_time.get_time, hv: cmd.hv, idx: cmd.idx, nBytes: cmd.numBytes})), numBytes: fromInteger(valHeaderBytes)},0));
            byteCnt_Evict <= 0;
            cmd.currAddr = cmd.currAddr + fromInteger(valHeaderBytes);
            cmdQ.deq();
            desCmdQ.enq(cmd);
            cmdQ_Wr.enq(cmd);
            deAlign.deAlign(truncate(cmd.byteOffset), cmd.numBytes,?);
            state <= Proc;
         end
         else begin
            let addr = cmd.currAddr + fromInteger(evictOffset) + extend(byteCnt_Evict);
            let rowidx = addr >> 6;
            $display("Valstr issuing read cmd for eviction: reqId = %d, currAddr = %d", cmd.reqId, addr);
            Bit#(7) nBytes = ?;

            if (addr[5:0] == 0) begin
               nBytes = 64;
            end
            else begin
               nBytes = 64 - extend(addr[5:0]);
            end
            
            //dramCmdQs[1].enq(DRAM_ACK_Req{initlock: False, ignoreLock: True, lock: False, rnw:True, addr: rowidx << 6, data:?, numBytes:nBytes});
            dramCmdQ.enq(tuple2(DRAM_ACK_Req{ack: False, initlock: False, ignoreLock: True, lock: False, rnw:True, addr: rowidx << 6, data:?, numBytes:nBytes},1));
            $display("byteCnt_Evict = %d, byteIncr = %d, total numBytes = %d", byteCnt_Evict, nBytes, cmd.old_nBytes + fromInteger(flashHeaderSz));
            byteCnt_Evict <= byteCnt_Evict + extend(nBytes);            
         end
      end
      
   endrule

   FIFO#(RespHandleType) respHandleQ <- mkSizedFIFO(numStages);
   Reg#(Bit#(32)) byteCnt_Rd <- mkReg(0);
   
   Reg#(Bit#(32)) debug_cnt <- mkReg(0);
   rule driveReadCmd if (state == Proc);
      let cmd = cmdQ_Rd.first();
      let addr = cmd.currAddr + extend(byteCnt_Rd);
      let rowidx = addr >> 6;
      //$display("Valstr issuing read cmd: currAddr = %d", addr);
      
      Bit#(7) nBytes = ?;

      if (addr[5:0] == 0) begin
         nBytes = 64;
      end
      else begin
         nBytes = 64 - extend(cmd.byteOffset);
      end
      
      Bool initlock = False;
      if (byteCnt_Rd == 0) begin
         respHandleQ.enq(RespHandleType{numBytes: cmd.numBytes, byteOffset: cmd.byteOffset});
         //align.align(truncate(cmd.byteOffset), cmd.numBytes, ?);
         initlock = True;
      end

      
      Bool lock = True;
      if (byteCnt_Rd + extend(nBytes) < cmd.numBytes) begin
         byteCnt_Rd <= byteCnt_Rd + extend(nBytes);
      end
      else begin
         lock = False;
         byteCnt_Rd <= 0;
         state <= ProcHeader;
         cmdQ_Rd.deq();
         debug_cnt <= debug_cnt + 1;
      end
      $display("%m:: dram Read, byteCnt_Rd = %d, addr = %d, byteIncr = %d, numBytes = %d, debug_cnt = %d", byteCnt_Rd, rowidx << 6, nBytes, cmd.numBytes, debug_cnt);
      //dramCmdQs[0].enq(DRAM_ACK_Req{initlock: initlock, ignoreLock: False, lock: lock, rnw:True, addr: rowidx << 6, data:?, numBytes:nBytes});
      dramCmdQ.enq(tuple2(DRAM_ACK_Req{ack: False, initlock: initlock, ignoreLock: False, lock: lock, rnw:True, addr: rowidx << 6, data:?, numBytes:nBytes},0));
   endrule
   
   ByteSer ser <- mkByteSer;
   Reg#(Bit#(32)) byteCnt <- mkReg(0);
   rule doSer;
      let v = respHandleQ.first();
      let data <- toGet(dramDataQs[0]).get();

      Bit#(32) byteIncr = 64;
      Bit#(6) offset = 0;
      if ( byteCnt == 0 ) begin
         align.align(truncate(v.byteOffset), v.numBytes, ?);
         
         offset = v.byteOffset;
         if ( 64 - extend(v.byteOffset) > v.numBytes ) begin
            byteIncr = v.numBytes;
         end
         else begin
            byteIncr = 64 - extend(v.byteOffset);
         end
      end
      
      $display("(%t) %m:: Read doSer, byteCnt = %d, byteIncr = %d, offset = %d, nBytes = %d, data = %h", $time, byteCnt, byteIncr, v.byteOffset, v.numBytes, data);
      //
      
      if (byteCnt + byteIncr >= v.numBytes) begin
         byteCnt <= 0;
         respHandleQ.deq();
         ser.inPipe.put(tuple3(data, offset, truncate(v.numBytes-byteCnt)));
      end
      else begin
         byteCnt <= byteCnt + byteIncr;
         ser.inPipe.put(tuple3(data, offset, truncate(byteIncr)));
      end
   endrule
   
   mkConnection(align.inPipe, ser.outPipe);
   
   //DeserializerIfc#(WordSz, 512, void) des <- mkDeserializer();
   ByteDes des <- mkByteDes;
   //FIFO#(Word) wDataWord <- mkFIFO;
   //FIFO#(Word) wDataWord <- mkSizedBRAMFIFO(131072);
   FIFO#(WordT) wDataWord <- mkSizedBRAMFIFO(256);
   //FIFO#(Word) wDataWord <- mkSizedBRAMFIFO(65536);
   
   mkConnection(toGet(wDataWord), deAlign.inPipe);

   Reg#(Bit#(32)) byteCnt_des <- mkReg(0);
   rule driveDesCmd;// if ( state == Proc );
      let cmd = desCmdQ.first();
      Bit#(6) offset = 0;
      Bit#(7) nBytes = 64;
      if (byteCnt_des == 0) begin
         offset = cmd.byteOffset;
         nBytes = 64 - extend(cmd.byteOffset);
      end
      

      if ( byteCnt_des + extend(nBytes) >= cmd.numBytes) begin
         desCmdQ.deq();
         byteCnt_des <= 0;
         nBytes = truncate(cmd.numBytes - byteCnt_des);
      end
      else begin
         byteCnt_des <= byteCnt_des + extend(nBytes);
      end
      
      des.request.put(tuple2(offset,nBytes));
   endrule
   
   rule doConn;
      let v <- deAlign.outPipe.get();
      des.inPipe.put(tpl_1(v));
   endrule
   
   Reg#(Bit#(32)) byteCnt_wr <- mkReg(0);
   rule driveDRAMCmd if (state == Proc );
      let cmd = cmdQ_Wr.first();
      
      let addr = cmd.currAddr + extend(byteCnt_wr);
      
      let v <- des.outPipe.get();
      let data = tpl_1(v);
      let numBytes = tpl_2(v);
      $display("DRAM Value store write: reqId = %d, addr = %d, data = %h, numBytes = %d", cmd.reqId, addr, data, numBytes);
      //dramCmdQs[0].enq(DRAM_ACK_Req{initlock: False, ignoreLock: True, lock: False, rnw: cmd.rnw, addr: addr, data: data, numBytes: numBytes});
      dramCmdQ.enq(tuple2(DRAM_ACK_Req{ack: False, initlock: False, ignoreLock: True, lock: False, rnw: cmd.rnw, addr: addr, data: data, numBytes: numBytes},0));
      
      $display("byteCnt_wr = %d, incrByte = %d , totalNbytes = %d", byteCnt_wr, numBytes, cmd.numBytes);
      if ( byteCnt_wr + extend(numBytes) == cmd.numBytes) begin
         $display("finish writing commands");
         byteCnt_wr <= 0;
         cmdQ_Wr.deq();
         state <= ProcHeader;
      end
      else begin
         byteCnt_wr <= byteCnt_wr + extend(numBytes);
      end
   endrule


   interface ValDRAMUser user;
      
      method Action readReq(Bit#(64) startAddr, Bit#(64) nBytes);
         $display("Valuestr Get read req, startAddr = %d, nBytes = %d, reqId = %d", startAddr, nBytes, reqCnt);
         Bit#(6) offset = truncate(startAddr + fromInteger(valueOf(TDiv#(ValHeaderSz,8))));
         cmdQ.enq(CmdType{currAddr: startAddr, numBytes:truncate(nBytes), rnw: True, byteOffset: offset});

         reqCnt <= reqCnt + 1;
         //rdReq <= BurstReq{addr: startAddr, nBytes: nBytes};
      endmethod
      
      method ActionValue#(WordT) readVal();
         let d <- align.outPipe.get;
         return tpl_1(d);
      endmethod
      
      method Action writeReq(ValstrWriteReqT req);
         $display("Valuestr Get write req, startAddr = %d, nBytes = %d, reqId = %d", req.addr, req.nBytes, reqCnt);
         
         Bit#(6) offset = truncate(req.addr + fromInteger(valueOf(TDiv#(ValHeaderSz,8))));
         cmdQ.enq(CmdType{currAddr: req.addr,
                          numBytes:extend(req.nBytes),
                          rnw: False,
                          byteOffset: offset,
                          hv:req.hv,
                          idx:req.idx,
                          doEvict: req.doEvict,
                          old_nBytes: req.old_nBytes,
                          reqId: reqCnt});
   
         if (req.doEvict) begin
            $display("Value Eviction is needed: old_hv = %h, old_idx = %d, numBytes = %d, addr = %d", req.old_hv, req.old_idx, req.addr+ fromInteger(valueOf(BytesOf#(Time_t))), req.old_nBytes+fromInteger(flashHeaderSz));
            flashReqQ.enq(req.old_nBytes+fromInteger(flashHeaderSz));
            align_evict.align(truncate(req.addr+ fromInteger(valueOf(BytesOf#(Time_t)))), extend(req.old_nBytes)+fromInteger(flashHeaderSz), ?);
            hdrUpdQ_pre.enq(tuple2(req.old_hv, req.old_idx));
         end
            
         reqCnt <= reqCnt + 1;
      endmethod
      
      method Action writeVal(WordT wrVal); 
         wDataWord.enq(wrVal);
      endmethod
   
   endinterface
      
   interface ValDRAMClient dramClient = toClient(dramRawCmdQ, dramRawDtaQ);//dramArb.dramClient;
   
   interface FlashWriteClient flashWriteClient = flashWrCli;
   
   interface Get htableRequest = toGet(hdrUpdQ);

endmodule
