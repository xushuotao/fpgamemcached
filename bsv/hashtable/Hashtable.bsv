package Hashtable;

import FIFO::*;
import Vector::*;

import DRAMController::*;

import DDR3::*;

import Time::*;

import BRAM::*;

import Valuestr::*;

import BRAMFIFO::*;

import Packet::*;
//`define DEBUG

typedef struct{
   Bit#(8) idle;
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
   
typedef 128 LineWidth; // LineWidth 64/128/256/512

typedef TDiv#(LineWidth, 8) LineBytes;

typedef TLog#(LineBytes) LgLineBytes;

typedef TDiv#(HeaderSz, LineWidth) HeaderTokens;

typedef TSub#(HeaderSz,TMul#(LineWidth,TSub#(TDiv#(HeaderSz, LineWidth),1))) HeaderRemainderSz;

typedef TDiv#(HeaderRemainderSz, 8) HeaderRemainderBytes;

typedef TLog#(LineWidth) LogLnWidth;

typedef TDiv#(512, LineWidth) NumWays;

typedef TMul#(256,8) MaxKeyLen;

typedef TAdd#(HeaderSz,MaxKeyLen) MaxItemSize;

typedef TDiv#(MaxItemSize, LineWidth) ItemOffset;

typedef TSub#(LineWidth, HeaderRemainderSz) HeaderResidualSz;
typedef TDiv#(HeaderResidualSz,8) HeaderResidualBytes;

`ifndef HEADER_64_ALIGNED
typedef TSub#(HeaderResidualSz, TMul#(64,TSub#(TDiv#(HeaderResidualSz,64),1))) DtaShiftSz;
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
   
   Reg#(PhyAddr) rdAddr_hdr <- mkRegU();
   Reg#(PhyAddr) wrAddr <- mkRegU();
   Reg#(PhyAddr) rdAddr_key <- mkRegU();
//   Reg#(PhyAddr) wrAddr <- mkRegU();

   Reg#(Bit#(8)) keyLen_rd <- mkRegU();
   Reg#(Bit#(8)) keyLen_wr <- mkRegU();
   Reg#(Bit#(8)) keylen_static <- mkRegU();
   
   Reg#(Bit#(8)) reqCnt_hdr <- mkReg(0);
   Reg#(Bit#(8)) respCnt_hdr <- mkReg(0);
   Reg#(Bit#(8)) reqCnt_key <- mkReg(0);
   Reg#(Bit#(8)) respCnt_key <- mkReg(0);
   
   
   Reg#(Bool) header_cmd <- mkRegU();
   Reg#(Bool) key_cmd <- mkRegU();
   
   //Reg#(Bool) wr_header_cmd <- mkRegU();
   Reg#(Bool) wr_key_cmd <- mkRegU();
   Reg#(Bit#(8)) reqCnt_hdr_wr <- mkRegU();
   Reg#(Bit#(8)) respCnt_hdr_wr <- mkRegU();


   Reg#(Bit#(8)) numBufs <- mkRegU();
   Reg#(Bit#(8)) numKeytokens <- mkRegU();
   Reg#(Bit#(8)) numKeys <- mkRegU();
   Reg#(Bit#(8)) reqCnt_key_wr <- mkRegU();
   
   Reg#(Bool) first_key_wr <- mkRegU();
   Reg#(Bit#(8)) respCnt_key_wr <- mkRegU();

   
   
   Reg#(Time_t) time_now <- mkRegU();
   
  
   FIFO#(Bit#(512)) dataFifo <- mkFIFO();
   
   FIFO#(Bit#(64)) keyTks <- mkFIFO();
   
   //FIFO#(Bit#(HeaderSz)) HeaderBuf <- mkFIFO();
   
   /***** procHeader variables ****/
   Reg#(Vector#(NumWays, ItemHeader)) headerBuf <- mkReg(unpack(0));
   
   Reg#(Bit#(NumWays)) cmpMask <- mkReg(0);
   
   Reg#(Bit#(NumWays)) idleMask <- mkReg(0);
   
   
   /**** procData variables ****/
   FIFO#(Bit#(64)) keyBuf <- mkSizedBRAMFIFO(32);
   
   /**** procWrite_header variables ****/
   Reg#(ItemHeader) newHeader <- mkRegU();
   
   Reg#(Bit#(HeaderResidualSz)) firstKeyLn <- mkRegU();
   Reg#(Bit#(10)) firstKeyCnt <- mkRegU();
   
   Reg#(Bit#(11)) wrHeaderPtr <- mkRegU();
   
   Reg#(Bool) cacheHit <- mkRegU();

   Reg#(Bit#(LineWidth)) lineBuf <- mkRegU();
   Reg#(Bit#(TAdd#(TLog#(LineWidth),1))) linePtr <- mkReg(0); 
   Reg#(Bit#(7)) keyPtr <- mkReg(0);
   //FIFO#(Bit#(64)) recvKeyFifo <- mkFIFO();
   
   /*** debugging ***/
   Reg#(Bit#(32)) hv <- mkRegU();
   Reg#(Bit#(64)) reg_nBytes <- mkRegU();
   
   
   rule recvReq (state == Idle);
      
      $display("First Stage: Iniatize parameters");
      let d = reqFifo.first();
      reqFifo.deq();
      
      //let hv_rl = tpl_2(d) % hvMax;
      hv <= tpl_2(d);
      reg_nBytes <= tpl_3(d);
      //rdAddr = (hashval * offset)<<3
      PhyAddr baseAddr = ((unpack(zeroExtend(tpl_2(d))) * fromInteger(valueOf(ItemOffset))) << 6) & addrTop; 
      rdAddr_hdr <= baseAddr;
      wrAddr <= baseAddr;
      //dataCnt = (Keylen * 8 + HeaderSz) / LineWidth
      Bit#(16) totalBits = (zeroExtend(tpl_1(d)) << 3) + fromInteger(valueOf(HeaderSz));
      let headerBits = fromInteger(valueOf(HeaderSz));
      //TODO:: Bits have to be redefined
      Bit#(16) totalCnt_;
      Bit#(8) reqCnt_hdr_;
      
      $display("keyLen_bits = %d, headerSz = %d, totalBits = %d", tpl_1(d)<<3, fromInteger(valueOf(HeaderSz)), totalBits);
      
      if ( (totalBits & fromInteger(valueOf(TSub#(LineWidth,1)))) == 0) begin
         totalCnt_ = totalBits >> fromInteger(valueOf(LogLnWidth)); 
      end
      else begin
         totalCnt_ = (totalBits >> fromInteger(valueOf(LogLnWidth))) + 1; 
      end
      
      reqCnt_hdr_ =  fromInteger(valueOf(HeaderTokens));
      
      reqCnt_hdr <= reqCnt_hdr_;
      respCnt_hdr <= reqCnt_hdr_;
      
      reqCnt_hdr_wr <= 1;
      respCnt_hdr_wr <= reqCnt_hdr_;
      
      Bit#(8) reqCnt_key_;
      if ( valueOf(HeaderSz)%valueOf(LineWidth) == 0) begin
         reqCnt_key_ = truncate(totalCnt_ - zeroExtend(reqCnt_hdr_));
      end
      else begin
         reqCnt_key_ = truncate(totalCnt_ - zeroExtend(reqCnt_hdr_)) + 1;
      end
      
      reqCnt_key <= reqCnt_key_;
      numBufs <= reqCnt_key_;
      
      $display("reqCnt_hdr = %d, reqCnt_key = %d, totalCnt = %d", reqCnt_hdr_, totalCnt_ - zeroExtend(reqCnt_hdr_), totalCnt_);
      
      keyLen_rd <= tpl_1(d);
      keyLen_wr <= tpl_1(d);
  
      Bit#(8) keylen = tpl_1(d);    
      
      Bit#(8) numKeytokens_;
      if ( (keylen & 7) == 0 ) begin
         numKeytokens_ = tpl_1(d) >> 3;
      end
      else begin
         numKeytokens_ = (tpl_1(d) >> 3) + 1;
      end
      respCnt_key <= reqCnt_key_;
      
      numKeytokens <= numKeytokens_;
      reqCnt_key_wr <= numKeytokens_;
      respCnt_key_wr <= reqCnt_key_;
      numKeys <= numKeytokens_;
      
      first_key_wr <= True;
      keylen_static <= tpl_1(d);
              
      cacheHit <= True;
      
      
      time_now <= real_clk.get_time();
      
      state <= ProcHeader;
      header_cmd <= True;
      key_cmd <= True;
      //wr_header_cmd <= True;
      wr_key_cmd <= True;
   endrule
   
   rule driveRd_header (state == ProcHeader && reqCnt_hdr > 0);//(reqCnt > 0);
      $display("Sending ReadReq for Header, rdAddr_hdr = %d", rdAddr_hdr);
      dram.readReq(rdAddr_hdr,64);
      rdAddr_hdr <= rdAddr_hdr + 64;
      reqCnt_hdr <= reqCnt_hdr - 1;
   endrule
   
   rule recvRd if (state != Idle);// if (recCnt > 0);
      let data <- dram.read;
      //recCnt <= recCnt - 1;
      $display("dataLine = %h", data);       
      dataFifo.enq(data);
   endrule
   
   
   Vector#(NumWays, DepacketIfc#(128, HeaderSz, 0)) depacketEngs_hdr <- replicateM(mkDepacketEngine());
   
   rule procHeader (state == ProcHeader && header_cmd);
      for (Integer i = 0; i < valueOf(NumWays); i=i+1) begin
         depacketEngs_hdr[i].start(1, fromInteger(valueOf(HeaderTokens)));
      end
      header_cmd <= False;
   endrule
   
   rule procHeader_2 (state == ProcHeader && respCnt_hdr > 0);
      let v <- toGet(dataFifo).get();
      Vector#(NumWays, Bit#(LineWidth)) vector_v = unpack(v);
      for (Integer i = 0; i < valueOf(NumWays); i=i+1) begin
         depacketEngs_hdr[i].inPipe.put(vector_v[i]);
      end
      respCnt_hdr <= respCnt_hdr - 1;
   endrule
   
   rule procHeader_3 (state == ProcHeader);
      Vector#(NumWays, ItemHeader) headers;
      Bit#(NumWays) cmpMask_temp = 0;
      Bit#(NumWays) idleMask_temp = 0;
      
      for (Integer i = 0; i < valueOf(NumWays); i=i+1) begin
         let v_ <- depacketEngs_hdr[i].outPipe.get;
         ItemHeader v = unpack(v_);
         headers[i] = v;
         if (v.idle != 0 ) begin
            idleMask_temp[i] = 1;
         end
         else if (v.keylen == keyLen_rd ) begin
            cmpMask_temp[i] = 1;
         end
      end
      
      cmpMask <= cmpMask_temp;
      idleMask <= idleMask_temp;
      headerBuf <= headers;      
      
      $display("cmpMask = %b, idleMask = %b", cmpMask_temp, idleMask_temp);
      if (cmpMask_temp == 0) begin
         state <= ProcData;//PrepWrite; //TODO:: State should be directed to write table
      end
      else begin
         state <= ProcData;
      end
      
      if ( valueOf(HeaderSz)%valueOf(LineWidth) == 0) begin
         rdAddr_key <= rdAddr_hdr;
      end
      else begin
         rdAddr_key <= rdAddr_hdr - 64;
      end
      
      
   endrule
   
   rule driveRd_data (state == ProcData && reqCnt_key > 0);//(reqCnt > 0);
      $display("Sending ReadReq for Data, rdAddr_key = %d", rdAddr_key);
      dram.readReq(rdAddr_key,64);
      rdAddr_key <= rdAddr_key + 64;
      reqCnt_key <= reqCnt_key - 1;
   endrule
   
   Vector#(NumWays, PacketIfc#(64, LineWidth, HeaderRemainderSz)) packetEngs_key <- replicateM(mkPacketEngine());
 
   rule procData (state == ProcData && key_cmd);
      for (Integer i = 0; i < valueOf(NumWays); i=i+1) begin
         packetEngs_key[i].start(extend(numBufs), extend(numKeytokens));
      end
      key_cmd <= False;
   endrule
   
   rule procData_2 (state == ProcData && respCnt_key > 0);
      let v <- toGet(dataFifo).get();
      $display("put data in to packetEngs");
      Vector#(NumWays, Bit#(LineWidth)) vector_v = unpack(v);
      for (Integer i = 0; i < valueOf(NumWays); i=i+1) begin
         packetEngs_key[i].inPipe.put(vector_v[i]);
      end
      respCnt_key <= respCnt_key - 1;
   endrule
   
   rule procData_3 (state == ProcData);
      Bit#(NumWays) cmpMask_temp = cmpMask;
      if (numKeys > 0) begin
         let keyToken <- toGet(keyTks).get();
         $display("Comparing keys, keytoken == %h", keyToken);
         keyBuf.enq(keyToken);
     
         for (Integer i = 0; i < valueOf(NumWays); i=i+1) begin
            let key <- packetEngs_key[i].outPipe.get();
            if ( cmpMask[i] == 1 && key != keyToken ) begin
               cmpMask_temp[i] = 0;
            end
         end
      end
      else begin
         state <= PrepWrite_0;
      end
      numKeys <= numKeys - 1;
      cmpMask <= cmpMask_temp;
   endrule
      
   PacketIfc#(LineWidth, HeaderSz, 0) packetEng_hdr <- mkPacketEngine(); 
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
         packetEng_hdr.start(1, fromInteger(valueOf(HeaderTokens)));
      end
      else begin
         Bool trade_in = False;
         if ( idleMask != 0 ) begin
            ind = mask2ind(idleMask);
            $display("Foruth Stage: idleMask = %b, ind = %d", idleMask, ind);
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
      valAddrFifo.enq(tuple2(newValAddr, reg_nBytes));
      
      state <= WriteHeader;
      packetEng_hdr.start(1, fromInteger(valueOf(HeaderTokens)));
   endrule


   
   rule writeHeader_1 (state == WriteHeader && reqCnt_hdr_wr > 0);
      packetEng_hdr.inPipe.put(pack(newHeader));
      reqCnt_hdr_wr <= reqCnt_hdr_wr - 1;
   endrule
   
   rule writeHeader_2 (state == WriteHeader);
      let wrVal <- packetEng_hdr.outPipe.get();
      Bit#(7) numOfBytes = fromInteger(valueOf(LineBytes));
      
      if (respCnt_hdr_wr > 1) begin
         wrAddr <= wrAddr + 64;
      end
      else begin
         numOfBytes = fromInteger(valueOf(HeaderRemainderBytes));
         if (cacheHit) begin
            $display("Go to Idle");
            state <= Idle;
            keyBuf.clear();
         end
         else begin
            state <= WriteKeys;
         end
      end
         
      respCnt_hdr_wr <= respCnt_hdr_wr - 1;
      $display("wrAddr = %d, wrVal = %h, bytes = %d", wrAddr, wrVal, numOfBytes);
      dram.write(wrAddr,zeroExtend(wrVal), numOfBytes);
   endrule

   DepacketIfc#(64, LineWidth, HeaderRemainderSz) depacketEng_key <- mkDepacketEngine();
   
   rule writeKeys_0 (state == WriteKeys && wr_key_cmd);
      wr_key_cmd <= False;
      depacketEng_key.start(extend(numBufs), extend(numKeytokens));
   endrule
   
   rule writeKeys_1 (state == WriteKeys && reqCnt_key_wr > 0);
      $display("put keytokens in to depacket inpipe");
      let v <- toGet(keyBuf).get();
      depacketEng_key.inPipe.put(v);
      reqCnt_key_wr <= reqCnt_key_wr - 1;
   endrule
 
   rule writeKeys_2 (state == WriteKeys);
      if (respCnt_key_wr > 0) begin
         let v <- depacketEng_key.outPipe.get();
         if (first_key_wr) begin
            $display("wrAddr = %d, wrVal = %h, bytes = %d", wrAddr + fromInteger(valueOf(HeaderRemainderBytes)), v, fromInteger(valueOf(HeaderResidualBytes)));
            dram.write(wrAddr + fromInteger(valueOf(HeaderRemainderBytes)), zeroExtend(v)>>fromInteger(valueOf(HeaderRemainderSz)), fromInteger(valueOf(HeaderResidualBytes)));
            first_key_wr <= False;
         end
         else begin
            $display("wrAddr = %d, wrVal = %h, bytes = %d", wrAddr, v, fromInteger(valueOf(LineBytes)));
            dram.write(wrAddr, zeroExtend(v), fromInteger(valueOf(LineBytes)));
         end
      end
      else begin
         $display("Going back to Idle");
         state <= Idle;
      end
      wrAddr <= wrAddr + 64;
      respCnt_key_wr <= respCnt_key_wr  -  1;
   endrule
      
   method Action readTable(Bit#(8) keylen, Bit#(32) hv, Bit#(64) nBytes);
      $display("Hashtable Request Received");
      reqFifo.enq(tuple3(keylen, hv, nBytes));
   endmethod
   
   method Action keyTokens(Bit#(64) keys);
      $display("Hashtable keytoken received");
      //Vector#(8, Bit#(8)) byteVec = unpack(keys);
      //keyTks.enq(pack(reverse(byteVec)));
      keyTks.enq(keys);
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

