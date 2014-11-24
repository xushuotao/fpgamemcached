package Valuestr;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;

import DRAMArbiterTypes::*;
import DRAMArbiter::*;

import Time::*;

typedef struct{
   Time_t timestamp;
   } ValHeader deriving (Bits, Eq);

/* constants definitions */

typedef SizeOf#(ValHeader) ValHeaderSz;

typedef TDiv#(ValHeaderSz, 512) HeaderBurstSz;


typedef enum {Idle, ProcHeader, Proc} ValAcc_State deriving (Bits, Eq);

typedef struct {
   Bit#(64) addr;
   Bit#(64) nBytes;
   } BurstReq deriving (Bits, Eq);



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
module mkValRawAccess#(Clk_ifc real_time)(ValAccess_ifc);
   
   Reg#(ValAcc_State) state <- mkReg(Idle);
   Reg#(Bool) rnw <- mkRegU();
   
   //Reg#(Bool) readChannelOpen <- mkReg(False);
   Reg#(Bit#(6)) initOffset <- mkRegU();
   Reg#(Bit#(7)) initNbytes <- mkRegU();
   Reg#(Bit#(64)) currAddr <- mkRegU();
   Reg#(Bit#(64)) byteCnt <- mkRegU();
   Reg#(Bit#(64)) numBytes <- mkRegU();
   Reg#(Bit#(64)) numBursts <- mkRegU();
   
   Reg#(Bit#(64)) byteCnt2 <- mkRegU();
   
   Reg#(Bool) firstLine <- mkRegU();
   Reg#(Bool) firstLine2 <- mkRegU();
   Reg#(Bit#(7)) lineCnt <- mkRegU();
   Reg#(Bit#(512)) lineBuf <- mkRegU();
   
   Reg#(Bit#(64)) wordBuf <- mkRegU();
   Reg#(Bit#(4)) wordCnt <- mkRegU();
   
   FIFO#(Bit#(64)) readRespQ <- mkFIFO();
   
   FIFO#(DRAMReq) dramCmdQ <- mkFIFO();
   FIFO#(Bit#(512)) dramDataQ <- mkFIFO();
   
   rule updateHeader if (state == ProcHeader);
      //$display("updateHeader: currAddr = %d, data = %h, nBytes = %d",currAddr, real_time.get_time, fromInteger(valueOf(TDiv#(SizeOf#(Time_t),8))));
      //dram.write(currAddr, extend(pack(real_time.get_time)),fromInteger(valueOf(TDiv#(SizeOf#(Time_t),8))));
      dramCmdQ.enq(DRAMReq{rnw:False, addr: currAddr, data:extend(pack(real_time.get_time)), numBytes:fromInteger(valueOf(TDiv#(SizeOf#(Time_t),8)))});
      //$display("updateHeader: nextAddr <= %d", currAddr + fromInteger(valueOf(TDiv#(ValHeaderSz,8))));
      currAddr <= currAddr + fromInteger(valueOf(TDiv#(ValHeaderSz,8)));
      state <= Proc;
   endrule
   
   rule driveReadCmd if (state == Proc && byteCnt < numBytes && rnw);
      $display("Valstr issuing read cmd: currAddr = %d", currAddr);
      //dram.readReq(currAddr, 64);
      dramCmdQ.enq(DRAMReq{rnw:True, addr: currAddr, data:?, numBytes:64});
      if (currAddr[5:0] == 0) begin
         currAddr <= currAddr + 64;
         byteCnt <= byteCnt + 64;
      end
      else begin
         currAddr <= (currAddr & ~(extend(6'b111111))) + 64;
         byteCnt <= byteCnt + extend(initNbytes);
      end
   endrule
   
        
   rule procReadResp if (state == Proc && rnw);
      if (byteCnt2 < numBytes) begin
         if (firstLine) begin
            //let v <- dram.read();
            let v <- toGet(dramDataQ).get();
            lineBuf <= v;
            firstLine <= False;
         end
         else begin 
          
            if (lineCnt >= extend(wordCnt) ) begin
               $display("enquening result: lineBuf = %h \nlineCnt = %d, wordCnt = %d, byteCnt2 = %d, numBytes = %d",lineBuf, lineCnt, wordCnt, byteCnt2, numBytes );
               //readRespQ.enq((wordBuf << {wordCnt,3'b0}) | (truncate(lineBuf) & ((1 << {wordCnt,3'b0}) - 1)));
               readRespQ.enq(truncate({lineBuf[63:0], wordBuf} >> {wordCnt, 3'b0}));
               byteCnt2 <= byteCnt2 + 8; //+ extend(wordCnt);
               
               if ( lineCnt == extend(wordCnt) && (byteCnt2 + 8 < numBytes) ) begin
                  //let v <- dram.read();
                  let v <- toGet(dramDataQ).get();
                  lineBuf <= v;
                  lineCnt <= 64;
               end
               else begin
                  lineBuf <= lineBuf >> {wordCnt, 3'b0};
                  lineCnt <= lineCnt - extend(wordCnt);
               end
               wordCnt <= 8;
            end
            else begin
               $display("shift wordBuf = %h \nlineCnt = %d, wordCnt = %d", wordBuf, lineCnt, wordCnt);
               wordBuf <= truncate({lineBuf[63:0],wordBuf} >> (lineCnt <<3));//(wordBuf << (lineCnt << 3)) | (truncate(lineBuf) & ((1 << (lineCnt << 3)) - 1));
               wordCnt <= wordCnt - truncate(lineCnt);
               lineCnt <= 64;
               if ( byteCnt2 + extend(lineCnt) < numBytes) begin
                  //let v <- dram.read();
                  let v <- toGet(dramDataQ).get();
                  lineBuf <= v;
               end
            end
         end       
      end
      else begin
         state <= Idle;
      end
   endrule
         
   FIFO#(Bit#(64)) wDataWord <- mkFIFO; 
   rule driveWriteCmd if (state == Proc && !rnw);
      if (firstLine) begin
         wordBuf <= wDataWord.first;
         wordCnt <= 8;
         wDataWord.deq();
         numBursts <= numBursts - 1;
         firstLine <= False;
      end
      else begin
         if (lineCnt > extend(wordCnt) ) begin
            
            lineBuf <= truncate({wordBuf,lineBuf} >> {wordCnt, 3'b0});
            lineCnt <= lineCnt - extend(wordCnt);
            wordCnt <= 8;
            
            //$display("Valstr write: lineBuf = %h\nlineCnt = %d, numBytes = %d, wordCnt = %d", lineBuf, lineCnt, numBytes, wordCnt);
            
            if ( numBursts > 0 ) begin
               wordBuf <= wDataWord.first;
               wDataWord.deq;
               //$display("newData Got: %h, numBursts = %d",wDataWord.first, numBursts);
               numBursts <= numBursts - 1;
            end
            else begin
               $display("ValStr write(Last): currAddr = %d, data = %h, nBytes = %d",currAddr, {wordBuf,lineBuf} >> {lineCnt,3'b0}, numBytes);
               Bit#(6) offset = truncate(currAddr);
               //dram.write(currAddr, truncate({wordBuf,lineBuf} >> {lineCnt, 3'b0}) >> {offset,3'b0}, truncate(numBytes));
               dramCmdQ.enq(DRAMReq{rnw:False, addr: currAddr, data:truncate({wordBuf,lineBuf} >> {lineCnt, 3'b0}) >> {offset,3'b0}, numBytes:truncate(numBytes)});
               state <= Idle;
            end
            
            
            
         end
         else begin
            if ( currAddr[5:0] == 0) begin
               currAddr <= currAddr + 64;
            end
            else begin
               currAddr <= (currAddr & ~(extend(6'b111111))) + 64;
            end
            
            Bit#(7) nBytes = ?;
            Bit#(6) offset = truncate(currAddr);
            if (firstLine2) begin
               nBytes = extend(initNbytes);
               firstLine2 <= False;
            end
            else if (numBytes < 64) begin
               nBytes = truncate(numBytes);   
            end
            else begin
               nBytes = 64;
            end
            
            if ( numBytes <= extend(nBytes)) begin
               state <= Idle;
            end
            
            //$display("Valstr write: initNbytes = %d", initNbytes);
            numBytes <= numBytes - extend(nBytes);
            $display("ValStr write(Normal): currAddr = %d, data = %h, nBytes = %d",currAddr, ({wordBuf,lineBuf} >> (lineCnt << 3)) >> {offset,3'b0}, nBytes);
            //dram.write(currAddr, truncate({wordBuf,lineBuf} >> (lineCnt << 3)) >> {offset,3'b0}, nBytes);
            dramCmdQ.enq(DRAMReq{rnw:False, addr: currAddr, data:truncate({wordBuf,lineBuf} >> (lineCnt << 3)) >> {offset,3'b0}, numBytes:nBytes});
            wordBuf <= wordBuf >> (lineCnt << 3);
            lineCnt <= 64;
            wordCnt <= wordCnt - truncate(lineCnt);
         end
      end
   endrule
            
      
   Wire#(BurstReq) rdReq <- mkWire;
   Wire#(BurstReq) wrReq <- mkWire;
   Wire#(Bit#(64)) rdDta <- mkWire;
   Wire#(Bit#(64)) wrDta <- mkWire;
      
   
   method Action readReq(Bit#(64) startAddr, Bit#(64) nBytes) if (state == Idle);
      $display("Valuestr Get read req, startAddr = %d, nBytes = %d", startAddr, nBytes);
      Bit#(6) offset_local = truncate(startAddr + fromInteger(valueOf(TDiv#(ValHeaderSz,8))));
      initNbytes <= 64 - extend(offset_local);
      state <= ProcHeader;
      
      currAddr <= startAddr;
      initOffset <= offset_local;
      
      lineCnt <= 64 - extend(offset_local);
      
      firstLine <= True;
      byteCnt <= 0;
      byteCnt2 <= 0;
      
      wordCnt <= 8;
      numBytes <= nBytes;
      if ( nBytes[2:0] == 0 )
         numBursts <= zeroExtend(nBytes[63:3]);
      else
         numBursts <= zeroExtend(nBytes[63:3]) + 1;
      
      rnw <= True;
   
      rdReq <= BurstReq{addr: startAddr, nBytes: nBytes};
   endmethod
   
   method ActionValue#(Bit#(64)) readVal();
      let d = readRespQ.first;
      readRespQ.deq;
      rdDta <= d;
      return d;
   endmethod
   
   method Action writeReq(Bit#(64) startAddr, Bit#(64) nBytes) if (state == Idle);
      $display("Valuestr Get write req, startAddr = %d, nBytes = %d", startAddr, nBytes);
      Bit#(6) offset_local = truncate(startAddr + fromInteger(valueOf(TDiv#(ValHeaderSz,8))));
      initNbytes <= 64 - extend(offset_local);//~offset_local + 1;
      state <= ProcHeader;
      
      currAddr <= startAddr;
      initOffset <= offset_local;
      
      lineCnt <= 64 - extend(offset_local);//extend(initNbytes);//~truncate(startAddr) & 7'b0111111
      
      firstLine <= True;
      firstLine2 <= True;
      byteCnt <= 0;
      byteCnt2 <= 0;
      numBytes <= nBytes;
      if ( nBytes[2:0] == 0 )
         numBursts <= zeroExtend(nBytes[63:3]);
      else
         numBursts <= zeroExtend(nBytes[63:3]) + 1;
   
      rnw <= False;
   
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
   method Action initValDelimit(Bit#(64) lgSz1, Bit#(64) lgSz2, Bit#(64) lgSz3);
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
   
   Reg#(Bit#(64)) reg_size1 <- mkRegU();
   Reg#(Bit#(64)) reg_size2 <- mkRegU();
   Reg#(Bit#(64)) reg_size3 <- mkRegU();
   
   Reg#(Bit#(64)) reg_lgOffset1 <- mkRegU();
   Reg#(Bit#(64)) reg_lgOffset2 <- mkRegU();
   Reg#(Bit#(64)) reg_lgOffset3 <- mkRegU();
   
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
      
      if (nBytes <= reg_size1) begin
         whichBin = 0;
      end
      else if ( nBytes <= reg_size2 ) begin
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
         addr = (reg_offset1 + pseudo_random << reg_lgSz1) & ( 1 << reg_lgOffset2 - 1);
      end
      else if (whichBin == 1) begin
         addr = (reg_offset2 + pseudo_random << reg_lgSz2) & ( 1 << reg_lgOffset3 - 1);
      end
      else begin
         addr = (reg_offset3 + pseudo_random << reg_lgSz3) & ( 1 << 29 - 1);
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
      method Action initValDelimit(Bit#(64) lgSz1, Bit#(64) lgSz2, Bit#(64) lgSz3) if (!initValDone);
         reg_lgSz1 <= lgSz1;
         reg_lgSz2 <= lgSz2;
         reg_lgSz3 <= lgSz3;
         reg_size1 <= 1 << lgSz1;
         reg_size2 <= 1 << lgSz2;
         reg_size3 <= 1 << lgSz3;
         initValDone <= True;
      endmethod
      method Action initAddrDelimit(Bit#(64) lgOffset1, Bit#(64) lgOffset2, Bit#(64) lgOffset3) if (!initAddrDone);
         reg_lgOffset1 <= lgOffset1;
         reg_lgOffset2 <= lgOffset2;
         reg_lgOffset3 <= lgOffset3;
         
         reg_offset1 <= 1 << lgOffset1;
         reg_offset2 <= 1 << lgOffset2;
         reg_offset3 <= 1 << lgOffset3;
   
         nextAddr1 <= 1 << lgOffset1;
         nextAddr2 <= 1 << lgOffset2;
         nextAddr3 <= 1 << lgOffset3;
         initAddrDone <= True;
      endmethod
   endinterface
endmodule

endpackage: Valuestr

