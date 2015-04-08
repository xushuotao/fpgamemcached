import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import BRAMFIFO::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;

import DRAMArbiterTypes::*;
import DRAMArbiter::*;

import Time::*;

import Connectable::*;

import ValDRAMCtrlTypes::*;

import ParameterTypes::*;
import SerDes::*;
import Shifter::*;
import Align::*;
/* interface defintions */

interface DebugProbes_Val;
   method BurstReq debugRdReq;
   method Bit#(64) debugRdDta;
   method BurstReq debugWrReq;
   method Bit#(64) debugWrDta;
endinterface

interface ValDRAMUser;
   method Action readReq(Bit#(64) startAddr, Bit#(64) nBytes);
   method ActionValue#(Bit#(64)) readVal();
   
   method Action writeReq(Bit#(64) startAddr, Bit#(64) nBytes, Bit#(30) hv, Bit#(2) idx);
   method Action writeVal(Bit#(64) wrVal);
endinterface


interface ValDRAMCtrlIFC;
   
   interface ValDRAMUser user;
   
   interface DRAMClient dramClient;

   interface DebugProbes_Val debug;
   
endinterface

typedef 64 WordSz;
typedef Bit#(ShftDtaSz) ShiftDta;
typedef Bit#(WordSz) Word;
typedef LgNOutputs#(ShftDtaSz, WordSz) SerDesArgSz;

//(*synthesize*)
module mkValDRAMCtrl(ValDRAMCtrlIFC);
   
   Clk_ifc real_time <- mkLogicClock;
   
   Reg#(ValAcc_State) state <- mkReg(ProcHeader);
   Reg#(Bool) rnw <- mkRegU();
   
 
   
   FIFO#(Word) readRespQ <- mkFIFO();
   
   FIFO#(DRAMReq) dramCmdQ <- mkFIFO();
   FIFO#(Bit#(512)) dramDataQ <- mkFIFO();
   
   FIFO#(CmdType) cmdQ <- mkFIFO();
   FIFO#(CmdType) cmdQ_Rd <- mkFIFO();
   FIFO#(CmdType) desCmdQ <- mkFIFO();
   FIFO#(CmdType) cmdQ_Wr <- mkFIFO();

   Reg#(Bit#(64)) reqCnt <- mkReg(0);
   
   rule loadOldValue;
   endrule
   
   rule dumpOldValue;
   endrule

   ByteDeAlignIfc#(Bit#(512), Bit#(0)) deAlign <- mkByteDeAlignPipeline();
   
   rule updateHeader if (state == ProcHeader);
      let cmd <- toGet(cmdQ).get();
      if (cmd.rnw) begin
         dramCmdQ.enq(DRAMReq{rnw:False, addr: cmd.currAddr, data:extend(pack(real_time.get_time)), numBytes:fromInteger(valueOf(TDiv#(SizeOf#(Time_t),8)))});
      end
      else begin
         dramCmdQ.enq(DRAMReq{rnw:False, addr: cmd.currAddr, data:extend(pack(ValHeader{timestamp: real_time.get_time, hv: cmd.hv, idx: cmd.idx, nBytes: cmd.numBytes})), numBytes: fromInteger(valueOf(TDiv#(ValHeaderSz,8)))});
      end
     
      cmd.currAddr = cmd.currAddr + fromInteger(valueOf(TDiv#(ValHeaderSz,8)));
      if (cmd.rnw ) 
         cmdQ_Rd.enq(cmd);
      else begin
         desCmdQ.enq(cmd);
         cmdQ_Wr.enq(cmd);
         deAlign.deAlign(cmd.byteOffset, cmd.numBytes,?);
      end
     
      state <= Proc;
   endrule

   FIFO#(RespHandleType) respHandleQ <- mkSizedFIFO(numStages);
   Reg#(Bit#(32)) byteCnt_Rd <- mkReg(0);

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
      
      dramCmdQ.enq(DRAMReq{rnw:True, addr: rowidx << 6, data:?, numBytes:nBytes});
      //$display("byteCnt_Rd = %d, byteIncr = %d, numBytes = %d", byteCnt_Rd, byteIncr, cmd.numBytes);
      if (byteCnt_Rd + extend(nBytes) < cmd.numBytes) begin
         byteCnt_Rd <= byteCnt_Rd + extend(nBytes);
      end
      else begin
         byteCnt_Rd <= 0;
         state <= ProcHeader;
         cmdQ_Rd.deq();
         respHandleQ.enq(RespHandleType{numBytes: cmd.numBytes, byteOffset: cmd.byteOffset});
      end
   endrule
   
   ByteAlignIfc#(Bit#(512), Bit#(0)) align <- mkByteAlignPipeline;
   
   mkConnection(align.inPipe, toGet(dramDataQ));
   
   rule doAlignReadResp;
      let v <- toGet(respHandleQ).get();
      align.align(v.byteOffset, v.numBytes, ?);
   endrule
   
   SerializerIfc#(512, WordSz) ser <- mkSerializer();
      
   rule doSer;
      let v <- align.outPipe.get();
      let data = tpl_1(v);
      let numBytes = tpl_2(v);
   
      Bit#(4) numWords = truncate(numBytes >> 3);
      
      if ( numBytes[2:0] != 0)
         numWords = numWords + 1;
      
      ser.marshall(data, numWords);
   endrule    
   
   DeserializerIfc#(WordSz, 512) des <- mkDeserializer();
   //FIFO#(Word) wDataWord <- mkFIFO;
   //FIFO#(Word) wDataWord <- mkSizedBRAMFIFO(131072);
   FIFO#(Word) wDataWord <- mkSizedBRAMFIFO(512);
   //FIFO#(Word) wDataWord <- mkSizedBRAMFIFO(65536);
   
   mkConnection(toGet(wDataWord), des.demarshall);

   Reg#(Bit#(32)) byteCnt_des <- mkReg(0);
   rule driveDesCmd if ( state == Proc );
      let cmd = desCmdQ.first();
      if ( byteCnt_des + 64 >= cmd.numBytes) begin
         desCmdQ.deq();
         byteCnt_des <= 0;
         Bit#(4) numWords = truncate((cmd.numBytes - byteCnt_des) >> 3);
         Bit#(3) remainder = truncate(cmd.numBytes - byteCnt_des);
         if ( remainder != 0)
            numWords = numWords + 1;
         des.request(numWords);
      end
      else begin
         byteCnt_des <= byteCnt_des + 64;
         des.request(8);
      end
   endrule
   
   rule doConn;
      let v <- des.getVal;
      deAlign.inPipe.put(v);
   endrule
   
   Reg#(Bit#(32)) byteCnt_wr <- mkReg(0);
   rule driveDRAMCmd if (state == Proc );
      let cmd = cmdQ_Wr.first();
      
      let addr = cmd.currAddr + extend(byteCnt_wr);
      
      let v <- deAlign.outPipe.get();
      let data = tpl_1(v);
      let numBytes = tpl_2(v);
      dramCmdQ.enq(DRAMReq{rnw: cmd.rnw, addr: addr, data: data, numBytes: numBytes});
      
      if ( byteCnt_wr + extend(numBytes) == cmd.numBytes) begin
         byteCnt_wr <= 0;
         cmdQ_Wr.deq();
         state <= ProcHeader;
      end
      else begin
         byteCnt_wr <= byteCnt_wr + extend(numBytes);
      end
   endrule

      
   Wire#(BurstReq) rdReq <- mkWire;
   Wire#(BurstReq) wrReq <- mkWire;
   Wire#(Bit#(64)) rdDta <- mkWire;
   Wire#(Bit#(64)) wrDta <- mkWire;
      

   interface ValDRAMUser user;
      
      method Action readReq(Bit#(64) startAddr, Bit#(64) nBytes);
         //$display("Valuestr Get read req, startAddr = %d, nBytes = %d, reqId = %d", startAddr, nBytes, reqCnt);
         Bit#(6) offset = truncate(startAddr + fromInteger(valueOf(TDiv#(ValHeaderSz,8))));
         cmdQ.enq(CmdType{currAddr: startAddr, numBytes:truncate(nBytes), rnw: True, byteOffset: offset});

         reqCnt <= reqCnt + 1;
         rdReq <= BurstReq{addr: startAddr, nBytes: nBytes};
      endmethod
      
      method ActionValue#(Bit#(64)) readVal();
         let d <- ser.getVal;
         rdDta <= d;
         return d;
      endmethod
      
      method Action writeReq(Bit#(64) startAddr, Bit#(64) nBytes, Bit#(30) hv, Bit#(2) idx);
         //$display("Valuestr Get write req, startAddr = %d, nBytes = %d, reqId = %d", startAddr, nBytes, reqCnt);
         
         Bit#(6) offset = truncate(startAddr + fromInteger(valueOf(TDiv#(ValHeaderSz,8))));
         cmdQ.enq(CmdType{currAddr: startAddr, numBytes:truncate(nBytes), rnw: False, byteOffset: offset});
         reqCnt <= reqCnt + 1;
         wrReq <= BurstReq{addr: startAddr, nBytes: nBytes};
      endmethod
      
      method Action writeVal(Bit#(64) wrVal); 
         wDataWord.enq(wrVal);
         wrDta <= wrVal;
      endmethod
   
   endinterface
      
   interface DRAMClient dramClient;
      interface Get request = toGet(dramCmdQ);
      interface Put response = toPut(dramDataQ);
   endinterface

         
   interface DebugProbes_Val debug;
      method BurstReq debugRdReq;
         return rdReq;
      endmethod
      method Bit#(64) debugRdDta;
         return rdDta;
      endmethod
      method BurstReq debugWrReq;
         return wrReq;
      endmethod
      method Bit#(64) debugWrDta;
         return wrDta;
      endmethod
   endinterface

endmodule
