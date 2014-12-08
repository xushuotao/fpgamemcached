import Vector::*;

interface ScoreboardIfc#(numeric type numEntries);
   method Action hdrRequest(Bit#(32) hv);
   method Maybe#(Bit#(TLog#(numEntries))) hdrGrant();
   method Action insert(Bit#(32) hv, Bit#(TLog#(numEntries)) idx);
   method Action keyRequest(Bit#(32) hv, Bit#(TLog#(numEntries)) idx);
   method Bool keyGrant();
   method Action doneHdrWrite(Bit#(TLog#(numEntries)) idx);
   method Action doneKeyWrite(Bit#(TLog#(numEntries)) idx);
endinterface

module mkScoreboard(ScoreboardIfc#(numEntries));
   Vector#(numEntries, Reg#(Bool)) valids <- replicateM(mkReg(False));
   Vector#(numEntries, Reg#(Bit#(32))) hashValues <- replicateM(mkRegU());
   Vector#(numEntries, Reg#(Bool)) pendingHdrWr <- replicateM(mkReg(False));
   Vector#(numEntries, Reg#(Bool)) pendingKeyWr <- replicateM(mkReg(False));
 
   Reg#(Bit#(TLog#(numEntries))) oldestPtr <- mkReg(0);
   Reg#(Bit#(TLog#(numEntries))) nextPtr <- mkReg(0);
  
   Wire#(Bit#(32)) requestWire <- mkWire;
   Wire#(Maybe#(Bit#(TLog#(numEntries)))) grant_id <- mkWire;
   
   rule doHdrRequest;
      Bool conflicts = False;
      for (Integer i = 0; i < valueOf(numEntries); i = i + 1) begin
         if (valids[i] && requestWire == hashValues[i] && pendingHdrWr[i])
            conflicts = True;
      end 
           
      if (conflicts && !valids[nextPtr])
         grant_id <= tagged Invalid;
      else begin
         grant_id <= tagged Valid nextPtr;
      end
   endrule
   
   Wire#(Bit#(32)) requestWire1 <- mkWire;
   Wire#(Bit#(TLog#(numEntries))) idxWire <- mkWire;
   Wire#(Bool) responseWire1  <- mkWire;
   
   rule doKeyRequest;
      Bool grant = True;
      
      //if ( idx >= oldestPtr ) begin
      let real_idx = idxWire - oldestPtr;
      
      for (Integer i = 0; i < valueOf(numEntries); i = i + 1) begin
         let real_i = fromInteger(i) - oldestPtr;
         if ( requestWire1 == hashValues[i] && pendingKeyWr[i] && real_i < real_idx )
            grant = False;
      end 
      
      responseWire1 <= grant;
   endrule
   
   method Action hdrRequest(Bit#(32) hv);
      requestWire <= hv;
   endmethod
      
   method Maybe#(Bit#(TLog#(numEntries))) hdrGrant();
      return grant_id;
   endmethod
   
   method Action insert(Bit#(32) hv, Bit#(TLog#(numEntries)) idx);
      valids[idx] <= True;
      hashValues[idx] <= hv;
      pendingHdrWr[idx] <= True;
      pendingKeyWr[idx] <= True;
      nextPtr <= nextPtr + 1;
   endmethod
   
   method Action keyRequest(Bit#(32) hv, Bit#(TLog#(numEntries)) idx);
      requestWire1 <= hv;
      idxWire <= idx;
   endmethod
   
   method Bool keyGrant();
      return responseWire1;
   endmethod
   
   method Action doneHdrWrite(Bit#(TLog#(numEntries)) idx);
      pendingHdrWr[idx] <= False;
   endmethod
   
   method Action doneKeyWrite(Bit#(TLog#(numEntries)) idx);
      valids[idx] <= False;
      oldestPtr <= oldestPtr + 1;
   endmethod
endmodule

   
