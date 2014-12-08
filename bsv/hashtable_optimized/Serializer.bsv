package Serializer;

import Vector::*;
import FIFO::*;
import SpecialFIFOs::*;

import GetPut::*;


interface DeserializerIfc;
   method Action start(Bit#(8) nInputs);
   interface Put#(Bit#(64)) inPipe;
   interface Get#(Bit#(128)) outPipe;
endinterface

interface SerializerIfc;
   method Action start(Bit#(8) nOutputs);
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
   
   FIFO#(Bit#(8)) cntMaxQ <- mkLFIFO;
   Reg#(Bit#(8)) cnt <- mkReg(0);
   method Action start(Bit#(8) nInputs);
      cntMaxQ.enq(nInputs);
   endmethod
      
   interface Put inPipe;
      method Action put(Bit#(64) v);
         let cntMax = cntMaxQ.first();
         if ( cnt + 1 == cntMax ) begin
            $display("Deserializer, last token = %d, cnt = %d", v, cnt);
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
   FIFO#(Bit#(8)) cntMaxQ <- mkLFIFO;
   Reg#(Bit#(8)) cnt <- mkReg(0);
   
   rule doSerial;
      Vector#(2,Bit#(64)) packets = unpack(bufFifo.first());
      packetFifo.enq(packets[sel]);
     
      let cntMax = cntMaxQ.first();
      if ( cnt + 1 == cntMax ) begin
         cnt <= 0;
         cntMaxQ.deq();
         bufFifo.deq();
         sel <= 0;
         $display("Serializer last token, packets[sel] = %d", packets[sel]);
      end
      else begin
         if ( sel == 1 ) begin
            bufFifo.deq();
         end
         sel <= sel + 1;
         cnt <= cnt + 1;
      end
   endrule   
   
   method Action start(Bit#(8) nOutputs);
      cntMaxQ.enq(nOutputs);
   endmethod
      
   interface Put inPipe = toPut(bufFifo);
   interface Get outPipe = toGet(packetFifo);
endmodule
   
endpackage
