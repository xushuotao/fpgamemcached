package SerDes;

import GetPut::*;
import FIFO::*;
import FIFOF::*;

import Shifter::*;

typedef TAdd#(TLog#(TDiv#(inputSz, outputSz)),1) LgNOutputs#(numeric type inputSz, numeric type outputSz);

interface SerializerIfc#(numeric type inputSz, numeric type outputSz);
   method Action marshall(Bit#(inputSz) value, Bit#(LgNOutputs#(inputSz, outputSz)) nOutputs);
   method ActionValue#(Bit#(outputSz)) getVal;
endinterface

interface DeserializerIfc#(numeric type inputSz, numeric type outputSz);
   method Action request(Bit#(LgNOutputs#(outputSz, inputSz)) nInputs);
   //method Action putVal(Bit#(inputSz) v);
   interface Put#(Bit#(inputSz)) demarshall;
   method ActionValue#(Bit#(outputSz)) getVal;
endinterface


module mkSerializer(SerializerIfc#(inputSz, outputSz))
   provisos(Add#(a__, outputSz, inputSz));
   FIFOF#(Tuple2#(Bit#(inputSz), Bit#(LgNOutputs#(inputSz, outputSz)))) inputFIFO <- mkFIFOF;
   Reg#(Bit#(inputSz)) inputBuf <- mkRegU();
   Reg#(Bit#(LgNOutputs#(inputSz, outputSz))) cnt <- mkReg(0);
   Reg#(Bit#(LgNOutputs#(inputSz, outputSz))) cntMax <- mkReg(0);
   FIFO#(Bit#(outputSz)) outputBuf <- mkFIFO();
   rule doSer;
      if ( cnt + 1 >= cntMax ) begin
         cnt <= 0;
         if ( cntMax != 0 ) begin
            outputBuf.enq(truncate(inputBuf));
         end
      
         if ( inputFIFO.notEmpty ) begin
            let args <- toGet(inputFIFO).get;
            inputBuf <= tpl_1(args);
            cntMax <= tpl_2(args);
         end
         else begin
            cntMax <= 0;
         end
      end
      else begin
         cnt <= cnt + 1;
         outputBuf.enq(truncate(inputBuf));
         inputBuf <= inputBuf >> valueOf(outputSz);
      end
   endrule
      
   method Action marshall(Bit#(inputSz) value, Bit#(LgNOutputs#(inputSz, outputSz)) nOutputs);
      //$display("marshall value = %h, nOutputs = %d", value, nOutputs);
      inputFIFO.enq(tuple2(value, nOutputs));
   endmethod
   
   method ActionValue#(Bit#(outputSz)) getVal;
      let v <- toGet(outputBuf).get;
      return v;
   endmethod
endmodule

module mkDeserializer(DeserializerIfc#(inputSz, outputSz))
   provisos(Add#(a__, inputSz, outputSz));
   FIFOF#(Bit#(LgNOutputs#(outputSz, inputSz))) cntMaxQ <- mkFIFOF;
   FIFO#(Bit#(inputSz)) inputFIFO <- mkFIFO;
   
   Reg#(Bit#(LgNOutputs#(outputSz, inputSz))) cnt <- mkReg(0);

   Reg#(Bit#(outputSz)) outputBuf <- mkRegU();
  // FIFO#(Bit#(outputSz)) outputFIFO <- mkFIFO();
   
   ByteSftIfc#(Bit#(outputSz)) sfter <- mkCombinationalRightShifter;
   
   Integer nInBytes = valueOf(TDiv#(inputSz, 8));
   Integer nOutBytes = valueOf(TDiv#(outputSz, 8));
   
   Reg#(Bit#(TLog#(TDiv#(outputSz, 8)))) leftBytes <- mkReg(fromInteger(nOutBytes-nInBytes));
   
   rule doDes;
      let cntMax = cntMaxQ.first();
      if ( cntMax > 0 ) begin
         let word <- toGet(inputFIFO).get();
         outputBuf <= truncateLSB({word, outputBuf});
         //outputBuf <= truncate({outputBuf, word});
         
         if ( cnt + 1 >= cntMax ) begin
            //outputFIFO.enq(truncateLSB({word, outputBuf}));
            leftBytes <= fromInteger(nOutBytes-nInBytes);
            $display("data = %h, leftBytes = %d",{word, outputBuf}, leftBytes);
            sfter.rotateByteBy(truncateLSB({word, outputBuf}), leftBytes);
            //outputFIFO.enq(truncate({outputBuf,word}));
            cnt <= 0;
            cntMaxQ.deq();
         end
         else begin
            leftBytes <= leftBytes - fromInteger(nInBytes);
            cnt <= cnt + 1;
         end
      end
      else begin
         //outputFIFO.enq(outputBuf);
         cntMaxQ.deq();
      end
   endrule
   method Action request(Bit#(LgNOutputs#(outputSz, inputSz)) nInputs);
      //$display("Deserializer got request, nInputs = %d", nInputs);
      cntMaxQ.enq(nInputs);
   endmethod
   
   interface Put demarshall = toPut(inputFIFO);
   
   method ActionValue#(Bit#(outputSz)) getVal;
      //let v <- toGet(outputFIFO).get();
      let v <- sfter.getVal;
      return v;
   endmethod
endmodule

endpackage
