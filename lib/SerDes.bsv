package SerDes;

import GetPut::*;
import FIFO::*;
import FIFOF::*;

import Shifter::*;

typedef TAdd#(TLog#(TDiv#(inputSz, outputSz)),1) LgNOutputs#(numeric type inputSz, numeric type outputSz);

interface SerializerIfc#(numeric type inputSz, numeric type outputSz, type tag_type);
   method Action marshall(Bit#(inputSz) value, Bit#(LgNOutputs#(inputSz, outputSz)) nOutputs, tag_type tag);
   method ActionValue#(Tuple2#(Bit#(outputSz), tag_type)) getVal;
endinterface

interface DeserializerIfc#(numeric type inputSz, numeric type outputSz, type tag_type);
   method Action request(Bit#(LgNOutputs#(outputSz, inputSz)) nInputs, tag_type tag);
   //method Action putVal(Bit#(inputSz) v);
   interface Put#(Bit#(inputSz)) demarshall;
   method ActionValue#(Tuple2#(Bit#(outputSz), tag_type)) getVal;
endinterface


module mkSerializer(SerializerIfc#(inputSz, outputSz, tag_type))
   provisos(Add#(a__, outputSz, inputSz),
            Bits#(tag_type, b__));
   FIFOF#(Tuple3#(Bit#(inputSz), Bit#(LgNOutputs#(inputSz, outputSz)), tag_type)) inputFIFO <- mkFIFOF;
   Reg#(Bit#(inputSz)) inputBuf <- mkRegU();
   Reg#(tag_type) tagReg <- mkRegU();
   Reg#(Bit#(LgNOutputs#(inputSz, outputSz))) cnt <- mkReg(0);
   Reg#(Bit#(LgNOutputs#(inputSz, outputSz))) cntMax <- mkReg(0);   
   FIFO#(Tuple2#(Bit#(outputSz), tag_type)) outputFIFO <- mkFIFO();
   rule doSer;
      if ( cnt + 1 >= cntMax ) begin
         cnt <= 0;
         if ( cntMax != 0 ) begin
            outputFIFO.enq(tuple2(truncate(inputBuf), tagReg));
         end
      
         if ( inputFIFO.notEmpty ) begin
            let args <- toGet(inputFIFO).get;
            inputBuf <= tpl_1(args);
            cntMax <= tpl_2(args);
            tagReg <= tpl_3(args);
         end
         else begin
            cntMax <= 0;
         end
      end
      else begin
         cnt <= cnt + 1;
         outputFIFO.enq(tuple2(truncate(inputBuf), tagReg));
         inputBuf <= inputBuf >> valueOf(outputSz);
      end
   endrule
      
   method Action marshall(Bit#(inputSz) value, Bit#(LgNOutputs#(inputSz, outputSz)) nOutputs, tag_type tag);
      //$display("marshall value = %h, nOutputs = %d", value, nOutputs);
      inputFIFO.enq(tuple3(value, nOutputs, tag));
   endmethod
   
   method ActionValue#(Tuple2#(Bit#(outputSz),tag_type)) getVal;
      let v <- toGet(outputFIFO).get;
      return v;
   endmethod
endmodule

module mkDeserializer(DeserializerIfc#(inputSz, outputSz, tag_type))
   provisos(Add#(a__, inputSz, outputSz),
            Bits#(tag_type, b__),
            Add#(1, d__, outputSz));
   FIFOF#(Tuple2#(Bit#(LgNOutputs#(outputSz, inputSz)), tag_type)) cntMaxQ <- mkFIFOF;
   FIFO#(Bit#(inputSz)) inputFIFO <- mkFIFO;
   
   Reg#(Bit#(LgNOutputs#(outputSz, inputSz))) cnt <- mkReg(0);

   Reg#(Bit#(outputSz)) outputBuf <- mkRegU();
  // FIFO#(Bit#(outputSz)) outputFIFO <- mkFIFO();
   
   ByteSftIfc#(Bit#(outputSz)) sfter <- mkCombinationalRightShifter;
   
   Integer nInBytes = valueOf(TDiv#(inputSz, 8));
   Integer nOutBytes = valueOf(TDiv#(outputSz, 8));
   
   Reg#(Bit#(TLog#(TDiv#(outputSz, 8)))) leftBytes <- mkReg(fromInteger(nOutBytes-nInBytes));
   FIFO#(tag_type) tagQ <- mkFIFO();
   rule doDes;
      let v = cntMaxQ.first();
      let cntMax = tpl_1(v);
      let tag = tpl_2(v);
      if ( cntMax > 0 ) begin
         let word <- toGet(inputFIFO).get();
         outputBuf <= truncateLSB({word, outputBuf});
         //outputBuf <= truncate({outputBuf, word});
         
         if ( cnt + 1 >= cntMax ) begin
            //outputFIFO.enq(truncateLSB({word, outputBuf}));
            leftBytes <= fromInteger(nOutBytes-nInBytes);
            //$display("data = %h, leftBytes = %d",{word, outputBuf}, leftBytes);
            sfter.rotateByteBy(truncateLSB({word, outputBuf}), leftBytes);
            tagQ.enq(tag);
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
   method Action request(Bit#(LgNOutputs#(outputSz, inputSz)) nInputs, tag_type tag);
      //$display("Deserializer got request, nInputs = %d", nInputs);
      cntMaxQ.enq(tuple2(nInputs,tag));
   endmethod
   
   interface Put demarshall = toPut(inputFIFO);
   
   method ActionValue#(Tuple2#(Bit#(outputSz), tag_type)) getVal;
      //let v <- toGet(outputFIFO).get();
      let v <- sfter.getVal;
      let tag <- toGet(tagQ).get();
      return tuple2(v, tag);
   endmethod
endmodule

endpackage
