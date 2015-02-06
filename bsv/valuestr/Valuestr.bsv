package Valuestr;

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

import ValuestrTypes::*;

/* interface defintions */

interface DebugProbes_Val;
   method BurstReq debugRdReq;
   method Bit#(64) debugRdDta;
   method BurstReq debugWrReq;
   method Bit#(64) debugWrDta;
endinterface


interface ValAccess_ifc;
   method Action readReq(Bit#(64) startAddr, Bit#(64) nBytes);
   method ActionValue#(Bit#(64)) readVal();
   
   method Action writeReq(Bit#(64) startAddr, Bit#(64) nBytes);
   method Action writeVal(Bit#(64) wrVal);
   
   interface DRAMClient dramClient;

   interface DebugProbes_Val debug;
   
endinterface

//(*synthesize*)
//module mkValRawAccess#(Clk_ifc real_time)(ValAccess_ifc);
module mkValRawAccess(ValAccess_ifc);
   
   Clk_ifc real_time <- mkLogicClock;
   
   Reg#(ValAcc_State) state <- mkReg(ProcHeader);
   Reg#(Bool) rnw <- mkRegU();
   
   //Reg#(Bool) readChannelOpen <- mkReg(False);
   //Reg#(Bit#(6)) initOffset <- mkRegU();
   //Reg#(Bit#(7)) initNbytes <- mkRegU();
   //Reg#(Bit#(64)) currAddr <- mkRegU();
   Reg#(Bit#(32)) byteCnt <- mkReg(0);
   Reg#(Bit#(32)) byteCnt_Wr <- mkReg(0);
   //Reg#(Bit#(64)) numBytes <- mkRegU();
   //Reg#(Bit#(64)) numBursts <- mkRegU();
   
   Reg#(Bit#(32)) byteCnt_Rd <- mkReg(0);
   Reg#(Bool) firstLine_Rd <- mkReg(True);
   
   
   Reg#(Bool) firstLine <- mkReg(True);
   Reg#(Bool) firstLine2 <- mkReg(True);
   Reg#(Bit#(7)) lineCnt_Rd <- mkRegU();
   Reg#(Bit#(512)) lineBuf_Rd <- mkRegU();
   
   Reg#(Bit#(64)) wordBuf_Rd <- mkRegU();
   Reg#(Bit#(4)) wordCnt_Rd <- mkRegU();
   
   Reg#(Bit#(7)) lineCnt_Wr <- mkRegU();
   Reg#(Bit#(512)) lineBuf_Wr <- mkRegU();
   
   Reg#(Bit#(64)) wordBuf_Wr <- mkRegU();
   Reg#(Bit#(4)) wordCnt_Wr <- mkRegU();
   
   
   FIFO#(Bit#(64)) readRespQ <- mkFIFO();
   
   FIFO#(DRAMReqType_Imm) dramCmdQ_Imm <- mkFIFO();
   FIFO#(DRAMReq) dramCmdQ <- mkFIFO();
   FIFO#(Bit#(512)) dramDataQ <- mkFIFO();
   
   FIFO#(CmdType) cmdQ <- mkFIFO();
   FIFO#(CmdType) cmdQ_Rd <- mkFIFO();
   FIFO#(CmdType) cmdQ_Wr <- mkFIFO();
   
   mkConnection(toGet(dramCmdQ_Imm), toPut(dramCmdQ));

   Reg#(Bit#(64)) reqCnt <- mkReg(0);
   
   rule updateHeader if (state == ProcHeader);
      let cmd <- toGet(cmdQ).get();
      //let cmd = cmdQ.first();
      dramCmdQ_Imm.enq(DRAMReqType_Imm{rnw:False, addr: cmd.currAddr, data:extend(pack(real_time.get_time)), numBytes:fromInteger(valueOf(TDiv#(SizeOf#(Time_t),8))), shiftval: 0});
     
      cmd.currAddr = cmd.currAddr + fromInteger(valueOf(TDiv#(ValHeaderSz,8)));
      if (cmd.rnw ) 
         cmdQ_Rd.enq(cmd);
      else
         cmdQ_Wr.enq(cmd);
      //currAddr <= cmd.currAddr + fromInteger(valueOf(TDiv#(ValHeaderSz,8)));
     
      state <= Proc;
   endrule

   FIFO#(RespHandleType) respHandleQ <- mkSizedFIFO(16);
   
   rule driveReadCmd if (state == Proc);// && cmdQ_2.first().rnw());
      let cmd = cmdQ_Rd.first();
      let addr = cmd.currAddr + extend(byteCnt);
      $display("Valstr issuing read cmd: currAddr = %d", addr);
      
      
      Bit#(32) byteIncr = ?;
      dramCmdQ_Imm.enq(DRAMReqType_Imm{rnw:True, addr: addr, data:?, numBytes:64, shiftval: 0});
      if (addr[5:0] == 0) begin
         byteIncr = 64; 
      end
      else begin
         byteIncr = extend(cmd.initNbytes);//extend(cmd.initOffset)//extend(initNbytes);
      end
      
      //$display("byteCnt = %d, byteIncr = %d, numBytes = %d", byteCnt, byteIncr, cmd.numBytes);
      if (byteCnt + byteIncr < cmd.numBytes) begin
         byteCnt <= byteCnt + byteIncr;
      end
      else begin
         byteCnt <= 0;
         state <= ProcHeader;
         cmdQ_Rd.deq();
         //cmdQ.deq;
         respHandleQ.enq(RespHandleType{numBytes:cmd.numBytes, initNbytes: cmd.initNbytes});
      end
   endrule
   
   Reg#(Bit#(64)) numBytes <- mkReg(0);
   rule procReadResp;// if (state == Proc && rnw);
      let args = respHandleQ.first;
      Bit#(32) byteIncr = 0;    
      
      if (firstLine_Rd) begin
         //let v <- dram.read();
         //$display("valstr get first read resp, args.initNbytes=%d, args.numBytes = %d",args.initNbytes, args.numBytes);
         let v <- toGet(dramDataQ).get();
         if ( args.initNbytes >= 8 ) begin
            lineBuf_Rd <= v >> 64;
            lineCnt_Rd <= args.initNbytes - 8;
            wordCnt_Rd <= 8;
            readRespQ.enq(truncate(v));
            byteIncr = 8;
         end
         else begin
            lineBuf_Rd <= v;
            lineCnt_Rd <= args.initNbytes;//64 - args.initOffset;
            wordCnt_Rd <= 8;
            if ( extend(args.initNbytes) >= args.numBytes) begin
               readRespQ.enq(truncate(v));
               byteIncr = args.numBytes;
            end
         end
            
         if ( args.numBytes > byteIncr )
            firstLine_Rd <= False;

      end
      else begin 
         
         $display("enquening result: lineBuf_Rd = %h\nwordBuf_Rd = %h\nlineCnt_Rd = %d, wordCnt_Rd = %d, byteCnt_Rd = %d, numBytes = %d",lineBuf_Rd, wordBuf_Rd, lineCnt_Rd, wordCnt_Rd, byteCnt_Rd, args.numBytes );
         
         byteIncr = 8;
         
         if ( lineCnt_Rd >= 16) begin
            readRespQ.enq(truncate({lineBuf_Rd[63:0], wordBuf_Rd} >> {wordCnt_Rd, 3'b0}));
            lineBuf_Rd <= lineBuf_Rd >> {wordCnt_Rd,3'b0};
            lineCnt_Rd <= lineCnt_Rd - extend(wordCnt_Rd);
            wordCnt_Rd <= 8;
         end
         else if ( lineCnt_Rd >= 8) begin
            readRespQ.enq(truncate(lineBuf_Rd));
            Vector#(8, Bit#(8)) rawData = unpack(truncate(lineBuf_Rd >> 64));
            wordBuf_Rd <= pack(reverse(rotateBy(reverse(rawData), truncate(unpack(lineCnt_Rd)-8))));
            if ( byteCnt_Rd + extend(lineCnt_Rd) < args.numBytes) begin
               let v <- toGet(dramDataQ).get();
               lineBuf_Rd <= v;
               wordCnt_Rd <= truncate(16-lineCnt_Rd);
               lineCnt_Rd <= 64;
            end
            else begin
               wordCnt_Rd <= 8;
               lineCnt_Rd <= 64;
               lineBuf_Rd <= lineBuf_Rd >> 64;
            end
         end
         else begin
            if ( byteCnt_Rd + extend(lineCnt_Rd) < args.numBytes) begin
               let v <- toGet(dramDataQ).get();
               
               Bit#(4) sft = truncate(8 - lineCnt_Rd);
               lineBuf_Rd <= v >> {sft,3'b0};
               lineCnt_Rd <= 56 + lineCnt_Rd;
               Vector#(8, Bit#(8)) rawData = unpack(truncate(lineBuf_Rd));
               Bit#(64) shiftData = pack(rotateBy(rawData, unpack(truncate(sft))));
               readRespQ.enq(truncate({v[63:0],shiftData} >> {sft,3'b0}));
               wordCnt_Rd <= 8;
            end
            else begin
               readRespQ.enq(truncate(lineBuf_Rd));
            end
         end
      end
         
      if (byteCnt_Rd + byteIncr <  args.numBytes) begin
         byteCnt_Rd <= byteCnt_Rd + byteIncr;
      end
      else begin
         //state <= Idle;
         if ( !firstLine_Rd)
            firstLine_Rd <= True;
         //byteCnt <= 0;
         byteCnt_Rd <= 0;
         respHandleQ.deq;
      end
   endrule
         
   Reg#(Bit#(32)) burstCnt <- mkReg(0);
   //FIFO#(Bit#(64)) wDataWord <- mkFIFO;
   //FIFO#(Bit#(64)) wDataWord <- mkSizedBRAMFIFO(131072);
   FIFO#(Bit#(64)) wDataWord <- mkSizedBRAMFIFO(512);
   //FIFO#(Bit#(64)) wDataWord <- mkSizedBRAMFIFO(65536);
   rule driveWriteCmd if (state == Proc);// && !cmdQ_Wr.first().rnw);
      let cmd = cmdQ_Wr.first();
      
      let currAddr = cmd.currAddr + extend(byteCnt_Wr);
      
      if (firstLine) begin
         wordBuf_Wr <= wDataWord.first;
         wordCnt_Wr <= 8;
         wDataWord.deq();
         //numBursts <= numBursts - 1;
         burstCnt <= burstCnt + 1;
         firstLine <= False;
         lineCnt_Wr <= cmd.initNbytes;//64 - cmd.initOffset; 
      end
      else begin
         if (lineCnt_Wr > extend(wordCnt_Wr) ) begin
            
            lineBuf_Wr <= truncate({wordBuf_Wr,lineBuf_Wr} >> {wordCnt_Wr, 3'b0});
            lineCnt_Wr <= lineCnt_Wr - extend(wordCnt_Wr);
            wordCnt_Wr <= 8;
            
            $display("Valstr write: lineBuf_Wr = %h\nlineCnt_Wr = %d,  wordCnt_Wr = %d, burstCnt = %d, cmd.numBurst = %d, numBytes = %d", lineBuf_Wr, lineCnt_Wr, wordCnt_Wr, burstCnt, cmd.numBursts, cmd.numBytes);
            
            if ( burstCnt < cmd.numBursts/*numBursts > 0*/ ) begin
               wordBuf_Wr <= wDataWord.first;
               wDataWord.deq;
               //$display("newData Got: %h, numBursts = %d",wDataWord.first, numBursts);
               //numBursts <= numBursts - 1;
               burstCnt <= burstCnt + 1;
            end
            else begin
               Bit#(7) nBytes = truncate(cmd.numBytes - byteCnt_Wr);
               $display("ValStr write(Last): currAddr = %d, data = %h, nBytes = %d",currAddr, {wordBuf_Wr,lineBuf_Wr} >> {lineCnt_Wr,3'b0}, nBytes);
               Bit#(6) offset = truncate(currAddr);
               //dram.write(currAddr, truncate({wordBuf_Wr,lineBuf_Wr} >> {lineCnt_Wr, 3'b0}) >> {offset,3'b0}, truncate(numBytes));
               //dramCmdQ_Imm.enq(DRAMReq{rnw:False, addr: currAddr, data:truncate({wordBuf_Wr,lineBuf_Wr} >> {lineCnt_Wr, 3'b0}) >> {offset,3'b0}, numBytes:nBytes});
               dramCmdQ_Imm.enq(DRAMReqType_Imm{rnw:False, addr: currAddr, data:truncateLSB({wordBuf_Wr,lineBuf_Wr}), numBytes:nBytes, shiftval: truncate(lineCnt_Wr) + offset - 8});
               //state <= Idle;
               //cmdQ.deq;
               cmdQ_Wr.deq();
               firstLine <= True;
               firstLine2 <= True; 
               burstCnt <= 0;
               byteCnt_Wr <= 0;
               state <= ProcHeader;
            end
            
         end
         else begin
            /*
            if ( currAddr[5:0] == 0) begin
               //currAddr <= currAddr + 64;
               byteCnt_Wr = byteCnt_Wr + 64;
            end
            else begin
               currAddr <= (currAddr & ~(extend(6'b111111))) + 64;
            end
            */
            Bit#(7) nBytes = ?;
            Bit#(6) offset = truncate(currAddr);
            if (firstLine2) begin
               nBytes = cmd.initNbytes;
               if ( byteCnt_Wr + extend(nBytes) < cmd.numBytes)
                  firstLine2 <= False;
            end
            else if ( byteCnt_Wr + 64 > cmd.numBytes/*numBytes < 64*/) begin
               nBytes = truncate(cmd.numBytes-byteCnt_Wr);   
            end
            else begin
               nBytes = 64;
            end
            
            
            
            if ( byteCnt_Wr + extend(nBytes) >= cmd.numBytes /*numBytes <= extend(nBytes)*/) begin
               //state <= Idle;
               byteCnt_Wr <= 0;
               //cmdQ.deq;
               cmdQ_Wr.deq();
               firstLine <= True;
               if (!firstLine2)
                  firstLine2 <= True; 
               burstCnt <= 0;
               state <= ProcHeader;
            end
            else begin
               byteCnt_Wr <= byteCnt_Wr + extend(nBytes);
            end
            
            //$display("Valstr write: initNbytes = %d", initNbytes);
            //numBytes <= numBytes - extend(nBytes);
            
            $display("ValStr write(Normal): currAddr = %d, data = %h, nBytes = %d",currAddr, ({wordBuf_Wr,lineBuf_Wr} >> (lineCnt_Wr << 3)) >> {offset,3'b0}, nBytes);
            //dram.write(currAddr, truncate({wordBuf_Wr,lineBuf_Wr} >> (lineCnt_Wr << 3)) >> {offset,3'b0}, nBytes);
            //dramCmdQ_Imm.enq(DRAMReq{rnw:False, addr: currAddr, data:truncate({wordBuf_Wr,lineBuf_Wr} >> (lineCnt_Wr << 3)) >> {offset,3'b0}, numBytes:nBytes});
            dramCmdQ_Imm.enq(DRAMReqType_Imm{rnw:False, addr: currAddr, data:truncateLSB({wordBuf_Wr,lineBuf_Wr}), numBytes:nBytes, shiftval: truncate(lineCnt_Wr)+offset-8});
            wordBuf_Wr <= wordBuf_Wr >> (lineCnt_Wr << 3);
            lineCnt_Wr <= 64;
            wordCnt_Wr <= wordCnt_Wr - truncate(lineCnt_Wr);
         end
      end
   endrule
            
      
   Wire#(BurstReq) rdReq <- mkWire;
   Wire#(BurstReq) wrReq <- mkWire;
   Wire#(Bit#(64)) rdDta <- mkWire;
   Wire#(Bit#(64)) wrDta <- mkWire;
      
   
   method Action readReq(Bit#(64) startAddr, Bit#(64) nBytes);// if (state == Idle);
      $display("Valuestr Get read req, startAddr = %d, nBytes = %d, reqId = %d", startAddr, nBytes, reqCnt);
      Bit#(6) offset_local = truncate(startAddr + fromInteger(valueOf(TDiv#(ValHeaderSz,8))));
      //initNbytes <= 64 - extend(offset_local);
      cmdQ.enq(CmdType{currAddr: startAddr,initNbytes: 64 - extend(offset_local), numBytes:truncate(nBytes), rnw: True});
      reqCnt <= reqCnt + 1;
   
      rdReq <= BurstReq{addr: startAddr, nBytes: nBytes};
   endmethod
   
   method ActionValue#(Bit#(64)) readVal();
      let d = readRespQ.first;
      readRespQ.deq;
      rdDta <= d;
      return d;
   endmethod
   
   method Action writeReq(Bit#(64) startAddr, Bit#(64) nBytes);// if (state == Idle);
      $display("Valuestr Get write req, startAddr = %d, nBytes = %d, reqId = %d", startAddr, nBytes, reqCnt);
      Bit#(6) offset_local = truncate(startAddr + fromInteger(valueOf(TDiv#(ValHeaderSz,8))));
      
      Bit#(32) numBursts = ?;
      if ( nBytes[2:0] == 0 )
         numBursts = zeroExtend(nBytes[31:3]);
      else
         numBursts = zeroExtend(nBytes[31:3]) + 1;

      cmdQ.enq(CmdType{currAddr:startAddr, initNbytes: 64 - extend(offset_local), numBytes: truncate(nBytes), numBursts: numBursts, rnw: False});
      //rnw <= False;
      reqCnt <= reqCnt + 1;
      wrReq <= BurstReq{addr: startAddr, nBytes: nBytes};
   endmethod
   
   method Action writeVal(Bit#(64) wrVal); 
      wDataWord.enq(wrVal);
      wrDta <= wrVal;
   endmethod
   
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

/*---------------------------------------------------------------------------------------*/
typedef enum {Idle, ReadHeader, ProcHeader} ValMng_State deriving (Bits, Eq);

interface ValAlloc_ifc;
   method Action newAddrReq(Bit#(64) nBytes, Bit#(64) oldAddr, Bool trade_in);
   method ActionValue#(Bit#(64)) newAddrResp();
endinterface

interface ValInit_ifc;
   method Action initValDelimit(Bit#(64) randMax1, Bit#(64) randMax2, Bit#(64) randMax3, Bit#(64) lgSz1, Bit#(64) lgSz2, Bit#(64) lgSz3);
   method Action initAddrDelimit(Bit#(64) lgOffset1, Bit#(64) lgOffset2, Bit#(64) lgOffset3);
endinterface

interface ValManage_ifc;
//   interface ValAccess_ifc valAccess;
   interface ValAlloc_ifc valAlloc;
   interface ValInit_ifc valInit;

   interface DRAMClient dramClient;   
   
endinterface


function Bit#(64) lfsr64(Bit#(64) x);
   return {x[62:0], (x[63] ~^ x[62] ~^ x[61] ~^ x[60])};
endfunction

function Bit#(2) findLRU(Vector#(4, ValHeader) x);
   Integer retval = ?;
   Vector#(4, Bit#(4)) maskVec = replicate(1);
   
   for (Integer i = 0; i < 4; i = i + 1) begin
      for (Integer j = 0; j < 4; j = j + 1) begin
         if ( x[i].timestamp > x[j].timestamp ) begin
            maskVec[i][j]  = 0;
         end
      end
   end
   
   for (Integer k = 0; k < 4; k = k + 1) begin
      if ( maskVec[k] != 0 ) begin
         retval = k;
      end
   end
   
   return fromInteger(retval);
endfunction


//(*synthesize*)
module mkValManager(ValManage_ifc);
   
   /* initialization registers */
   FIFOF#(Bit#(64)) oldAddr_1 <- mkSizedBypassFIFOF(3);
   FIFOF#(Bit#(64)) oldAddr_2 <- mkSizedBypassFIFOF(3);
   FIFOF#(Bit#(64)) oldAddr_3 <- mkSizedBypassFIFOF(3);
   
   Reg#(Bit#(64)) reg_lgSz1 <- mkRegU();
   Reg#(Bit#(64)) reg_lgSz2 <- mkRegU();
   Reg#(Bit#(64)) reg_lgSz3 <- mkRegU();
   Reg#(Bit#(64)) reg_randMax1 <- mkRegU();
   Reg#(Bit#(64)) reg_randMax2 <- mkRegU();
   Reg#(Bit#(64)) reg_randMax3 <- mkRegU();
   
   Reg#(Bit#(64)) reg_size1 <- mkRegU();
   Reg#(Bit#(64)) reg_size2 <- mkRegU();
   Reg#(Bit#(64)) reg_size3 <- mkRegU();
   
   //Reg#(Bit#(64)) reg_lgOffset1 <- mkRegU();
   //Reg#(Bit#(64)) reg_lgOffset2 <- mkRegU();
   //Reg#(Bit#(64)) reg_lgOffset3 <- mkRegU();
   
   Reg#(Bit#(64)) reg_offset1 <- mkRegU();
   Reg#(Bit#(64)) reg_offset2 <- mkRegU();
   Reg#(Bit#(64)) reg_offset3 <- mkRegU();
   
   Reg#(Bit#(64)) nextAddr1 <- mkRegU();
   Reg#(Bit#(64)) nextAddr2 <- mkRegU();
   Reg#(Bit#(64)) nextAddr3 <- mkRegU();
   
   Reg#(Bool) initValDone <- mkReg(False);
   Reg#(Bool) initAddrDone <- mkReg(False);
   
   Reg#(ValMng_State) state <- mkReg(Idle);
   
   Reg#(Bit#(64)) pseudo_random <- mkReg(1);
   
   Vector#(4, Reg#(Bit#(64))) addrBuf <- replicateM(mkRegU());
   Reg#(Vector#(4, ValHeader)) hdBuf <- mkRegU();
   Reg#(Bit#(3)) numOfReqs <- mkReg(0);
   Reg#(Bit#(3)) numOfResp <- mkReg(0);
   
   /* input and output queues */
   
   FIFO#(Tuple3#(Bit#(64), Bit#(64), Bool)) inputFifo <- mkFIFO();
   FIFO#(Bit#(64)) outputFifo <- mkFIFO();
   
   FIFO#(Bit#(2)) whichBinFifo <- mkBypassFIFO();
   FIFOF#(Tuple2#(Maybe#(Bit#(64)),Bit#(2))) toRdHeader <- mkFIFOF();
   
   FIFO#(DRAMReq) dramCmdQ <- mkFIFO();
   FIFO#(Bit#(512)) dramDataQ <- mkFIFO();

   
   rule push_OldAddr;
      let v = inputFifo.first();
      inputFifo.deq();
      
      let nBytes = tpl_1(v);
      let oldAddr = tpl_2(v);
      let trade_in = tpl_3(v);
      
      Bit#(2) whichBin;
      
      let totalSz = nBytes + (fromInteger(valueOf(ValHeaderSz))>>3);
      
      $display("totalSz = %d, regSize1 = %d, regSize2 = %d, regSize3 = %d", totalSz, reg_size1, reg_size2, reg_size3);
      if ( totalSz <= reg_size1) begin
         whichBin = 0;
      end
      else if ( totalSz <= reg_size2 ) begin
         whichBin = 1;
      end
      else begin
         whichBin = 2;
      end
      
      if ( trade_in ) begin
         if ( whichBin == 0 ) begin
            oldAddr_1.enq(oldAddr);
         end
         else if ( whichBin == 1) begin
            oldAddr_2.enq(oldAddr);
         end
         else begin
            oldAddr_3.enq(oldAddr);
         end
      end
      
      whichBinFifo.enq(whichBin);
           
   endrule
      
   rule alloc_Addr;
      let whichBin = whichBinFifo.first;
      whichBinFifo.deq();
      
      Maybe#(Bit#(64)) newAddr = tagged Invalid;
      
      
      if ( whichBin == 0 ) begin
         if ( oldAddr_1.notEmpty ) begin
            newAddr = tagged Valid oldAddr_1.first;
            oldAddr_1.deq;
         end
         else if (nextAddr1 < reg_offset2) begin
            newAddr = tagged Valid nextAddr1;
            nextAddr1 <= nextAddr1 + reg_size1;
         end
      end
      else if ( whichBin == 1 ) begin
         if ( oldAddr_2.notEmpty ) begin
            newAddr = tagged Valid oldAddr_2.first;
            oldAddr_2.deq;
         end
         else if (nextAddr2 < reg_offset3) begin
            newAddr = tagged Valid nextAddr2;
            nextAddr2 <= nextAddr2 + reg_size2;
         end
      end
      else begin
         if ( oldAddr_3.notEmpty ) begin
            newAddr = tagged Valid oldAddr_3.first;
            oldAddr_3.deq;
         end
         else if (nextAddr3 < zeroExtend(29'd-1)) begin
            newAddr = tagged Valid nextAddr3;
            nextAddr3 <= nextAddr3 + reg_size3;
         end
      end
      if (!isValid(newAddr)) $display("Out of addresses for bin = %d", whichBin);
      toRdHeader.enq(tuple2(newAddr, whichBin));
   endrule
   
   rule rdHeader if (state == Idle && toRdHeader.notEmpty);
      let d = toRdHeader.first;
      let retval = tpl_1(d);
      
      case (retval) matches
         tagged Valid .v: begin
            outputFifo.enq(v);
            toRdHeader.deq;
         end
         tagged Invalid: begin
            state <= ReadHeader;
            numOfReqs <= 0;
            numOfResp <= 0;
           end
      endcase
   endrule

   rule issueRd if ( state == ReadHeader && numOfReqs < 4);
      let d = toRdHeader.first;
      let whichBin = tpl_2(d);
      
     
      pseudo_random <= lfsr64(pseudo_random);
      Bit#(64) addr;
      if (whichBin == 0) begin
         addr = reg_offset1 + ((reg_randMax1 & pseudo_random) << reg_lgSz1);
      end
      else if (whichBin == 1) begin
         addr = reg_offset2 + ((reg_randMax2 & pseudo_random) << reg_lgSz2);
      end
      else begin
         addr = reg_offset3 + ((reg_randMax3 & pseudo_random) << reg_lgSz3);
      end
      
      addrBuf[numOfReqs] <= addr;
      //dram.readReq(addr,64);
      dramCmdQ.enq(DRAMReq{rnw:True, addr: addr, data:?, numBytes:64});
      
      numOfReqs <= numOfReqs + 1;
      
   endrule
   
   rule collectRd if ( state == ReadHeader );
      let old_hdBuf = hdBuf;
      if ( numOfResp < 4 ) begin
         //let d <- dram.read;
         let d <- toGet(dramDataQ).get();
         old_hdBuf[numOfResp] = unpack(d[511: valueOf(TSub#(512,ValHeaderSz))]);
         numOfResp <= numOfResp + 1;
      end
      else begin
         state <= ProcHeader;
      end
      hdBuf <= old_hdBuf;
   endrule
   
   rule procHd if ( state == ProcHeader) ;
      let ind = findLRU(hdBuf);
      outputFifo.enq(addrBuf[ind]);
      toRdHeader.deq();
      state <= Idle;
   endrule
      

   interface DRAMClient dramClient;
      interface Get request = toGet(dramCmdQ);
      interface Put response = toPut(dramDataQ);
   endinterface      
   
   interface ValAlloc_ifc valAlloc;
      method Action newAddrReq(Bit#(64) nBytes, Bit#(64) oldAddr, Bool trade_in) if (initValDone && initAddrDone);
         inputFifo.enq(tuple3(nBytes, oldAddr, trade_in));
      endmethod
      method ActionValue#(Bit#(64)) newAddrResp() if (initValDone && initAddrDone);
         let retval = outputFifo.first();
         outputFifo.deq();
         return retval;
      endmethod
   endinterface

   interface ValInit_ifc valInit;
      method Action initValDelimit(Bit#(64) randMax1, Bit#(64) randMax2, Bit#(64) randMax3, Bit#(64) lgSz1, Bit#(64) lgSz2, Bit#(64) lgSz3) if (!initValDone);
         reg_randMax1 <= randMax1;
         reg_randMax2 <= randMax2;
         reg_randMax3 <= randMax3;
 
         reg_lgSz1 <= lgSz1;
         reg_lgSz2 <= lgSz2;
         reg_lgSz3 <= lgSz3;
         reg_size1 <= 1 << lgSz1;
         reg_size2 <= 1 << lgSz2;
         reg_size3 <= 1 << lgSz3;
         initValDone <= True;
      endmethod
      method Action initAddrDelimit(Bit#(64) offset1, Bit#(64) offset2, Bit#(64) offset3) if (!initAddrDone);
         //reg_lgOffset1 <= lgOffset1;
         //reg_lgOffset2 <= lgOffset2;
         //reg_lgOffset3 <= lgOffset3;
         
         reg_offset1 <= offset1;
         reg_offset2 <= offset2;
         reg_offset3 <= offset3;
   
         nextAddr1 <= offset1;
         nextAddr2 <= offset2;
         nextAddr3 <= offset3;
         initAddrDone <= True;
      endmethod
   endinterface
endmodule

endpackage: Valuestr

