`include "ProtocolHeader.bsv"
typedef TDiv#(TSub#(a, TDiv#(b,2)),b) RDiv#(a,b);

interface TestIFC#(numeric type bufSz);
endinterface

module mkTest(TestIFC#(bufSz));
   Integer buf_size = valueOf(bufSz);
   Bit#(32) shit = 0;
   Reg#(Bit#(32)) a <- mkRegU();
   Reg#(Bit#(32)) b <- mkRegU();
   
   Reg#(Bit#(SizeOf#(Bit#(32)))) dummy <- mkRegU();
   rule proc;//if (flag == True);
//      $display("HeaderSz = %d", valueOf(ReqHeaderSz));
      a <= extend(b);
      $display("size of dummy is %d", valueOf(SizeOf#(dummy)));
      $finish;
   endrule
endmodule

module mkTop(Empty);
   TestIFC#(32) v <- mkTest;
endmodule
         
