import FIFOF::*;
import FIFO::*;
import GetPut::*;

interface StreamingDeserializerIfc#(type tFrom, type tTo);
   method ActionValue#(tTo) deq;
   method Action enq(tFrom in, Bool cont);
endinterface

module mkStreamingDeserializer (StreamingDeserializerIfc#(tFrom, tTo))
   provisos(
      Bits#(tFrom, tFromSz)
      , Bits#(tTo, tToSz)
      , Add#(tFromSz, __a, tToSz)
      //, Log#(tFromSz, tFromSzLog)
            );
   Integer fromSz = valueOf(tFromSz);
   Integer toSz = valueOf(tToSz);

   Reg#(Bit#(32)) outCounter <- mkReg(0);
   Reg#(Bit#(tToSz)) outBuffer <- mkReg(0);

   FIFO#(tTo) outQ <- mkFIFO;

   method ActionValue#(tTo) deq;
      outQ.deq;
      return outQ.first;
   endmethod
   method Action enq(tFrom in, Bool cont);
      let inData = pack(in);
      Bit#(tToSz) nextBuffer = outBuffer | (zeroExtend(inData)<<outCounter);

      if ( outCounter + fromInteger(fromSz) > fromInteger(toSz) ) begin
	 let over = outCounter + fromInteger(fromSz) - fromInteger(toSz);
	 outQ.enq(unpack(nextBuffer));
	 if ( cont ) begin
	    outCounter <= over;
	    let minus = fromInteger(toSz) - outCounter;
	    outBuffer <= (zeroExtend(inData) >> minus);
	    //$display( "%x >%d %d %x", inData, over,outCounter, inData >> minus );
	 end else begin
		     outCounter <= 0;
		     outBuffer <= 0;
		  end
      end
      else if ( outCounter + fromInteger(fromSz) == fromInteger(toSz) ) begin
	 outBuffer <= 0;
	 outCounter <= 0;
	 outQ.enq(unpack(nextBuffer));
      end else if ( cont ) begin
			      outBuffer <= nextBuffer;
			      outCounter <= outCounter + fromInteger(fromSz);
			      //$display( "outcounter -> %d", outCounter + fromInteger(fromSz) );
		           end else begin
			               outBuffer <= 0;
			               outCounter <= 0;
		                    end
   endmethod
endmodule


interface StreamingSerializerIfc#(type tFrom, type tTo);
   method ActionValue#(Tuple2#(Tuple2#(tTo, Bool),Bit#(32))) deq;
   method Action enq(tFrom in, Bit#(32) tag);
endinterface

module mkStreamingSerializer (StreamingSerializerIfc#(tFrom, tTo))
   provisos(
            Bits#(tFrom, tFromSz)
            , Bits#(tTo, tToSz)
            , Add#(tToSz, __a, tFromSz)
            //, Log#(tFromSz, tFromSzLog)
      );

   Integer fromSz = valueOf(tFromSz);
   Integer toSz = valueOf(tToSz);

   FIFOF#(Tuple2#(Bit#(tFromSz), Bit#(32))) inQ <- mkFIFOF;
   Reg#(Bit#(32)) inCounter <- mkReg(0); // FIXME 32
   Reg#(Maybe#(Bit#(tFromSz))) inBuffer <- mkReg(tagged Invalid);

   FIFO#(Tuple2#(Tuple2#(tTo, Bool),Bit#(32))) outQ <- mkFIFO;
   
   Reg#(Bit#(32)) tagReg <- mkRegU();

   rule serialize;
      Bit#(tFromSz) inBufferData = fromMaybe(?, inBuffer);
      Bit#(tToSz) outData = truncate(inBufferData>>inCounter);

      
      if ( !isValid(inBuffer) ) begin
	 let v <- toGet(inQ).get();
         let inDta = tpl_1(v);
         let tag = tpl_2(v);
	 inBuffer <= tagged Valid inDta;
	 inCounter <= 0;
         tagReg <= tag;
      end
      else if ( inCounter + fromInteger(toSz) == fromInteger(fromSz) ) begin
	 //outQ.enq(tuple2(unpack(outData), True));
         outQ.enq(tuple2(tuple2(unpack(outData), True), tagReg));
	 inCounter <= 0;
	 if ( inQ.notEmpty ) begin
            let v <- toGet(inQ).get();
            let inDta = tpl_1(v);
            let tag = tpl_2(v);
	    Bit#(tFromSz) fromData = inDta;
	    inBuffer <= tagged Valid fromData;
            tagReg <= tag;
	 end
         else begin
	    inBuffer <= tagged Invalid;
	 end
      end
      else if ( inCounter + fromInteger(toSz) > fromInteger(fromSz) ) begin
	 if ( inQ.notEmpty ) begin
	    /*Bit#(tFromSz) fromData = inQ.first;
	    inQ.deq;
	    inBuffer <= tagged Valid fromData;*/
            
            let v <- toGet(inQ).get();
            let inDta = tpl_1(v);
            let tag = tpl_2(v);
	    Bit#(tFromSz) fromData = inDta;
	    inBuffer <= tagged Valid fromData;
            tagReg <= tag;
      
	    let over = inCounter + fromInteger(toSz) - fromInteger(fromSz);
	    Bit#(tToSz) combData = truncate( fromData << (fromInteger(toSz) -over)) | outData;
	    
	    outQ.enq(tuple2(tuple2(unpack(combData), True), tag));
	    inCounter <= over;
	 end 
         else begin
	    outQ.enq(tuple2(tuple2(unpack(outData), False), tagReg));
	    inCounter <= 0;
	    inBuffer <= tagged Invalid;
	 end
      end
      else begin
	 outQ.enq(tuple2(tuple2(unpack(outData), True), tagReg));
	 inCounter <= inCounter + fromInteger(toSz);
      end
   endrule


   method ActionValue#(Tuple2#(Tuple2#(tTo, Bool),Bit#(32))) deq; // value, continue? tag
      outQ.deq;
      /*let d = outQ.first;
      let data = tpl_1(d);
      let cont = tpl_2(d);*/
      return outQ.first;
   endmethod
   method Action enq(tFrom in, Bit#(32) tag);
      inQ.enq(tuple2(pack(in), tag));
   endmethod
endmodule
