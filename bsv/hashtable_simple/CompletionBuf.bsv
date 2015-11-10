import Vector::*;
import Fifo::*;


interface CompletionBuf#(numeric type numEntries, type element_type);
   method Bool search(element_type v);
   method Action insert(element_type v);
   method Action delete();
endinterface

module mkCompletionBuf(CompletionBuf#(numEntries, element_type))
   provisos(Add#(0, numEntries, TExp#(TLog#(numEntries))),
            Eq#(element_type),
            Bits#(element_type, a__));
   
   
   
   /*function Bool isFound(element_type v, element_type s);
      return v == s;
   endfunction*/
   
   SFifo#(numEntries, element_type, element_type) fifo <- mkPipelineSFifo();
   
   method Bool search(element_type v);
      return fifo.search(v);
   endmethod

   method Action insert(element_type v);
      fifo.enq(v);
   endmethod
   
   method Action delete();
      fifo.deq();
   endmethod
endmodule
