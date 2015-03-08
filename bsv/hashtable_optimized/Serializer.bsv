//package Serializer;

import Vector::*;
import FIFO::*;
import SpecialFIFOs::*;

import GetPut::*;

import ParameterTypes::*;

interface DeserializerIfc;
   method Action start(Bit#(64) nInputs);
   interface Put#(Bit#(64)) inPipe;
   interface Get#(Bit#(128)) outPipe;
endinterface

interface SerializerIfc;
   method Action start(Bit#(64) nOutputs, Bit#(16) reqId);
   interface Put#(Bit#(128)) inPipe;
   interface Get#(Bit#(64)) outPipe;
endinterface

//(*synthesize*)
module mkDeserializer(DeserializerIfc);
   Reg#(Bit#(1)) sel <- mkReg(0);
   Vector#(2, FIFO#(Bit#(64))) packetFifos <- replicateM(mkBypassFIFO);
   FIFO#(Bit#(128)) bufFifo <- mkFIFO();

   
   rule doDeserial;
      let token0 <- toGet(packetFifos[0]).get();
      let token1 <- toGet(packetFifos[1]).get();
      bufFifo.enq({token1, token0});
   endrule
   
   FIFO#(Bit#(64)) cntMaxQ <- mkFIFO;
   Reg#(Bit#(64)) cnt <- mkReg(0);
   method Action start(Bit#(64) nInputs);
      cntMaxQ.enq(nInputs);
   endmethod
      
   interface Put inPipe;
      method Action put(Bit#(64) v);
         let cntMax = cntMaxQ.first();
         //$display("Deserializer, value = %h, cnt = %d", v, cnt);
         if ( cnt + 1 >= cntMax ) begin
           // $display("Deserializer, last token = %d, cnt = %d", v, cnt);
            cntMaxQ.deq();
            cnt <= 0;
            sel <= 0;
            packetFifos[sel].enq(v);
            if ( cnt[0] == 0 ) begin
               packetFifos[sel+1].enq(0);
            end
         end
         else begin
            sel <= sel + 1;
            cnt <= cnt + 1;
            packetFifos[sel].enq(v);
         end
      endmethod
   endinterface    
   interface Get outPipe = toGet(bufFifo);
endmodule
   
//(*synthesize*)
module mkSerializer(SerializerIfc);
   FIFO#(Bit#(128)) bufFifo <- mkBypassFIFO();
   FIFO#(Bit#(64)) packetFifo <- mkFIFO;
   Reg#(Bit#(1)) sel <- mkReg(0);
   FIFO#(Tuple2#(Bit#(64),Bit#(16))) cntMaxQ <- mkSizedFIFO(numStages);
   Reg#(Bit#(64)) cnt <- mkReg(0);
   
   rule doSerial;
      Vector#(2,Bit#(64)) packets = unpack(bufFifo.first());
      //$display("Putting packets[%d] = %h to outPipe, reqCnt = %d", sel, packets[sel], tpl_2(cntMaxQ.first));
      packetFifo.enq(packets[sel]);
     
      let cntMax = tpl_1(cntMaxQ.first());
      if ( cnt + 1 >= cntMax ) begin
         cnt <= 0;
         cntMaxQ.deq();
         bufFifo.deq();
         sel <= 0;
         //$display("Serializer last token, packets[%d] = %h, reqCnt = %d", sel, packets[sel], tpl_2(cntMaxQ.first));
      end
      else begin
         if ( sel == 1 ) begin
            bufFifo.deq();
         end
         sel <= sel + 1;
         cnt <= cnt + 1;
      end
   endrule   
   
   method Action start(Bit#(64) nOutputs, Bit#(16) reqId);
      cntMaxQ.enq(tuple2(nOutputs,reqId));
   endmethod
      
   interface Put inPipe = toPut(bufFifo);
   interface Get outPipe = toGet(packetFifo);
endmodule
   
//endpackage

interface DeserializerTagIfc;
   method Action start(Bit#(64) nInputs, Bit#(32) tag);
   interface Put#(Bit#(64)) inPipe;
   interface Get#(Tuple2#(Bit#(128), Bit#(32))) outPipe;
endinterface

module mkDeserializerTag(DeserializerTagIfc);
   Reg#(Bit#(1)) sel <- mkReg(0);
   Vector#(2, FIFO#(Tuple2#(Bit#(64), Bit#(32)))) packetFifos <- replicateM(mkBypassFIFO);
   FIFO#(Tuple2#(Bit#(128), Bit#(32))) bufFifo <- mkFIFO();

   
   rule doDeserial;
      let token0 <- toGet(packetFifos[0]).get();
      let token1 <- toGet(packetFifos[1]).get();
      bufFifo.enq(tuple2({tpl_1(token1), tpl_1(token0)},tpl_2(token0)));
   endrule
   
   FIFO#(Tuple2#(Bit#(64), Bit#(32))) cntMaxQ <- mkFIFO;
   Reg#(Bit#(64)) cnt <- mkReg(0);
   method Action start(Bit#(64) nInputs, Bit#(32) tag);
      cntMaxQ.enq(tuple2(nInputs, tag));
   endmethod
      
   interface Put inPipe;
      method Action put(Bit#(64) v);
         let d = cntMaxQ.first();
         let cntMax = tpl_1(d);
         let tag = tpl_2(d);
         //$display("Deserializer, Value = %h, cnt = %d", v, cnt);
         if ( cnt + 1 >= cntMax ) begin
            //$display("Deserializer, last token = %h, cnt = %d", v, cnt);
            cntMaxQ.deq();
            cnt <= 0;
            sel <= 0;
            packetFifos[sel].enq(tuple2(v, tag));
            if ( cnt[0] == 0 ) begin
               packetFifos[sel+1].enq(tuple2(0, tag));
            end
         end
         else begin
            sel <= sel + 1;
            cnt <= cnt + 1;
            packetFifos[sel].enq(tuple2(v, tag));
         end
      endmethod
   endinterface    
   interface Get outPipe = toGet(bufFifo);
endmodule
