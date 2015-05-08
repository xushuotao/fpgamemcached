import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import LFSR::*;
import Vector::*;
import GetPut::*;
import LFSR::*;
import ClientServer::*;
import ClientServerHelper::*;

import DRAMCommon::*;
import ValuestrCommon::*;

/*---------------------------------------------------------------------------------------*/
typedef enum {Idle, ReadHeader, ProcHeader} ValMng_State deriving (Bits, Eq);

/*interface ValAllocIFC;
   method Action newAddrReq(Bit#(64) nBytes, Bit#(64) oldAddr, Bool trade_in);
   method ActionValue#(Bit#(64)) newAddrResp();
endinterface*/


interface ValManage_ifc;
   interface ValAllocServer server;
   
   interface ValManageInitIFC valInit;

   interface DRAM_LOCK_Client dramClient;   
   
endinterface


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


(*synthesize*)
module mkValManager(ValManage_ifc);
   
   /* initialization registers */
   FIFOF#(Bit#(32)) oldAddr_1 <- mkSizedBypassFIFOF(3);
   FIFOF#(Bit#(32)) oldAddr_2 <- mkSizedBypassFIFOF(3);
   FIFOF#(Bit#(32)) oldAddr_3 <- mkSizedBypassFIFOF(3);
   
   Reg#(Bit#(32)) reg_lgSz1 <- mkRegU();
   Reg#(Bit#(32)) reg_lgSz2 <- mkRegU();
   Reg#(Bit#(32)) reg_lgSz3 <- mkRegU();
   Reg#(Bit#(32)) reg_randMax1 <- mkRegU();
   Reg#(Bit#(32)) reg_randMax2 <- mkRegU();
   Reg#(Bit#(32)) reg_randMax3 <- mkRegU();
   
   Reg#(Bit#(32)) reg_size1 <- mkRegU();
   Reg#(Bit#(32)) reg_size2 <- mkRegU();
   Reg#(Bit#(32)) reg_size3 <- mkRegU();
   
   //Reg#(Bit#(32)) reg_lgOffset1 <- mkRegU();
   //Reg#(Bit#(32)) reg_lgOffset2 <- mkRegU();
   //Reg#(Bit#(32)) reg_lgOffset3 <- mkRegU();
   
   Reg#(Bit#(32)) reg_offset1 <- mkRegU();
   Reg#(Bit#(32)) reg_offset2 <- mkRegU();
   Reg#(Bit#(32)) reg_offset3 <- mkRegU();
   
   Reg#(Bit#(32)) nextAddr1 <- mkRegU();
   Reg#(Bit#(32)) nextAddr2 <- mkRegU();
   Reg#(Bit#(32)) nextAddr3 <- mkRegU();
   
   Reg#(Bool) initValDone <- mkReg(False);
   Reg#(Bool) initAddrDone <- mkReg(False);
   
      
   Vector#(4, Reg#(Bit#(32))) addrBuf <- replicateM(mkRegU());
   Reg#(Vector#(4, ValHeader)) hdBuf <- mkRegU();
   Reg#(Bit#(3)) numOfReqs <- mkReg(0);
   Reg#(Bit#(3)) numOfResp <- mkReg(0);
   
   /* input and output queues */
   
   FIFO#(ValAllocReqT) inputFifo <- mkFIFO();
   FIFO#(ValAllocRespT) outputFifo <- mkFIFO();

   
   FIFO#(Bit#(2)) whichBinFifo <- mkBypassFIFO();
   FIFOF#(Tuple2#(Maybe#(Bit#(32)),Bit#(2))) toRdHeader <- mkFIFOF();
   
   FIFO#(DRAM_LOCK_Req) dramCmdQ <- mkFIFO();
   FIFO#(Bit#(512)) dramDataQ <- mkFIFO();

   
   rule push_OldAddr if ( initValDone && initAddrDone);
      let v = inputFifo.first();
      inputFifo.deq();
      
      let nBytes = v.nBytes;
      let oldAddr = v.oldAddr;
      let oldNBytes = v.oldNBytes;
      let trade_in = v.trade_in;
      
      Bit#(2) whichBin_old;

      let oldSz = oldNBytes + (fromInteger(valueOf(ValHeaderSz))>>3);
      $display("trade_in = %d, nBytes = %d, oldAddr = %d, oldNBytes = %d", trade_in, nBytes, oldAddr, oldNBytes);
      $display("oldSz = %d, regSize1 = %d, regSize2 = %d, regSize3 = %d", oldSz, reg_size1, reg_size2, reg_size3);
            
      if ( oldSz <= reg_size1) begin
         whichBin_old = 0;
      end
      else if ( oldSz <= reg_size2 ) begin
         whichBin_old = 1;
      end
      else begin
         whichBin_old = 2;
      end
      
      if ( trade_in ) begin
         if ( whichBin_old == 0 ) begin
            oldAddr_1.enq(oldAddr);
         end
         else if ( whichBin_old == 1) begin
            oldAddr_2.enq(oldAddr);
         end
         else begin
            oldAddr_3.enq(oldAddr);
         end
      end
      
      Bit#(2) whichBin;
      let totalSz = nBytes + (fromInteger(valueOf(ValHeaderSz))>>3);
      if ( totalSz <= reg_size1) begin
         whichBin = 0;
      end
      else if ( totalSz <= reg_size2 ) begin
         whichBin = 1;
      end
      else begin
         whichBin = 2;
      end
      $display("whichbin = %d", whichBin);
      whichBinFifo.enq(whichBin);
           
   endrule
      
   rule alloc_Addr;
      let whichBin = whichBinFifo.first;
      whichBinFifo.deq();
      
      Maybe#(Bit#(32)) newAddr = tagged Invalid;
      
      
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
      $display("Addr = %d", fromMaybe(?, newAddr));
      if (!isValid(newAddr)) $display("Out of addresses for bin = %d", whichBin);
      toRdHeader.enq(tuple2(newAddr, whichBin));
   endrule
      
   Reg#(Bit#(2)) reqCnt <- mkReg(0);
   let lfsr <- mkLFSR_32;

   FIFO#(Tuple3#(Maybe#(Bit#(32)),Bit#(2), Vector#(4, Bit#(32)))) readRespHandleQ <- mkFIFO();
   rule issueRd;
      let d = toRdHeader.first;
      let whichBin = tpl_2(d);
              
      
      Bit#(32) addr = ?;
      Bool doReadHeader = !isValid(tpl_1(d));
      let addrVect = readVReg(addrBuf);
               
      if ( doReadHeader ) begin
         let pseudo_random = lfsr.value;
         lfsr.next();
         
         if (whichBin == 0) begin
            addr = reg_offset1 + ((reg_randMax1 & pseudo_random) << reg_lgSz1);
         end
         else if (whichBin == 1) begin
            addr = reg_offset2 + ((reg_randMax2 & pseudo_random) << reg_lgSz2);
         end
         else begin
            addr = reg_offset3 + ((reg_randMax3 & pseudo_random) << reg_lgSz3);
         end
         addrVect[reqCnt] = addr;
         addrBuf[reqCnt] <= addr;
         $display("Value Evict:: DRAMCmd, addr = %d, numBytes = %d", addr, valueOf(ValHeaderBytes));
         dramCmdQ.enq(DRAM_LOCK_Req{initlock: False, ignoreLock: True, lock: False, rnw:True, addr: extend(addr), data:?, numBytes:fromInteger(valueOf(ValHeaderBytes))});
         reqCnt <= reqCnt + 1;
      end
      
      if ( reqCnt == 0 && !doReadHeader) begin
         readRespHandleQ.enq(tuple3(tpl_1(d),tpl_2(d),?));
         toRdHeader.deq();
      end
      else if (reqCnt + 1 == 0) begin
         //readRespHandleQ.enq(d);
         readRespHandleQ.enq(tuple3(tpl_1(d),tpl_2(d), addrVect));
         toRdHeader.deq();
      end

      
   endrule
   
   Reg#(Bit#(2)) respCnt <- mkReg(0);
   rule collectRd;
      let v = readRespHandleQ.first();
      let addrBuf = tpl_3(v);
      Bool doReadHeader = !isValid(tpl_1(v));
      let new_hdBuf = hdBuf;      
      
      if ( doReadHeader) begin
         let d <- toGet(dramDataQ).get();
         new_hdBuf[respCnt] = unpack(truncate(pack(d)));//unpack(d[511: valueOf(TSub#(512,ValHeaderSz))]);
         hdBuf <= new_hdBuf;
         respCnt <= respCnt + 1;
      end

      if (respCnt == 0 && !doReadHeader) begin
         outputFifo.enq(ValAllocRespT{newAddr: fromMaybe(?, tpl_1(v)), doEvict: False});
         readRespHandleQ.deq();
      end
      else if (respCnt + 1 == 0 ) begin
         let ind = findLRU(new_hdBuf);
         let hdr = new_hdBuf[ind];
         
         outputFifo.enq(ValAllocRespT{newAddr: addrBuf[ind], doEvict: True, oldNBytes: hdr.nBytes, hv: hdr.hv, idx: hdr.idx});
         readRespHandleQ.deq();
      end
   endrule
      
      

   interface DRAM_LOCK_Client dramClient;
      interface Get request = toGet(dramCmdQ);
      interface Put response = toPut(dramDataQ);
   endinterface      
   
   interface ValAllocServer server = toServer(inputFifo, outputFifo);
   
   interface ValManageInitIFC valInit;
      method Action initValDelimit(Bit#(32) randMax1, Bit#(32) randMax2, Bit#(32) randMax3, Bit#(32) lgSz1, Bit#(32) lgSz2, Bit#(32) lgSz3) if (!initValDone);
         $display("ValueManager init Addr Delimiter: randMax1 = %d, randMax2 = %d, randMax3 = %d, lgSz1 = %d, lgSz2 = %d, lgSz3 = %d", randMax1, randMax2, randMax3, lgSz1, lgSz2, lgSz3);
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
         lfsr.seed(1);
      endmethod
      method Action initAddrDelimit(Bit#(32) offset1, Bit#(32) offset2, Bit#(32) offset3) if (!initAddrDone);
         //reg_lgOffset1 <= lgOffset1;
         //reg_lgOffset2 <= lgOffset2;
         //reg_lgOffset3 <= lgOffset3;
         $display("ValueManager init Addr Delimiter: offset1 = %d, offset2 = %d, offset3 = %d", offset1, offset2, offset3);
         
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
