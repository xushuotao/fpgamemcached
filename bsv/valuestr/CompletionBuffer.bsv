import Vector::*;
import Ehr::*;

interface CompletionBufferUpdateIFC#(type element_type);
   method Action addCmd (element_type v);
   method Action deleteCmd();// (element_type v);
endinterface

interface CompletionBufferQueryIFC#(type element_type);
   method Bool search (element_type v);
endinterface

interface CompletionBufferIfc#(type element_type, numeric type numEntries);
   interface CompletionBufferUpdateIFC#(element_type) updatePort;
   interface CompletionBufferQueryIFC#(element_type) queryPort;
endinterface


module mkCompletionBuffer(CompletionBufferIfc#(element_type, numEntries))
   provisos (Eq#(element_type),
             Bits#(element_type, a__));
   Ehr#(2, Bool) full_flag <- mkEhr(False);
   Vector#(numEntries, Reg#(element_type)) cmdEntries <- replicateM(mkRegU());
   Ehr#(2, Bit#(TLog#(numEntries))) oldestEntry <- mkEhr(0);
   Ehr#(2, Bit#(TLog#(numEntries))) nextEntry <- mkEhr(0);
   
   
   interface CompletionBufferUpdateIFC updatePort;
      method Action addCmd (element_type v) if ( !full_flag[0] );
         //$display("full_flag[0] = %d, nextEntry[0] = %d, oldestEntry[0] = %d", full_flag[0], nextEntry[0], oldestEntry[0]);
         cmdEntries[nextEntry[0]] <= v;
         nextEntry[0] <= nextEntry[0] + 1;
         if ( oldestEntry[0] == nextEntry[0] + 1) begin
            full_flag[0] <= True;
         end
      endmethod
      
      method Action deleteCmd () if ( oldestEntry[1] != nextEntry[1] || full_flag[1]);
         oldestEntry[1] <= oldestEntry[1] + 1;
         if (full_flag[1]) full_flag[1] <= False;
      endmethod
   endinterface
   
   interface CompletionBufferQueryIFC queryPort;
      method Bool search (element_type v);
         Bool hit = False;
         let real_idx = nextEntry[1] - oldestEntry[1];
         for (Integer i = 0; i < valueOf(numEntries); i = i + 1) begin
            let real_i = fromInteger(i) - oldestEntry[1];
            if ( v == cmdEntries[i] &&  real_i < real_idx )
               hit = True;
         end 
         return hit;
      endmethod
   endinterface
endmodule
   
