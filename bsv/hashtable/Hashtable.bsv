package Hashtable;

import FIFO::*;
import Vector::*;

import DRAMController::*;

import DDR3::*;

import Time::*;

import BRAM::*;

import Valuestr::*;

//`define DEBUG

typedef struct{
   Bit#(4) idle;
   Bit#(8) keylen; // key length
   Bit#(8) clsid; // slab class id
   Bit#(64) valAddr; // valueStore address
   Bit#(16) refcount;
   Time_t exptime; // expiration time
   Time_t currtime;// last accessed time
   Bit#(64) nBytes; //
   } ItemHeader deriving(Bits, Eq);

//`define HEADER_64_ALIGNED;

/* constants definition */
typedef enum {Idle, ProcHeader, ProcData, PrepWrite_0, PrepWrite_1, WriteHeader, WriteKeys} State deriving (Bits, Eq);
   
typedef Bit#(64) PhyAddr;

typedef SizeOf#(ItemHeader) HeaderSz;
   
typedef 64 LineWidth; // LineWidth 64/128/256/512

typedef TDiv#(LineWidth, 8) LineBytes;

typedef TLog#(LineBytes) LgLineBytes;

typedef TDiv#(HeaderSz, LineWidth) HeaderTokens;

typedef TSub#(HeaderSz,TMul#(LineWidth,TSub#(TDiv#(HeaderSz, LineWidth),1))) HeaderResidualSz;

typedef TDiv#(HeaderResidualSz, 8) HeaderResdualBytes;

typedef TLog#(LineWidth) LogLnWidth;

typedef TDiv#(512, LineWidth) NumWays;

typedef TMul#(256,8) MaxKeyLen;

typedef TAdd#(HeaderSz,MaxKeyLen) MaxItemSize;

typedef TDiv#(MaxItemSize, LineWidth) ItemOffset;

typedef TSub#(LineWidth, HeaderResidualSz) LnSz4Key;

`ifndef HEADER_64_ALIGNED
typedef TSub#(LnSz4Key, TMul#(64,TSub#(TDiv#(LnSz4Key,64),1))) DtaShiftSz;
`else
typedef 0 DtaShfitSz;
`endif

typedef TSub#(64, DtaShiftSz) KeyShiftSz;

interface HashtableInitIfc;
   method Action initTable(Bit#(64) lgOffset);
endinterface

interface HashtableIfc;
   method Action readTable(Bit#(8) keylen, Bit#(32) hv, Bit#(64) nBytes);
   method Action keyTokens(Bit#(64) keys);
   method ActionValue#(Tuple2#(Bit#(64), Bit#(64))) getValAddr();
   interface HashtableInitIfc init;
endinterface

function Bit#(TLog#(NumWays)) mask2ind (Bit#(NumWays) mask);
   /*Bit#(TLog#(NumWays)) retval = case (mask)
                                    1: 0;
                                    2: 1;
                                    4: 2;
                                    8: 3;
                                    16: 4;
                                    32: 5;
                                    64: 6;
                                    128: 7;
                                    default: 0;
                                 endcase;*/
   Bit#(TLog#(NumWays)) retval = ?;
   
   for (Integer i = 0; i < valueOf(NumWays); i = i + 1) begin
      if ((mask >> fromInteger(i))[0] == 1) begin
         retval = fromInteger(i);
      end
   end
   return retval;
endfunction

function Bit#(TLog#(NumWays)) findLRU (Vector#(NumWays, Time_t) timestamps);
   Integer retval = ?;
   
   Vector#(NumWays, Bit#(NumWays)) maskVec = replicate(1);
   for (Integer i = 0; i < valueOf(NumWays); i = i + 1) begin
      //let time_i = timestamps[i];
      for (Integer j = 0; j < valueOf(NumWays); j = j + 1) begin
         if ( timestamps[i] > timestamps[j] ) begin
            maskVec[i][j] = 0;
         end
      end
   end
   
   for (Integer k = 0; k < valueOf(NumWays); k = k + 1) begin
      if ( maskVec[k] != 0 ) begin
         retval = k;
      end
   end
   
   return fromInteger(retval);
endfunction
                                                                        

//(*synthesize*)
module mkAssocHashtb#(DRAMControllerIfc dram, Clk_ifc real_clk, ValAlloc_ifc valAlloc)(HashtableIfc);
   //Reg#(Bit#(32)) hvMax <- mkRegU();
   Reg#(Bit#(64)) addrTop <- mkRegU();
   
   FIFO#(Tuple3#(Bit#(8), Bit#(32), Bit#(64))) reqFifo <- mkFIFO();  
   FIFO#(Tuple2#(Bit#(64), Bit#(64))) valAddrFifo <- mkFIFO();
   
   Reg#(State) state <- mkReg(Idle);
   
   Reg#(PhyAddr) rdAddr <- mkRegU();
   Reg#(PhyAddr) wrAddr <- mkRegU();
   Reg#(Bit#(8)) keyLen_rd <- mkRegU();
   Reg#(Bit#(8)) keyLen_wr <- mkRegU();
   Reg#(Bit#(8)) keylen_static <- mkRegU();
   
   Reg#(Bit#(8)) reqCnt_header <- mkReg(0);
   Reg#(Bit#(16)) reqCnt_data <- mkReg(0);
   Reg#(Bit#(16)) respCnt_data <- mkReg(0);
   
   Reg#(Time_t) time_now <- mkRegU();
   
   Reg#(Bit#(8)) procCnt <-mkReg(0);
  
  
   
   FIFO#(Bit#(512)) dataFifo <- mkFIFO();
   
   FIFO#(Bit#(64)) keyTks <- mkFIFO();
   
   //FIFO#(Bit#(HeaderSz)) HeaderBuf <- mkFIFO();
   
   /***** procHeader variables ****/
   Reg#(Vector#(NumWays, ItemHeader)) headerBuf <- mkReg(unpack(0));
   
   Reg#(Bit#(TAdd#(TLog#(HeaderSz),1))) headerCnt <- mkReg(0);
   
   //Reg#(512) lastHeaderToken <- mkRegU();
   
   Reg#(Bit#(NumWays)) cmpMask <- mkReg(0);
   
   Reg#(Bit#(NumWays)) idleMask <- mkReg(0);
   
   
   /**** procData variables ****/
   Reg#(Bit#(512)) dataFifoBuf <- mkReg(0);
   Reg#(Bit#(TAdd#(TLog#(LineWidth),1))) dataFifoPtr <- mkReg(0); 
   Reg#(Bit#(7)) keyBufPtr <- mkReg(0);

   Reg#(Vector#(NumWays,Bit#(64))) tokenBuf <- mkRegU();
  
   
   BRAM_Configure cfg = defaultValue;
   BRAM2Port#(Bit#(5), Bit#(64)) keyBuf <- mkBRAM2Server(cfg);
   Reg#(Bit#(6)) keyBuf_wp <- mkReg(0);
   Reg#(Bit#(6)) keyBuf_rp <- mkReg(0);
   Reg#(Bit#(6)) keyBuf_rc <- mkReg(0);
   
   //FIFO#(Bit#(64)) keyBuf <- mkSizedBRAMFIFO(32);
   
   Reg#(ItemHeader) newHeader <- mkRegU();
   
   Reg#(Bit#(LnSz4Key)) firstKeyLn <- mkRegU();
   Reg#(Bit#(10)) firstKeyCnt <- mkRegU();
   
   Reg#(Bit#(11)) wrHeaderPtr <- mkRegU();
   
   Reg#(Bool) cacheHit <- mkRegU();

   Reg#(Bit#(LineWidth)) lineBuf <- mkRegU();
   Reg#(Bit#(TAdd#(TLog#(LineWidth),1))) linePtr <- mkReg(0); 
   Reg#(Bit#(7)) keyPtr <- mkReg(0);
   FIFO#(Bit#(64)) recvKeyFifo <- mkFIFO();
   
   /*** debugging ***/
   Reg#(Bit#(32)) hv <- mkRegU();
   Reg#(Bit#(64)) reg_nBytes <- mkRegU();
   
   rule recvReq (state == Idle);//(reqCnt == 0);
      
      $display("First Stage: Iniatize parameters");
      let d = reqFifo.first();
      reqFifo.deq();
      
      //let hv_rl = tpl_2(d) % hvMax;
      hv <= tpl_2(d);
      reg_nBytes <= tpl_3(d);
      //rdAddr = (hashval * offset)<<3
      PhyAddr baseAddr = ((unpack(zeroExtend(tpl_2(d))) * fromInteger(valueOf(ItemOffset))) << 6) & addrTop; 
      rdAddr <= baseAddr;
      wrAddr <= baseAddr;
      //dataCnt = (Keylen * 8 + HeaderSz) / LineWidth
      Bit#(16) totalBits = (zeroExtend(tpl_1(d)) << 3) + fromInteger(valueOf(HeaderSz));
      let headerBits = fromInteger(valueOf(HeaderSz));
      //TODO:: Bits have to be redefined
      Bit#(16) totalCnt_;
      Bit#(8) reqCnt_header_;
      
      $display("keyLen = %d, headerSz = %d, totalBits = %d", tpl_1(d)<<3, fromInteger(valueOf(HeaderSz)), totalBits);
      
      if ( (totalBits & fromInteger(valueOf(TSub#(TExp#(LogLnWidth),1)))) == 0/*totalBits[valueOf(TSub#(LogLnWidth,1)):0] == 0*/) begin
         totalCnt_ = totalBits >> fromInteger(valueOf(LogLnWidth)); 
      end
      else begin
         totalCnt_ = (totalBits >> fromInteger(valueOf(LogLnWidth))) + 1; 
      end
      
      //if (fromInteger(valueOf(HeaderResidualSz)) == 0) begin
      reqCnt_header_ =  fromInteger(valueOf(HeaderTokens));
      //end
      //else begin
       //  reqCnt_header_ =  fromInteger(valueOf(TAdd#(HeaderTokens,1)));
      //end
      
      reqCnt_header <= reqCnt_header_;
      reqCnt_data <= totalCnt_ - zeroExtend(reqCnt_header_);
      
      $display("reqCnt_header = %d, reqCnt_data = %d, totalCnt = %d", reqCnt_header_, totalCnt_ - zeroExtend(reqCnt_header_), totalCnt_);
      
      keyLen_rd <= tpl_1(d);
      keyLen_wr <= tpl_1(d);
      
      keylen_static <= tpl_1(d);
              
      headerCnt <= fromInteger(valueOf(HeaderSz));
      dataFifoPtr <= fromInteger(valueOf(LnSz4Key));
      keyBufPtr <= 64;//fromInteger(valueOf(LineWidth));//
      
      keyBuf_wp <= 0;
      keyBuf_rp <= fromInteger(valueOf(TSub#(TDiv#(LnSz4Key,64),1)));
      
      keyBuf_rc <= fromInteger(valueOf(TDiv#(LnSz4Key,64)));
      
      firstKeyCnt <= fromInteger(valueOf(LnSz4Key));
      
      wrHeaderPtr <= fromInteger(valueOf(HeaderSz));
      cacheHit <= True;
      
      
      keyPtr <= fromInteger(valueOf(KeyShiftSz));
      linePtr <= fromInteger(valueOf(LineWidth));
      
      time_now <= real_clk.get_time();
      
      state <= ProcHeader;
   endrule
   
   rule driveRd_header (state == ProcHeader && reqCnt_header > 0);//(reqCnt > 0);
      $display("Sending ReadReq for Header, rdAddr = %d", rdAddr);
      dram.readReq(rdAddr,64);
      rdAddr <= rdAddr + 64;
      reqCnt_header <= reqCnt_header - 1;
   endrule
   
   rule recvRd if (state != Idle);// if (recCnt > 0);
      let data <- dram.read;
      //recCnt <= recCnt - 1;
      $display("dataLine = %h", data);       
      dataFifo.enq(data);
   endrule
   
   rule procHeader ( state == ProcHeader);//&& reqCnt_header == 0);
      $display("Second Stage: Read and Process Header, newData = %h", dataFifo.first);
      let prevData = headerBuf;
      Vector#(NumWays, Bit#(LineWidth)) newData = unpack(dataFifo.first);
      Vector#(NumWays, ItemHeader) nextData = newVector();
      
      Vector#(NumWays, Bit#(LineWidth)) dataFifo_temp = newVector();
           
      Bit#(32) shiftSz = fromInteger(valueOf(LineWidth));
      
      Bit#(NumWays) cmpMask_temp = 0;
      Bit#(NumWays) idleMask_temp = 0;
      
      if ( headerCnt <= fromInteger(valueOf(LineWidth)) ) begin
         shiftSz = fromInteger(valueOf(HeaderResidualSz));//headerCnt;
      end
      
      Bool lastToken = (headerCnt <= fromInteger(valueOf(LineWidth)));
      
      // shift data in to headerBuf;
      for (Integer i = 0; i < valueOf(NumWays); i = i+1) begin
         
         if ( lastToken ) begin
            nextData[i] = unpack((pack(prevData[i]) << shiftSz) | zeroExtend(newData[i]>>valueOf(LnSz4Key)));//[valueOf(TSub#(LineWidth,1)):valueOf(TSub#(LineWidth,HeaderResidualSz))]));
            dataFifo_temp[i] = newData[i] << valueOf(HeaderResidualSz);
         end
         else begin
            nextData[i] = unpack((pack(prevData[i]) << shiftSz) | zeroExtend(newData[i]));
         end
         
         // if it is the last token of the header buffer;
         if ( lastToken ) begin
            
            if ( nextData[i].idle != 0 ) begin
               idleMask_temp[i] = 1;
            end
            else if ( nextData[i].keylen == keyLen_rd ) begin
               cmpMask_temp[i] = 1;
            end
         end
      end
      
      if ( lastToken ) begin
         
         $display("HeaderBuf = %h, prevData = %h", nextData, prevData);
         
         headerCnt <= 0;
         cmpMask <= cmpMask_temp;
         idleMask <= idleMask_temp;
         
         dataFifoBuf <= pack(dataFifo_temp);
         
         $display("cmpMask = %b, idleMask = %b", cmpMask_temp, idleMask_temp);
         if (cmpMask_temp == 0) begin
            state <= ProcData;//PrepWrite; //TODO:: State should be directed to write table
         end
         else begin
            state <= ProcData;
         end
      end
      else begin
         headerCnt <= headerCnt - fromInteger(valueOf(LineWidth));
      end
      dataFifo.deq();
      headerBuf <= nextData;
   endrule
   
   rule driveRd_data (state == ProcData && reqCnt_data > 0);//(reqCnt > 0);
      $display("Sending ReadReq for Data, rdAddr = %d", rdAddr);
      dram.readReq(rdAddr,64);
      rdAddr <= rdAddr + 64;
      reqCnt_data <= reqCnt_data - 1;
   endrule
   
   rule procData (state == ProcData );// if ( headerCnt == 0 ); //TODO:: Fire condition has to be added
      $display("Third Stage: ProcData");
      //if ( keyLen > 0 ) begin
      Vector#(NumWays, Bit#(LineWidth)) data = unpack(dataFifoBuf);
      Vector#(NumWays, Bit#(LineWidth)) nextData = newVector();
      
      Vector#(NumWays, Bit#(64)) nextTokenBuf = newVector();
      
      Bit#(NumWays) cmpMask_temp = cmpMask;
      $display("keyBufPtr = %d, dataFifoPtr = %d", keyBufPtr, dataFifoPtr);
      $display("dataFifoBuf = %h", dataFifoBuf);
      let newKeytokens = keyTks.first();
      if (zeroExtend(keyBufPtr) > dataFifoPtr) begin
         /* draining dataFifoBuf */
         for (Integer i = 0; i < valueOf(NumWays); i = i+1) begin
            //nextTokenBuf[i] = (tokenBuf[i] << valueOf(DtaShiftSz)) | zeroExtend(pack(data[i])[valueOf(TSub#(LineWidth,1)): valueOf(TSub#(LineWidth,DtaShiftSz))]);
            nextTokenBuf[i] = (tokenBuf[i] << valueOf(DtaShiftSz)) | zeroExtend(data[i] >> valueOf(TSub#(LineWidth,DtaShiftSz)));//[valueOf(TSub#(LineWidth,1)): valueOf(TSub#(LineWidth,DtaShiftSz))]);
         end
         keyBufPtr <= keyBufPtr - truncate(dataFifoPtr);
         
         
         dataFifoPtr <= fromInteger(valueOf(LineWidth));
         
         if ({keyLen_rd,3'b0} >= extend(dataFifoPtr)) begin
            dataFifoBuf <= dataFifo.first();
            dataFifo.deq();
         end
         else begin
            dataFifoBuf <= 0;
         end
         
         tokenBuf <= nextTokenBuf;
      end
      else begin// if (keyBufPtr <= dataFifoPtr) begin
         /* draining keyTokenBuff */
         
         for (Integer i = 0; i < valueOf(NumWays); i = i+1) begin
            if ( keyBufPtr == 64 ) begin
               nextTokenBuf[i] = (tokenBuf[i] << 64) | zeroExtend(data[i] >> valueOf(TSub#(LineWidth, 64)));//[valueOf(TSub#(LineWidth,1)): valueOf(TSub#(LineWidth, 64))]);
               nextData[i] = data[i] << 64;
            end
            else begin
               nextTokenBuf[i] = (tokenBuf[i] << valueOf(KeyShiftSz)) | zeroExtend(data[i] >> valueOf(TSub#(LineWidth,KeyShiftSz)));//[valueOf(TSub#(LineWidth,1)): valueOf(TSub#(LineWidth, KeyShiftSz))]);   
               nextData[i] = data[i] << valueOf(KeyShiftSz);
            end
         end
         
         $display("ProcData: tokens = %h << %d", tokenBuf, valueOf(KeyShiftSz));
         $display("ProcData: data = %h", dataFifoBuf);
         $display("ProcData: nexttokens = %h",nextTokenBuf);
         
         for (Integer i = 0; i < valueOf(NumWays); i = i+1) begin
            if (cmpMask[i] == 1 && nextTokenBuf[i] != newKeytokens) begin 
               cmpMask_temp[i] = 0;
            end
         end
         
         $display("After Data Cmp, cmpMask = %b", cmpMask_temp);
         cmpMask <= cmpMask_temp;
         
         if (keyLen_rd > 8) begin
            keyLen_rd <= keyLen_rd - 8;
         end
         else begin
            keyLen_rd <= 0;
            state <= PrepWrite_0;
            //dataFifo.deq(); // remaining input has to be flushed
         end
         keyBufPtr <= 64;
         dataFifoPtr <= dataFifoPtr - zeroExtend(keyBufPtr);
         dataFifoBuf <= pack(nextData);
         
         keyBuf.portA.request.put(BRAMRequest{write: True,
                                              responseOnWrite: False,
                                              address: truncate(keyBuf_wp),
                                              datain: newKeytokens});
         keyBuf_wp <= keyBuf_wp + 1;
         
         if (firstKeyCnt >= 64) begin
            firstKeyLn <= firstKeyLn << 64 | truncate(newKeytokens);
            firstKeyCnt <= firstKeyCnt - 64;
         end
         else if ( firstKeyCnt > 0) begin
            $display("keyToken = %h",newKeytokens);
            firstKeyLn <= (firstKeyLn << valueOf(DtaShiftSz)) | truncate(newKeytokens>>valueOf(KeyShiftSz));//[63:valueOf(TSub#(64,DtaShiftSz))]);
            firstKeyCnt <= 0;
         end
         
         keyTks.deq();
      end

   endrule
   
   rule prepWrite_0 (state == PrepWrite_0);
      $display("Fourth Stage: PrepWrite");      
      Bit#(TLog#(NumWays)) ind;
      let old_header = headerBuf;
      
      //let time_now = real_clk.get_time();
      
      
      if ( cmpMask != 0 ) begin
         // update the timestamp in the header;
         let old_header = headerBuf;
         ind = mask2ind(cmpMask);
         
         old_header[ind].refcount = old_header[ind].refcount + 1;
         old_header[ind].currtime = time_now;
         
         state <= WriteHeader;
         
         valAddrFifo.enq(tuple2(old_header[ind].valAddr, old_header[ind].nBytes));
         newHeader <= old_header[ind];
            
      end
      else begin
         Bool trade_in = False;
         if ( idleMask != 0 ) begin
            ind = mask2ind(idleMask);
            $display("Foruth Stage: idleMask = %b, ind = %d", idleMask, ind);
 //           trade_in = False;
         end
         else begin
            // choose the smallest time stamp, and update the header and the key;
            Vector#(NumWays, Time_t) timestamps;
            for (Integer i = 0; i < valueOf(NumWays); i = i + 1) begin
               timestamps[i] = headerBuf[i].currtime;
            end
            ind = findLRU(timestamps);
            trade_in = True;
         end
         
         valAlloc.newAddrReq(reg_nBytes, old_header[ind].valAddr, trade_in);
         /* more interesting stuff to do here */
         // update a new header if no hit
         
         cacheHit <= False;
         state <= PrepWrite_1;
      end
      wrAddr <= wrAddr + (zeroExtend(ind) << valueOf(LgLineBytes));
      
   endrule
   
   rule prepWrite_1 (state == PrepWrite_1);
      //$display("%h",old_header[ind]);
      let newValAddr <- valAlloc.newAddrResp();
      newHeader <=  ItemHeader{idle: 0,
                               keylen : keylen_static, // key length
                               clsid : 0 , // slab class id
                               valAddr : newValAddr,//zeroExtend(hv), 
                               refcount : 0,
                               exptime : 0, // expiration time
                               currtime : time_now,// last accessed time
                               nBytes : reg_nBytes //
                               };
      //header_Buf <= old_header;
      valAddrFifo.enq(tuple2(newValAddr, reg_nBytes));
      //newHeader <= old_header[ind];
      //wrAddr <= wrAddr + (zeroExtend(ind) << valueOf(LgLineBytes));
      
      
      state <= WriteHeader;
   endrule
   
   rule writeHeader (state == WriteHeader);
      $display("Fifth Stage: WriteHeader");
      $display("newHeader = %h", newHeader);
      Bit#(LineWidth) wrVal = ?;
      Bit#(7) numOfBytes = fromInteger(valueOf(LineBytes));
            
      if ( wrHeaderPtr > fromInteger(valueOf(LineWidth)) )  begin 
         wrVal =  pack(newHeader)[valueOf(TSub#(HeaderSz,1)): valueOf(TSub#(HeaderSz,LineWidth))];
         //numOfBytes = fromInteger(valueOf(LineBytes));
         //wrAddr <= wrAddr + 64'h8;
         wrHeaderPtr <= wrHeaderPtr - fromInteger(valueOf(LineWidth));
      end
      else begin
         //wrVal = pack(newHeader)[valueOf(TSub#(HeaderSz,1)): valueOf(TSub#(HeaderSz,HeaderResidualSz))];
         wrVal = {pack(newHeader)[valueOf(TSub#(HeaderSz,1)): valueOf(TSub#(HeaderSz,HeaderResidualSz))],firstKeyLn};
         //numOfBytes = fromInteger(valueOf(HeaderResidualBytes));
         //wrAddr <= wrAddr + fromInteger(valueOf(HeaderResiduleBytes));
         wrHeaderPtr <= 0;
         if (cacheHit) begin
            $display("Go to Idle");
            state <= Idle;
         end
         else begin
            $display("Go to WriteKeys, keyBuf_rp = %d, keyBuf_wp = %d", keyBuf_rp, keyBuf_wp);
            state <= WriteKeys;
         end
      end
      newHeader <= unpack(pack(newHeader) << valueOf(LineWidth));
      wrAddr <= wrAddr + 64;
      $display("wrAddr = %d, wrVal = %h, bytes = %d", wrAddr, wrVal, numOfBytes);
      dram.write(wrAddr,zeroExtend(wrVal), numOfBytes);
   endrule
   
   rule driveRdKeys (state == WriteKeys && keyBuf_rp < keyBuf_wp);
      $display("Read Key from BRAM: keyBuf_rp = %d, keyBuf_wp = %d", keyBuf_rp, keyBuf_wp);
      keyBuf.portB.request.put(BRAMRequest{write: False,
                                           responseOnWrite: False,
                                           address: truncate(keyBuf_rp),
                                           datain: 0});
      keyBuf_rp <= keyBuf_rp + 1;
   endrule
   
   
   rule recvKeys;
      let keyTk <- keyBuf.portB.response.get;
      recvKeyFifo.enq(keyTk);
   endrule
 
   rule writeKeys (state == WriteKeys);
      $display("Last Stage: WriteKeys");
      //let keyTk <- keyBuf.portB.response.get;
      let keyTk = recvKeyFifo.first;
      
      let tempLine = lineBuf;
      
      if (keyPtr > linePtr) begin
         /* draining lineBuf */
         let wrData = (tempLine << valueOf(DtaShiftSz)) | (keyTk >> valueOf(KeyShiftSz));//zeroExtend(keyTk[64:valueOf(TSub#(64,DtaShiftSz))]);
         //let wrData = {tempLine[valueOf(TSub#(TSub#(LineWidth,DtaShiftSz),1)):0], keyTk[63:valueOf(TSub#(64,DtaShiftSz))]};
         dram.write(wrAddr, zeroExtend(wrData), fromInteger(valueOf(LineBytes)));
         //dram.write(wrAddr, zeroExtend({tempLine[valueOf(TSub#(TSub#(LineWidth,DtaShiftSz),1)):0], keyTk[63:valueOf(TSub#(64,DtaShiftSz))]}), fromInteger(valueOf(LineBytes)));
         if ( keyLen_wr <= zeroExtend(linePtr>>3)) begin
            state <= Idle;
            recvKeyFifo.deq();
         end
            
         wrAddr <= wrAddr + 64;
         keyPtr <= keyPtr - linePtr;
         linePtr <= fromInteger(valueOf(LineWidth));
      end
      else begin// if (keyPtr <= linePtr) begin
         /* draining keyBuf */
         
         if (keyPtr == 64) begin
            tempLine = tempLine << 64 | keyTk;//{tempLine[valueOf(TSub#(LineWidth,65)): 0], keyTk};
            //tempLine = {tempLine[valueOf(TSub#(LineWidth,65)): 0], keyTk};
         end
         else begin
            tempLine = (tempLine << valueOf(KeyShiftSz)) | (keyTk & fromInteger(valueOf(TSub#(TExp#(KeyShiftSz),1))) );//zeroExtend(keyTk[valueOf(TSub#(KeyShiftSz,1)):0]);//{tempLine[31:0], keyTk[31:0]};
    //        tempLine = {tempLine[valueOf(TSub#(TSub#(LineWidth,KeyShiftSz),1)):0], keyTk[valueOf(TSub#(KeyShiftSz,1)):0]};
         end
         
         keyPtr <= 64;
         linePtr <= linePtr - keyPtr;
         recvKeyFifo.deq();
         lineBuf <= tempLine;
         
         $display("keyBuf_rc = %d, keyBuf_wp = %d", keyBuf_rc, keyBuf_wp);        
         //if ( keyBuf_rc < keyBuf_wp) begin
         //   keyBuf_rc <= keyBuf_rc + 1;
         if ( keyLen_wr > 8 ) begin
            keyLen_wr <= keyLen_wr - 8;
         end
         else begin
            $display("Last Stage: go back to Idle");
            $display("wrAddr = %d, wrVal = %h, bytes = %d", wrAddr, tempLine << (linePtr-keyPtr), fromInteger(valueOf(LineBytes)));
            dram.write(wrAddr,zeroExtend(tempLine << (linePtr-keyPtr)), fromInteger(valueOf(LineBytes)));//(fromInteger(valueOf(LineWidth)) - linePtr + keyPtr)>>3);
            keyLen_wr <= 0;
            state <= Idle;
         end
      end
      
   endrule
   
      
   method Action readTable(Bit#(8) keylen, Bit#(32) hv, Bit#(64) nBytes);
      $display("Hashtable Request Received");
      reqFifo.enq(tuple3(keylen, hv, nBytes));
   endmethod
   
   method Action keyTokens(Bit#(64) keys);
      $display("Hashtable keytoken received");
      Vector#(8, Bit#(8)) byteVec = unpack(keys);
      keyTks.enq(pack(reverse(byteVec)));
   endmethod
   
   method ActionValue#(Tuple2#(Bit#(64), Bit#(64))) getValAddr();
      valAddrFifo.deq;
      return valAddrFifo.first;
   endmethod

   interface HashtableInitIfc init;
      method Action initTable(Bit#(64) lgOffset) if (state == Idle);
         //hvMax <= unpack((1 << lgOffset) - 1) / fromInteger(valueOf(ItemOffset));
         addrTop <= (1 << lgOffset) - 1;
      endmethod
   endinterface
endmodule

endpackage: Hashtable

