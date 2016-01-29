import FIFO::*;
import Vector::*;
import GetPut::*;
import Align::*;

import ProtocolHeader::*;
import DMAHelper::*;

`ifdef Debug
Bool debug = True;
`else
Bool debug = False;
`endif

interface MemReqParser;
   interface Put#(Bit#(32)) request;
   interface Put#(Bit#(128)) inPipe;
   interface Get#(Protocol_Binary_Request_Header) reqHeader;
   interface Get#(Bit#(128)) keyPipe;
   interface Get#(Tuple2#(Bit#(128), Bool)) keyValPipe;
endinterface

typedef TDiv#(ReqHeaderSz, 8) ReqHeaderBytes;

typedef enum{DoHeader, DoKeyValueTokens} State deriving (Bits, Eq);

//(*synthesize*)
module mkMemReqParser(MemReqParser);
   //FIFO#(Bit#(32)) reqMaxQ <- mkFIFO;
   
   FIFO#(Bit#(128)) inFifo <- mkFIFO;
   
   ByteAlignIfc#(Bit#(128), Bit#(0)) keyAlign <- mkByteAlignCombinational;
   ByteAlignIfc#(Bit#(128), Bool) keyValAlign <- mkByteAlignCombinational;
   
   Reg#(State) state <- mkReg(DoHeader);

   //Reg#(Protocol_Binary_Request_Header) headerBuf <- mkRegU();
   Reg#(Bit#(ReqHeaderSz)) headerBuf <- mkRegU();
   FIFO#(Protocol_Binary_Request_Header) reqHeaderQ <- mkFIFO();

   Reg#(Bit#(TAdd#(TLog#(ReqHeaderBytes),1))) byteCnt_hdr <- mkReg(0); 
   
   Reg#(Bit#(32)) byteCnt_kv <- mkReg(0); 
   Reg#(Bit#(4)) offset <- mkReg(0);
   Reg#(Bit#(4)) sftArg <- mkReg(8);
   
   Reg#(Bit#(16)) keylen <- mkReg(0);
   Reg#(Bit#(32)) totallen <- mkReg(0);
   
   Reg#(Bit#(32)) headerCnt <- mkReg(0);
   
   Reg#(Bit#(32)) reqCnt <- mkReg(0);
   rule distHeaderTokens if (state==DoHeader);
      let d <- toGet(inFifo).get();
      if (debug) $display("byteCnt_hdr = %d, %h %h",byteCnt_hdr, d, headerBuf);
      if (byteCnt_hdr >= fromInteger(valueOf(ReqHeaderBytes)-16)) begin
         Protocol_Binary_Request_Header newHdr = unpack(truncateLSB({d, headerBuf} << {sftArg, 3'b0}));
         if (debug) begin
            $display("header[%d] = %h",headerCnt, newHdr);
            $display("magic %h", newHdr.magic);
            $display("opcode %h", newHdr.opcode);
            $display("keylen %h", newHdr.keylen);
            $display("extlen %h", newHdr.extlen);
            $display("datatype %h", newHdr.datatype);
            $display("reserved %h", newHdr.reserved);
            $display("bodylen %h", newHdr.bodylen);
            $display("opaque %h", newHdr.opaque);
            $display("cas %h", newHdr.cas);
            headerCnt <= headerCnt + 1;
         end
         reqHeaderQ.enq(newHdr);
         if ( byteCnt_hdr > fromInteger(valueOf(ReqHeaderBytes)-16) && newHdr.bodylen > 0 ) begin
            keyAlign.inPipe.put(d);
            keyValAlign.inPipe.put(d);
         end
         
         keyAlign.align(8+offset, extend(newHdr.keylen),?);
         if ( newHdr.opcode == PROTOCOL_BINARY_CMD_SET ) begin
            keyValAlign.align(8+offset, newHdr.bodylen, False);
         end
         else begin
            keyValAlign.align(8+offset, newHdr.bodylen, True);
         end
         keylen <= newHdr.keylen;
         totallen <= newHdr.bodylen;
         if ( newHdr.bodylen > extend(~(offset + 8) + 1) ) begin
            state <= DoKeyValueTokens;
            byteCnt_kv <= extend(~(offset + 8) + 1);
         end
         else begin
            if ( newHdr.opcode == PROTOCOL_BINARY_CMD_EOM ) begin
               reqCnt <= 0;
               //reqMaxQ.deq();
               sftArg <= 8;
               offset <= 0;
               byteCnt_hdr <= 0;
            end
            else begin
               //reqCnt <= reqCnt + 1;
               headerBuf <= unpack(truncateLSB({d, headerBuf}));
               sftArg <= sftArg + 8 - truncate(newHdr.bodylen);
               offset <= offset + 8 + truncate(newHdr.bodylen);
               byteCnt_hdr <=  extend((~(offset + 8) + 1) - truncate(newHdr.bodylen));
            end
         end
      end
      else begin
         headerBuf <= truncateLSB({d, headerBuf});
         byteCnt_hdr <= byteCnt_hdr + 16;
      end
   endrule
   

   rule distKeyValueTokens if (state == DoKeyValueTokens);
      let d <- toGet(inFifo).get();
      //if (debug) $display("byteCnt_kv = %d, %h",byteCnt_kv, d);
      if ( byteCnt_kv < extend(keylen)) begin
         keyAlign.inPipe.put(d);
      end
      keyValAlign.inPipe.put(d);
      
      if (byteCnt_kv + 16 >= totallen ) begin
         state <= DoHeader;
         /*if ( reqCnt + 1 == reqMaxQ.first()) begin
            reqCnt <= 0;
            reqMaxQ.deq();
            sftArg <= 8;
            offset <= 0;
            byteCnt_hdr <= 0;
         end
         else begin*/
         reqCnt <= reqCnt + 1;
         sftArg <= truncate(byteCnt_kv + 16 - totallen) - 8;
         offset <= truncate(totallen - byteCnt_kv);
         byteCnt_hdr <= truncate(byteCnt_kv + 16 - totallen);
         if ( byteCnt_kv + 16 > totallen) begin
            headerBuf <= unpack(truncateLSB({d, headerBuf}));
         end
         byteCnt_kv <= 0;
      //end
      end
      else begin
         byteCnt_kv <= byteCnt_kv + 16;
      end
   endrule
  
   function Bit#(8) expand(Bit#(1) v);
      Bit#(8) retval = 0;
      if ( v == 1) 
         retval = -1;
      return retval;
   endfunction
   
   //interface Put request = toPut(reqMaxQ);
   interface Put inPipe = toPut(inFifo);
   interface Get reqHeader = toGet(reqHeaderQ);
   interface Get keyPipe;
      method ActionValue#(Bit#(128)) get();
         let d <- keyAlign.outPipe.get();
         let dta = tpl_1(d);
         let numBytes = tpl_2(d);
         Bit#(16) bytemask = (1 << numBytes)  - 1;

         Vector#(16, Bit#(8)) mask = map(expand, unpack(bytemask));
         return dta & pack(mask);
      endmethod
   endinterface
   
   interface Get keyValPipe;
      method ActionValue#(Tuple2#(Bit#(128),Bool)) get();
         let d <- keyValAlign.outPipe.get();
         //$display("d = %h, nBytes = %d", tpl_1(d), tpl_2(d));
         let dta = tpl_1(d);
         let numBytes = tpl_2(d);
         Bit#(16) bytemask = (1 << numBytes)  - 1;
         //$display("bytemask = %b",bytemask);
         Vector#(16, Bit#(8)) mask = map(expand, unpack(bytemask));
         return tuple2(dta & pack(mask),tpl_3(d));
      endmethod
   endinterface
endmodule
   
