import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import BRAMFIFO::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;

import DRAMCommon::*;
import DRAMArbiter::*;

import Time::*;

import Connectable::*;

import ValDRAMCtrlTypes::*;

import ParameterTypes::*;
import SerDes::*;
import Shifter::*;

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

typedef 576 ShftDtaSz;
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
   FIFO#(Bit#(32)) numBytesQ <- mkFIFO;
      

   Reg#(Bit#(64)) reqCnt <- mkReg(0);
   
   rule loadOldValue;
   endrule
   
   rule dumpOldValue;
   endrule
   
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
         numBytesQ.enq(cmd.numBytes);
      end
     
      state <= Proc;
   endrule

   FIFO#(RespHandleType) respHandleQ <- mkSizedFIFO(numStages);

   Reg#(Bit#(32)) byteCnt_Rd <- mkReg(0);
   Reg#(Bit#(32)) burstIncr <- mkReg(0);
   rule driveReadCmd if (state == Proc);// && cmdQ_2.first().rnw());
      let cmd = cmdQ_Rd.first();
      let addr = cmd.currAddr + extend(byteCnt_Rd);
      let rowidx = addr >> 6;
      //$display("Valstr issuing read cmd: currAddr = %d", addr);
      
      Bit#(7) nBytes = ?;
      Bit#(32) byteIncr = ?;

      if (addr[5:0] == 0) begin
         byteIncr = 64; 
         nBytes = 64;
      end
      else begin
         byteIncr = extend(cmd.initNbytes);//extend(cmd.initOffset)//extend(initNbytes);
         nBytes = cmd.initNbytes;
      end
      
      dramCmdQ.enq(DRAMReq{rnw:True, addr: rowidx << 6, data:?, numBytes:nBytes});
      //$display("byteCnt_Rd = %d, byteIncr = %d, numBytes = %d", byteCnt_Rd, byteIncr, cmd.numBytes);
      if (byteCnt_Rd + byteIncr < cmd.numBytes) begin
         byteCnt_Rd <= byteCnt_Rd + byteIncr;
         burstIncr <= burstIncr + 1;
      end
      else begin
         byteCnt_Rd <= 0;
         state <= ProcHeader;
         cmdQ_Rd.deq();
         //cmplBufUpdate.deleteCmd;
         burstIncr <= 0;
         respHandleQ.enq(RespHandleType{nBursts: burstIncr + 1, initOffset: cmd.initOffset, regOffset: cmd.regOffset, initNWords: cmd.initNWords, totalNWords: cmd.totalNWords});
      end
   endrule
   
   Reg#(Bit#(32)) burstCnt_R <- mkReg(0);
   Reg#(Bit#(32)) wordCnt <- mkReg(0);
   Reg#(Word) readCache <- mkRegU();
   

   //ByteSftIfc#(ShiftDta) readShifter <- mkCombinationalRightShifter;
   ByteSftIfc#(ShiftDta) readShifter <- mkPipelineRightShifter;
   FIFO#(Bit#(SerDesArgSz)) serArgQ <- mkSizedFIFO(valueOf(ElementShiftSz#(ShiftDta)));
   SerializerIfc#(ShftDtaSz, WordSz) ser <- mkSerializer();
   
   rule procReadResp;
      let args = respHandleQ.first;
      Bit#(32) wordIncr = 0;
      
      let data <- toGet(dramDataQ).get();

      readCache <= truncateLSB(data);
      
      //$display("data = %h, wordCnt = %d, totalNWords",data, wordCnt, args.totalNWords);
      if (burstCnt_R == 0) begin
         /* first burst */
         wordIncr = extend(args.initNWords);
         if ( args.initNWords > 0) begin
            //ser.marshall(rotateRByte(extend(data), args.initOffset), args.initNWords);
            readShifter.rotateByteBy(extend(data), extend(args.initOffset));
            serArgQ.enq(args.initNWords);
            wordIncr = extend(args.initNWords);
         end
      end
      else begin
         let newVal ={data, readCache};
         if ( burstCnt_R + 1 == args.nBursts) begin
            /* last burst */
            //ser.marshall(rotateRByte(newVal, args.regOffset), truncate(args.totalNWords - wordCnt));
            readShifter.rotateByteBy(newVal, extend(args.regOffset));
            serArgQ.enq(truncate(args.totalNWords - wordCnt));
         end
         else begin
            /* regular burst */
            //ser.marshall(rotateRByte(newVal, args.regOffset), 8);
            readShifter.rotateByteBy(newVal, extend(args.regOffset));
            serArgQ.enq(8);
            wordIncr = 8;
         end
      end
      
      if (burstCnt_R + 1 < args.nBursts) begin
         burstCnt_R <= burstCnt_R + 1;
         wordCnt <= wordCnt + wordIncr;
      end
      else begin
         burstCnt_R <= 0;
         respHandleQ.deq();
         wordCnt <= 0;
      end
   endrule
   
   rule doSer;
      let nInputs <- toGet(serArgQ).get();
      let data <- readShifter.getVal;
      ser.marshall(data, nInputs);
   endrule
         
   
   DeserializerIfc#(WordSz, ShftDtaSz) des <- mkDeserializer();
   //FIFO#(Word) wDataWord <- mkFIFO;
   //FIFO#(Word) wDataWord <- mkSizedBRAMFIFO(131072);
   FIFO#(Word) wDataWord <- mkSizedBRAMFIFO(512);
   //FIFO#(Word) wDataWord <- mkSizedBRAMFIFO(65536);
   
   mkConnection(toGet(wDataWord), des.demarshall);
   
   Reg#(Bit#(32)) byteCnt_des <- mkReg(0);
   Reg#(Bit#(32)) wordCnt_des <- mkReg(0);
   rule driveDesCmd if ( state == Proc);
      //let cmd = cmdQ_Wr.first();
      let cmd = desCmdQ.first();
      Bit#(32) wordIncr = ?;
      Bit#(32) byteIncr = ?;
      $display("driveDesCmd byteCnt_des = %d, wordCnt_des = %d", byteCnt_des, wordCnt_des);
      if ( byteCnt_des == 0) begin
         /*first des cmd*/
         $display("first des cmd, nInputs = %d", cmd.initNWords);
         des.request(cmd.initNWords);
         byteIncr = extend(cmd.initNbytes);
         wordIncr = extend(cmd.initNWords);
      end
      else if (byteCnt_des + 64 >= cmd.numBytes) begin
         /*last des cmd*/
         $display("last des cmd, nInputs = %d", cmd.totalNWords - wordCnt_des);
         des.request(truncate(cmd.totalNWords - wordCnt_des));
         byteIncr =  64;
      end
      else begin
         /*regular des cmd*/
         $display("regular, nInputs = %d", 8);
         des.request(8);
         byteIncr = 64;
         wordIncr = 8;
      end
      
      if ( byteCnt_des + byteIncr >= cmd.numBytes) begin
         byteCnt_des <= 0;
         wordCnt_des <= 0;
         desCmdQ.deq();
      end
      else begin
         byteCnt_des <= byteCnt_des + byteIncr;
         wordCnt_des <= wordCnt_des + wordIncr;
      end
   endrule
   
   Reg#(Bit#(32)) byteCnt_Wr <- mkReg(0);
   Reg#(Bit#(32)) wordCnt_Wr <- mkReg(0);
   
   //ByteSftIfc#(ShiftDta) writeShifter <- mkCombinationalRightShifter;
   ByteSftIfc#(ShiftDta) writeShifter <- mkPipelineRightShifter;
   FIFO#(DRAMReqType_Pre) dramArgQ <- mkSizedFIFO(valueOf(ElementShiftSz#(ShiftDta)));
   
   rule driveShiftCmd if (state == Proc);
      let cmd = cmdQ_Wr.first();
      let data <- des.getVal();
      
      let currAddr = cmd.currAddr + extend(byteCnt_Wr);
      Bit#(7) rotate = ?;
      
      Bit#(7) nBytes = 64;      
      
      Bit#(32) byteIncr = 0;
      Bit#(32) wordIncr = 0;
      if ( byteCnt_Wr == 0 ) begin
         /* first wr */
         byteIncr = extend(cmd.initNbytes);
         wordIncr = extend(cmd.initNWords);
         rotate = truncate({9-cmd.initNWords, 3'b0});
         nBytes = cmd.initNbytes;
         
      end
      else if ( byteCnt_Wr + 64 >= cmd.numBytes ) begin
         /* last wr */
         byteIncr = 64;
         wordIncr = 8;
         rotate = truncate({8- (cmd.totalNWords - wordCnt_Wr),3'b0}) + 8- extend(cmd.regOffset);
         nBytes = truncate(cmd.numBytes - byteCnt_Wr);
      end
      else begin
         /* regular wr */
         byteIncr = 64;
         wordIncr = 8;
         rotate = extend(8 - cmd.regOffset);
         nBytes = 64;
      end
      
      if ( byteCnt_Wr + byteIncr >= cmd.numBytes ) begin
         byteCnt_Wr <= 0;
         wordCnt_Wr <= 0;
         cmdQ_Wr.deq;
      end
      else begin
         wordCnt_Wr <= wordCnt_Wr + wordIncr;
         byteCnt_Wr <= byteCnt_Wr + byteIncr;
      end
      
      writeShifter.rotateByteBy(data, rotate);
      dramArgQ.enq(DRAMReqType_Pre{rnw: False, addr: currAddr, numBytes:nBytes});
   endrule
   
   Reg#(Bit#(32)) byteCnt_wrCmd <- mkReg(0);
   rule driveDRAMCmd if (state == Proc);
      let numBytes = numBytesQ.first();
      let cmd <- toGet(dramArgQ).get();
      let data <- writeShifter.getVal;
      if ( byteCnt_wrCmd + extend(cmd.numBytes) == numBytes) begin
         numBytesQ.deq();
         byteCnt_wrCmd <= 0;
         state <= ProcHeader;
      end
      else begin
         byteCnt_wrCmd <= byteCnt_wrCmd + extend(cmd.numBytes);
      end
      dramCmdQ.enq(DRAMReq{rnw: cmd.rnw, addr: cmd.addr, data: truncate(data), numBytes: cmd.numBytes});
   endrule
      
  
      
   Wire#(BurstReq) rdReq <- mkWire;
   Wire#(BurstReq) wrReq <- mkWire;
   Wire#(Bit#(64)) rdDta <- mkWire;
   Wire#(Bit#(64)) wrDta <- mkWire;
      

   interface ValDRAMUser user;
      
      method Action readReq(Bit#(64) startAddr, Bit#(64) nBytes);// if (state == Idle);
         $display("Valuestr Get read req, startAddr = %d, nBytes = %d, reqId = %d", startAddr, nBytes, reqCnt);
        
         Bit#(32) totalNWords = ?;
         if (nBytes[2:0] == 0)
            totalNWords = truncate(nBytes >> 3);
         else
            totalNWords = truncate((nBytes >> 3) + 1);
        

         Bit#(6) offset = truncate(startAddr + fromInteger(valueOf(TDiv#(ValHeaderSz,8))));
         Bit#(7) initNbytes = 64 - extend(offset);
         Bit#(4) initNWords = truncateLSB(initNbytes);
    
         if ( extend(initNbytes) >= nBytes ) begin
            initNWords = truncate(totalNWords);
         end
   
         Bit#(4) regOffset = extend(offset[2:0]);
         if (regOffset == 0) begin
            regOffset = 8;
         end
   
         //$display("Read req: initNbytes = %d, initOffset = %d, regOffset = %d, initNWords = %d, totalNWords = %d", initNbytes, offset, regOffset, initNWords, totalNWords);
         cmdQ.enq(CmdType{currAddr: startAddr,initNbytes: initNbytes, numBytes:truncate(nBytes), rnw: True, initOffset: offset, regOffset: regOffset, initNWords: extend(initNWords), totalNWords: totalNWords});
         reqCnt <= reqCnt + 1;
      
         rdReq <= BurstReq{addr: startAddr, nBytes: nBytes};
      endmethod
      
      method ActionValue#(Bit#(64)) readVal();
         let d <- ser.getVal;
         rdDta <= d;
         return d;
      endmethod
      
      method Action writeReq(Bit#(64) startAddr, Bit#(64) nBytes, Bit#(30) hv, Bit#(2) idx);
         $display("Valuestr Get write req, startAddr = %d, nBytes = %d, reqId = %d", startAddr, nBytes, reqCnt);
   
         Bit#(32) totalNWords = ?;
         if (nBytes[2:0] == 0)
            totalNWords = truncate(nBytes >> 3);
         else
            totalNWords = truncate((nBytes >> 3) + 1);
        

         Bit#(6) offset = truncate(startAddr + fromInteger(valueOf(TDiv#(ValHeaderSz,8))));
         Bit#(7) initNbytes = 64 - extend(offset);
   
         Bit#(4) initNWords = truncateLSB(initNbytes);
         if ( initNbytes[2:0] != 0 ) begin
            initNWords = initNWords + 1;
         end
            
    
         if ( extend(initNbytes) >= nBytes ) begin
            initNWords = truncate(totalNWords);
            initNbytes = truncate(nBytes);
         end
   
         Bit#(4) regOffset = extend(offset[2:0]);
         
            
         //cmdQ.enq(CmdType{currAddr:startAddr, initNbytes: 64 - extend(offset_local), numBytes: truncate(nBytes), numBursts: numBursts, rnw: False, hv: hv, idx: idx});
         $display("Write req: initNbytes = %d, initOffset = %d, regOffset = %d, initNWords = %d, totalNWords = %d", initNbytes, offset, regOffset, initNWords, totalNWords);
         cmdQ.enq(CmdType{currAddr: startAddr,initNbytes: initNbytes, numBytes:truncate(nBytes), rnw: False, initOffset: offset, regOffset: regOffset, initNWords: extend(initNWords), totalNWords: totalNWords, hv: hv, idx:idx});
         //rnw <= False;
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
