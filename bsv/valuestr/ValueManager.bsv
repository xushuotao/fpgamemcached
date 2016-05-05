import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import LFSR::*;
import Vector::*;
import GetPut::*;
import LFSR::*;
import ClientServer::*;
import ClientServerHelper::*;

import Fifo::*;
import HashtableTypes::*;

import HostFIFO::*;

import DRAMCommon::*;
import ValDRAMArbiter::*;
import ValuestrCommon::*;

import ParameterTypes::*;

/*---------------------------------------------------------------------------------------*/
typedef enum {Idle, ReadHeader, ProcHeader} ValMng_State deriving (Bits, Eq);

/*interface ValAllocIFC;
   method Action newAddrReq(Bit#(64) nBytes, Bit#(64) oldAddr, Bool trade_in);
   method ActionValue#(Bit#(64)) newAddrResp();
endinterface*/


interface ValManage_ifc;
   interface ValAllocServer server;
   
   interface ValManageInitIFC valInit;

   interface ValDRAMClient dramClient;
   
   interface Put#(Bool) ack;
   
   interface Vector#(3, IndicationServer#(Bit#(32))) indicationServers;
   
   method Action reset();
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


//(*synthesize*)
module mkValManager(ValManage_ifc);
   
   /* initialization registers */
   // FIFOF#(Bit#(32)) oldAddr_1 <- mkSizedBypassFIFOF(3);
   // FIFOF#(Bit#(32)) oldAddr_2 <- mkSizedBypassFIFOF(3);
   // FIFOF#(Bit#(32)) oldAddr_3 <- mkSizedBypassFIFOF(3);
   HostFIFO#(Bit#(32)) oldAddr_1 <- mkHostFIFO(32, 16);
   HostFIFO#(Bit#(32)) oldAddr_2 <- mkHostFIFO(32, 16);
   HostFIFO#(Bit#(32)) oldAddr_3 <- mkHostFIFO(32, 16);
   
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
   
   FIFO#(ValAllocReqT) inputFifo <- mkSizedFIFO(valueOf(NUM_STAGES));
   FIFO#(ValAllocRespT) outputFifo <- mkFIFO();

   
   //FIFO#(Maybe#(Bit#(2))) whichBinFifo <- mkBypassFIFO();
   FIFO#(Maybe#(Bit#(2))) whichBinFifo <- mkFIFO();
   FIFO#(Bool) rtnNewQ <- mkFIFO();
   FIFOF#(Tuple2#(Maybe#(Bit#(32)),Bit#(2))) toRdHeader <- mkFIFOF();
   
   FIFO#(DRAM_ACK_Req) dramCmdQ <- mkFIFO();
   FIFO#(Bit#(512)) dramDataQ <- mkFIFO();

   Reg#(Bit#(32)) reqCnt_0 <- mkReg(0);
   rule push_OldAddr if ( initValDone && initAddrDone);
      let v = inputFifo.first();
      inputFifo.deq();
      
      let nBytes = v.nBytes;
      let oldAddr = v.oldAddr;
      let oldNBytes = v.oldNBytes;
      //let trade_in = v.trade_in;
      let rtn_old = v.rtn_old;
      let req_new = v.req_new;

      
      Bit#(2) whichBin_old;

      let oldSz = oldNBytes + (fromInteger(valueOf(ValHeaderSz))>>3);
      $display("ValManager:: return_old = %d, request_new = %d, nBytes = %d, oldAddr = %d, oldNBytes = %d, reqCnt = %d", rtn_old, req_new,  nBytes, oldAddr, oldNBytes, reqCnt_0);
      $display("ValManager:: oldSz = %d, regSize1 = %d, regSize2 = %d, regSize3 = %d", oldSz, reg_size1, reg_size2, reg_size3);
            
      reqCnt_0 <= reqCnt_0 + 1;
      
      if ( oldSz <= reg_size1) begin
         whichBin_old = 0;
      end
      else if ( oldSz <= reg_size2 ) begin
         whichBin_old = 1;
      end
      else begin
         whichBin_old = 2;
      end
      
      if ( rtn_old ) begin
         $display("return_old...whichBin_old = %d", whichBin_old);
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
      
      Maybe#(Bit#(2)) whichBin = tagged Invalid;
      let totalSz = nBytes + (fromInteger(valueOf(ValHeaderSz))>>3);
      if ( req_new ) begin
         if ( totalSz <= reg_size1) begin
            whichBin = tagged Valid 0;
         end
         else if ( totalSz <= reg_size2 ) begin
            whichBin = tagged Valid 1;
         end
         else begin
            whichBin = tagged Valid 2;
         end
         $display("whichbin = %d", whichBin);
      end
      whichBinFifo.enq(whichBin);
      rtnNewQ.enq(req_new);
           
   endrule
   Reg#(Bit#(32)) reqCnt_2 <- mkReg(0);
   Reg#(Bit#(32)) reqCnt_3 <- mkReg(0);
   SFifo#(NUM_STAGES, Bit#(32), Bit#(32)) sfifo <- mkCFSFifo(eq);      
   Reg#(Bool) lock <- mkReg(False);
   rule alloc_Addr if (!lock);
      let whichBinData = whichBinFifo.first;
      whichBinFifo.deq();
      let whichBin = fromMaybe(?, whichBinData);
      let returnNew <- toGet(rtnNewQ).get();
      
      Maybe#(Bit#(32)) newAddr = tagged Invalid;      
      if ( isValid(whichBinData) ) begin

         
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
      end
      else begin
         newAddr = tagged Valid 0;
      end
      
      $display("ValManager:: Addr = %d, reqCnt = %d", fromMaybe(?, newAddr), reqCnt_3);
      reqCnt_3 <= reqCnt_3 + 1;
      if (!isValid(newAddr) && returnNew) begin
         $display("Out of addresses for bin = %d", whichBin);
         toRdHeader.enq(tuple2(newAddr, whichBin));
         lock <= True;
      end
      else begin
         outputFifo.enq(ValAllocRespT{newAddr: fromMaybe(?, newAddr), doEvict: False});
         $display("ValManager:: new non-evict addr = %d found, reqCnt = %d", fromMaybe(?, newAddr), reqCnt_2);
         reqCnt_2 <= reqCnt_2 + 1;
         if ( returnNew)
            sfifo.enq(fromMaybe(?,newAddr));
      end
   endrule
      
   Reg#(Bit#(2)) reqCnt <- mkReg(0);
   let lfsr_1 <- mkLFSR_32;
   let lfsr_2 <- mkLFSR_32;
   let lfsr_3 <- mkLFSR_32;

   //FIFO#(Tuple3#(Maybe#(Bit#(32)),Bit#(2), Vector#(4, Bit#(32)))) readRespHandleQ <- mkFIFO();
   

   
   Reg#(Bit#(1)) state <- mkReg(0);
   
   //Vector#(4, Reg#(Bit#(32))) addrBuf <- replicateM(mkRegU());
   Reg#(Maybe#(Bit#(32))) retval_Reg <- mkRegU();
   Reg#(Bit#(2)) whichBin_reg <- mkRegU();

   FIFO#(Bit#(32)) addrFIFO <- mkFIFO();
   
   
   Vector#(3, FIFO#(Bit#(32))) addrQs <- replicateM(mkFIFO);
   //FIFO#(Bit#(32)) addrQ_1 <- mkFIFO();
   rule generateAddr_1 if  ( initValDone && initAddrDone);
      let pseudo_random = lfsr_1.value;
      lfsr_1.next();
      let addr = reg_offset1 + ((reg_randMax1 & pseudo_random) << reg_lgSz1);
      $display("generate addr 1, addr = %d", addr);
      //addrQ_1.enq(addr);
      addrQs[0].enq(addr);
   endrule

   //FIFO#(Bit#(32)) addrQ_2 <- mkFIFO();
   rule generateAddr_2 if  ( initValDone && initAddrDone);
      let pseudo_random = lfsr_2.value;
      lfsr_2.next();
      let addr = reg_offset2 + ((reg_randMax2 & pseudo_random) << reg_lgSz2);
      $display("generate addr 2, addr = %d", addr);
      //addrQ_2.enq(addr);
      addrQs[1].enq(addr);
   endrule

   //FIFO#(Bit#(32)) addrQ_3 <- mkFIFO();
   rule generateAddr_3 if  ( initValDone && initAddrDone);
      let pseudo_random = lfsr_3.value;
      lfsr_3.next();
      let addr = reg_offset3 + ((reg_randMax3 & pseudo_random) << reg_lgSz3);
      $display("generate addr 3, addr = %d", addr);
      //addrQ_3.enq(addr);
      addrQs[2].enq(addr);
   endrule
   
   
   rule issueRd if (state == 0);
      let d = toRdHeader.first;
      
      let whichBin = tpl_2(d);
      
      Bit#(32) addr = ?;
      Bool doReadHeader = !isValid(tpl_1(d));
      //let addrVect = readVReg(addrBuf);
               
      if ( doReadHeader ) begin
         let addr = addrQs[whichBin].first;
         // if (whichBin == 0) begin
         //    //addr = reg_offset1 + ((reg_randMax1 & pseudo_random) << reg_lgSz1);
         //    //addr <- toGet(addrQ_1).get();
         //    //$display("Murali says you suck");
         // end
         // else if (whichBin == 1) begin
         //    //addr = reg_offset2 + ((reg_randMax2 & pseudo_random) << reg_lgSz2);
         //    addr <- toGet(addrQ_2).get();
         // end
         // else begin
         //    //addr = reg_offset3 + ((reg_randMax3 & pseudo_random) << reg_lgSz3);
         //    addr <- toGet(addrQ_3).get();
         // end
         if ( !sfifo.search(addr) ) begin
            //addrVect[reqCnt] = addr;
            addrBuf[reqCnt] <= addr;
            $display("Value Evict:: whichbin = %d, addr = %h", whichBin, addr);
            $display("Value Evict:: DRAMCmd, addr = %d, numBytes = %d, reqCnt = %d", addr, valueOf(ValHeaderBytes), reqCnt);
            dramCmdQ.enq(DRAM_ACK_Req{initlock: False, ignoreLock: True, lock: False, rnw:True, addr: extend(addr), data:?, numBytes:fromInteger(valueOf(ValHeaderBytes))});
            //addrFIFO.enq(addr);
            addrQs[whichBin].deq();
            reqCnt <= reqCnt + 1;
         end
      end
      
      if ( reqCnt == 0 && !doReadHeader) begin
         //readRespHandleQ.enq(tuple3(tpl_1(d),tpl_2(d),?));
         //retval_Reg <= tpl_1(d);
         //whichBin_reg <= tpl_2(d);
         //state <= 1;
         toRdHeader.deq();
         //outputFifo.enq(ValAllocRespT{newAddr: fromMaybe(?, tpl_1(d)), doEvict: False});
         //$display("ValManager:: newAddr found, reqCnt", reqCnt_2);
         //reqCnt_2 <= reqCnt_2 + 1;
      end
      else if (reqCnt + 1 == 0) begin
         //readRespHandleQ.enq(d);
         //readRespHandleQ.enq(tuple3(tpl_1(d),tpl_2(d), addrVect));
         retval_Reg <= tpl_1(d);
         //whichBin_reg <= tpl_2(d);
         state <= 1;
         toRdHeader.deq();
      end
   endrule
   
   // rule doDRAMRaw;
   //    let addr <- toGet(addrFIFO).get();
   //    dramCmdQ.enq(DRAM_ACK_Req{initlock: False, ignoreLock: True, lock: False, rnw:True, addr: extend(addr), data:?, numBytes:fromInteger(valueOf(ValHeaderBytes))});
   // endrule

   Reg#(Bit#(2)) respCnt <- mkReg(0);
   rule collectRd if (state == 1);
      //let v = readRespHandleQ.first();
      //let addrBuf = tpl_3(v);
      //Bool doReadHeader = !isValid(tpl_1(v));
      //Bool doReadHeader = !isValid(retval_Reg);
      let new_hdBuf = hdBuf;      
      
      //if ( doReadHeader) begin
      let d <- toGet(dramDataQ).get();
      new_hdBuf[respCnt] = unpack(truncate(pack(d)));//unpack(d[511: valueOf(TSub#(512,ValHeaderSz))]);
      hdBuf <= new_hdBuf;
      respCnt <= respCnt + 1;
      $display("Value Evict:: dramResp, respCnt = %d, hv = %h, idx = %d, timestamp = %d", respCnt, new_hdBuf[respCnt].hv, new_hdBuf[respCnt].idx, new_hdBuf[respCnt].timestamp);
      //end

      // if (respCnt == 0 && !doReadHeader) begin
      //    outputFifo.enq(ValAllocRespT{newAddr: fromMaybe(?, tpl_1(v)), doEvict: False});
      //    $display("ValManager:: newAddr found, reqCnt", reqCnt_2);
      //    reqCnt_2 <= reqCnt_2 + 1;
      //    readRespHandleQ.deq();
      //    state <= 0;
      // end
      // else 
      if (respCnt + 1 == 0 ) begin
         let ind = findLRU(new_hdBuf);
         let hdr = new_hdBuf[ind];
         $display("ValManager:: eviction addr = %d found, reqCnt", addrBuf[ind], reqCnt_2);
         reqCnt_2 <= reqCnt_2 + 1;
         outputFifo.enq(ValAllocRespT{newAddr: addrBuf[ind], doEvict: True, oldNBytes: hdr.nBytes, hv: hdr.hv, idx: hdr.idx});
         sfifo.enq(addrBuf[ind]);
         //readRespHandleQ.deq();
         state <= 0;
         lock <= False;
      end
   endrule
   
   Vector#(3, IndicationServer#(Bit#(32))) indSrv = newVector();
   indSrv[0] = oldAddr_1.indicationServer;
   indSrv[1] = oldAddr_2.indicationServer;
   indSrv[2] = oldAddr_3.indicationServer;
   
      
      

   interface ValDRAMClient dramClient;
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
         lfsr_1.seed(1);
         lfsr_2.seed(1);
         lfsr_3.seed(1);
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
   
   interface indicationServers = indSrv;
  
   interface Put ack;
      method Action put(Bool v);
         sfifo.deq();
      endmethod
   endinterface
   
   method Action reset();
      initValDone <= False;
      initAddrDone <= False;
   endmethod
endmodule
