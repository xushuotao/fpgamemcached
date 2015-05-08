import BRAM::*;
import FIFO::*;
import ClientServer::*;


interface DataReorderBuffer;
   interface Server#(Bit#(8), Bit#(7)) reserve;
   interface Put#(Tuple2#(Bit#(128), Bit#(7))) inDataQ;
   interface Get#(Bit#(128)) outDataQ;
endinterface

module mkDataReorderBuffer(DataReorderBuffer);
   
   BRAM_Configure cfg = defaultValue;
   BRAM2Port#(Bit#(16), Bit#(128)) bramBuf <- mkBRAM2Server(cfg);
   let tagServer <- mkTagAlloc;
   
   

   interface Server#(Bit#(8), Bit#(7)) reserve;
   interface Put#(Tuple2#(Bit#(128), Bit#(7))) inDataQ;
   interface Get#(Bit#(128)) outDataQ;
   
endmodule   
   
   
