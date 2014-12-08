

typedef enum {DoHdrRd, DoKeyRd, DoHdrWr, DoHdrWr} InstrState;

interface InstrBoardIfc#(numeric type nEntries);
   method Action insert(Bit#(32) hv);
   method Action update(Bit#(32) hv, InstrState state);
endinterface

      
      

module mkInstrBoard(InstrBoardIfc#(nEntries));
   Vector#(nEntries, Reg#(Maybe#(Bit#(32)))) hashValues <- replicateM(mkReg(tagged Invalid));
   Vector#(nEntries, Reg#(InstrState)) instrStates <- replicateM(mkRegU());
   
   function Maybe#(Bit#(TLog#(nEntries))) toMask(Vector#(nEntries, Reg#(Maybe#(Bit#(32)))) vec);
      Maybe#(Bit#(TLog#(nEntries))) retval;
      for (Integer i = 0; i < valueOf(nEntries); i = i + 1) begin
         if (vec[i] matches tagged Valid.d) begin
            retval = tagged Valid fromInteger(i);
         end
   endfunction
         

   
   method Action insert(Bit#(32) hv);
   method Action update(Bit#(32) hv, InstrState state);
