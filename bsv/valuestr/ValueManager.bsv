import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;

import DRAMArbiterTypes::*;
import ValDRAMCtrlTypes::*;

/*---------------------------------------------------------------------------------------*/
typedef enum {Idle, ReadHeader, ProcHeader} ValMng_State deriving (Bits, Eq);

interface ValAllocIFC;
   method Action newAddrReq(Bit#(64) nBytes, Bit#(64) oldAddr, Bool trade_in);
   method ActionValue#(Bit#(64)) newAddrResp();
endinterface

interface ValInitIFC;
   method Action initValDelimit(Bit#(64) randMax1, Bit#(64) randMax2, Bit#(64) randMax3, Bit#(64) lgSz1, Bit#(64) lgSz2, Bit#(64) lgSz3);
   method Action initAddrDelimit(Bit#(64) lgOffset1, Bit#(64) lgOffset2, Bit#(64) lgOffset3);
endinterface

interface ValManage_ifc;
//   interface ValAccess_ifc valAccess;
   interface ValAllocIFC valAlloc;
   interface ValInitIFC valInit;

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
      //if ( !cmplBufQuery.search(addr) ) begin
      addrBuf[numOfReqs] <= addr;
      dramCmdQ.enq(DRAMReq{rnw:True, addr: addr, data:?, numBytes:64});
      numOfReqs <= numOfReqs + 1;
      //end
      
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
   
   rule procHd if ( state == ProcHeader) ; // 
      let ind = findLRU(hdBuf);
      outputFifo.enq(addrBuf[ind]);
      toRdHeader.deq();
      state <= Idle;
   endrule
      

   interface DRAMClient dramClient;
      interface Get request = toGet(dramCmdQ);
      interface Put response = toPut(dramDataQ);
   endinterface      
   
   interface ValAllocIFC valAlloc;
      method Action newAddrReq(Bit#(64) nBytes, Bit#(64) oldAddr, Bool trade_in) if (initValDone && initAddrDone);
         inputFifo.enq(tuple3(nBytes, oldAddr, trade_in));
      endmethod
      method ActionValue#(Bit#(64)) newAddrResp() if (initValDone && initAddrDone);
         let retval = outputFifo.first();
         outputFifo.deq();
         return retval;
      endmethod
   endinterface

   interface ValInitIFC valInit;
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
