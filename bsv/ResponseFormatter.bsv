import FIFO::*;
import SpecialFIFOs::*;
import GetPut::*;
import Vector::*;

import MemcachedTypes::*;
import ProtocolHeader::*;
import Align::*;
import ParameterTypes::*;


interface ResponseFormatter;
   //interface Put#(Bit#(32)) request;
   interface Put#(Protocol_Binary_Response_Header) hdrPipe;
   interface Put#(Bit#(128)) inPipe;
   interface Get#(Tuple2#(Bit#(128), Bool)) outPipe;
endinterface

typedef enum{DoHeader, DoValueTokens} State deriving (Bits, Eq);

typedef BytesOf#(Protocol_Binary_Response_Header) RespHeaderBytes;

//(*synthesize*)
module mkResponseFormatter(ResponseFormatter);
   /*FIFO#(Bit#(32)) reqQ <- mkFIFO;
   FIFO#(Bit#(32)) reqQ_1 <- mkFIFO;*/
   Reg#(Bit#(1)) sel_req <- mkReg(0);
   FIFO#(Protocol_Binary_Response_Header) reqQ <- mkSizedFIFO(numStages);
   FIFO#(Protocol_Binary_Response_Header) headerQ <- mkFIFO();
   FIFO#(Bit#(32)) bodylenQ_hdr <- mkFIFO;
   FIFO#(Bit#(32)) bodylenQ_val <- mkSizedFIFO(8);
   FIFO#(Bit#(128)) valQ <- mkSizedFIFO(8);
   FIFO#(Tuple2#(Bit#(128),Bool)) outputQ <- mkFIFO;
   
   Reg#(Bit#(4)) offset <- mkReg(0);
   
   Reg#(Bit#(32)) reqCnt <- mkReg(0);
   
   Vector#(2,ByteDeAlignIfc#(Bit#(128), Bool)) deAlign_hdr <- replicateM(mkByteDeAlignCombinational_regular);
   ByteDeAlignIfc#(Bit#(128), Bit#(0)) deAlign_val <- mkByteDeAlignCombinational_regular;
      
   Reg#(Bit#(2)) cnt <- mkReg(0);
   Reg#(Bit#(1)) sel_des <- mkReg(0);
   
   Reg#(Bit#(32)) reqCnt_1 <- mkReg(0);
   rule doReq;
      let v <- toGet(reqQ).get();

      bodylenQ_hdr.enq(v.bodylen);
      if (v.bodylen > 0 ) begin
         bodylenQ_val.enq(v.bodylen);
         deAlign_val.deAlign(offset + 8, v.bodylen, ?);
      end
      
      Bool eom = False;

      if ( v.opcode == PROTOCOL_BINARY_CMD_EOM ) begin
         eom = True;
         offset <= 0;
         reqCnt_1 <= 0;
      end
      else begin
         offset <= truncate(extend(offset) + 8 + v.bodylen);
         reqCnt_1 <= reqCnt_1 + 1;
      end
      $display("Response Formatter:: reqcnt = %d, put hdr = %h, keylen = %d, vallen = %d, eom = %d, opaque = %d, offset = %d", reqCnt_1, v, v.keylen, v.bodylen, eom, v.opaque, offset);      
      deAlign_hdr[sel_req].deAlign(offset, fromInteger(valueOf(RespHeaderBytes)), eom);
      sel_req <= sel_req + 1;
      headerQ.enq(v);
   endrule
   
   rule desHeader;
      let header = headerQ.first();
      Vector#(3, Bit#(64)) dataV = unpack(pack(header));
      if ( cnt == 2 ) begin
         headerQ.deq();
         deAlign_hdr[sel_des].inPipe.put(extend(dataV[2]));
         cnt <= 0;
         sel_des <= sel_des + 1;
      end
      else begin
         deAlign_hdr[sel_des].inPipe.put({dataV[1],dataV[0]});
         cnt <= cnt + 2;
      end
   endrule
   
   Reg#(State) state <- mkReg(DoHeader);
   Reg#(Bit#(TAdd#(TLog#(RespHeaderBytes),1))) byteCnt_hdr <- mkReg(0);
   Reg#(Bit#(32)) byteCnt_val <- mkReg(0);
   Reg#(Bit#(1)) sel <- mkReg(0);
   rule doHeader if (state == DoHeader);
      //let reqMax = reqQ.first();
      let v <- deAlign_hdr[sel].outPipe.get();
      let bodylen = bodylenQ_hdr.first();
      let data = tpl_1(v);
      let nBytes = tpl_2(v);
      let eom = tpl_3(v);
      //$display("%m, reqcnt = %d, byteCnt_hdr = %d, bodylen = %d, data = %h, nBytes = %d", reqCnt, byteCnt_hdr, bodylen, data, nBytes);
      if ( byteCnt_hdr + extend(nBytes) == fromInteger(valueOf(RespHeaderBytes)) ) begin
         bodylenQ_hdr.deq();
         sel <= sel + 1;
         if ( bodylen > 0 ) begin
            // if the response has value
            if ( nBytes < 16 ) begin
               let valD <- deAlign_val.outPipe.get();
               
               if ( bodylen > extend(16 - nBytes) ) begin
                  outputQ.enq(tuple2(data | tpl_1(valD), False));
                  state <= DoValueTokens;
                  byteCnt_val <= extend(tpl_2(valD));
               end
               else begin
                  bodylenQ_val.deq();
                  /*if ( eom //reqCnt + 1 == reqMax/ ) begin
                     $display("%m:: doHdrwithval:: Request finishes, enquening last request hdr");
                     //reqQ.deq();
                     reqCnt <= 0;
                     byteCnt_hdr <= 0;
                     byteCnt_val <= 0;
                     outputQ.enq(tuple2(data | tpl_1(valD), True));
                  end
                  else begin*/
                  reqCnt <= reqCnt + 1;
                  if ( bodylen < extend(16 - nBytes)) begin
                     let hdrV <- deAlign_hdr[sel+1].outPipe.get();
                     $display("data = %h, hdrV = %h, hdrV_nBYtes=%d", data, tpl_1(hdrV), tpl_2(hdrV));
                     outputQ.enq(tuple2(data | tpl_1(valD) | tpl_1(hdrV), False));
                     byteCnt_hdr <= extend(tpl_2(hdrV));
                  end
                  else begin
                     outputQ.enq(tuple2(data | tpl_1(valD), False));
                     byteCnt_hdr <= 0;
                  end
                  //end
               end
            end
            else begin
               state <= DoValueTokens;
               outputQ.enq(tuple2(data,False));
               byteCnt_val <= 0;
            end
         end
         else begin
            // if the response has no value
            if ( eom/*reqCnt + 1 == reqMax*/ ) begin
               $display("%m:: doHdr:: Request finishes, enquening last request hdr");
               //reqQ.deq();
               reqCnt <= 0;
               byteCnt_hdr <= 0;
               byteCnt_val <= 0;
               outputQ.enq(tuple2(data,True));
            end
            else begin
               reqCnt <= reqCnt +1;
               if ( nBytes < 16 ) begin
                  let hdrV <- deAlign_hdr[sel+1].outPipe.get();
                  //$display("data = %h, hdrV = %h, hdrV_nBYtes=%d", data, tpl_1(hdrV), tpl_2(hdrV));
                  outputQ.enq(tuple2(data | tpl_1(hdrV), False));
                  byteCnt_hdr <= extend(tpl_2(hdrV));
               end
               else begin
                  outputQ.enq(tuple2(data,False));
                  byteCnt_hdr <= 0;
               end
            end
         end
      end
      else begin
         outputQ.enq(tuple2(data, False));
         byteCnt_hdr <= byteCnt_hdr + 16;
      end
   endrule
   
   rule doVal if (state == DoValueTokens );

      //let reqMax = reqQ.first();
      let v <- deAlign_val.outPipe.get();
      let data = tpl_1(v);
      let nBytes = tpl_2(v);
      let bodylen = bodylenQ_val.first();
      //$display("%m, reqcnt = %d, byteCnt_val = %d, bodylen = %d, data = %h, nBytes = %d", reqCnt, byteCnt_val, bodylen, data, nBytes);
      if ( byteCnt_val + extend(nBytes) == bodylen ) begin
         state <= DoHeader;
         bodylenQ_val.deq();
         /*if ( reqCnt + 1 == reqMax ) begin
            $display("%m:: doVal:: Request finishes, enquening last request");
            reqQ.deq();
            reqCnt <= 0;
            byteCnt_hdr <= 0;
            byteCnt_val <= 0;
            outputQ.enq(tuple2(data,True));
         end
         else begin*/
         reqCnt <= reqCnt +1;
         if ( nBytes < 16 ) begin
            let hdrD <- deAlign_hdr[sel].outPipe.get();
            outputQ.enq(tuple2(data | tpl_1(hdrD), False));
            byteCnt_hdr <= extend(tpl_2(hdrD));
         end
         else begin
            outputQ.enq(tuple2(data, False));
            byteCnt_hdr <= 0;
         end
         //end
      end
      else begin
         outputQ.enq(tuple2(data, False));
         byteCnt_val <= byteCnt_val + 16;
      end
   endrule
   
   
   /*interface Put request;
      method Action put(Bit#(32) v);
         reqQ.enq(v);
         reqQ_1.enq(v);
      endmethod
   endinterface*/
   interface Put hdrPipe = toPut(reqQ);
   interface Put inPipe = deAlign_val.inPipe;//toPut(valQ);
   interface Get outPipe = toGet(outputQ);
      
endmodule
