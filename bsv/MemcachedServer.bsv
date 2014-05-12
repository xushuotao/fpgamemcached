

//import FIFO::*;
/*
typedef struct{
   Bit#(32) a;
   Bit#(32) b;
   } S1 deriving (Bits);

typedef struct{
   Bit#(32) a;
   Bit#(16) b;
   Bit#(7) c;
   } S2 deriving (Bits);

typedef enum {
   E1Choice1,
   E1Choice2,
   E1Choice3
   } E1 deriving (Bits,Eq);

typedef struct{
   Bit#(32) a;
   E1 e1;
   } S3 deriving (Bits);

interface SimpleIndication;
    method Action heard1(Bit#(32) v);
    method Action heard2(Bit#(16) a, Bit#(16) b);
    method Action heard3(S1 v);
    method Action heard4(S2 v);
    method Action heard5(Bit#(32) a, Bit#(64) b, Bit#(32) c);
    method Action heard6(Bit#(32) a, Bit#(40) b, Bit#(32) c);
    method Action heard7(Bit#(32) a, E1 e1);
endinterface

interface SimpleRequest;
    method Action say1(Bit#(32) v);
    method Action say2(Bit#(16) a, Bit#(16) b);
    method Action say3(S1 v);
    method Action say4(S2 v);
    method Action say5(Bit#(32)a, Bit#(64) b, Bit#(32) c);
    method Action say6(Bit#(32)a, Bit#(40) b, Bit#(32) c);
    method Action say7(S3 v);
endinterface

typedef struct {
    Bit#(32) a;
    Bit#(40) b;
    Bit#(32) c;
} Say6ReqSimple deriving (Bits);

*/

interface ServerIndication;
   method Action hexdump(Bit#(32) v);
endinterface

interface ServerRequest;
   method Action receive_cmd(Bit#(32) cmd);
endinterface

module mkServerRequest#(ServerIndication indication)(ServerRequest);
   
   method Action receive_cmd(Bit#(32) cmd);
      indication.hexdump(cmd);
   endmethod
   /*
   method Action say1(Bit#(32) v);
      indication.heard1(v);
   endmethod
   
   method Action say2(Bit#(16) a, Bit#(16) b);
      indication.heard2(a,b);
   endmethod
      
   method Action say3(S1 v);
      indication.heard3(v);
   endmethod
   
   method Action say4(S2 v);
      indication.heard4(v);
   endmethod
      
   method Action say5(Bit#(32) a, Bit#(64) b, Bit#(32) c);
      indication.heard5(a, b, c);
   endmethod

   method Action say6(Bit#(32) a, Bit#(40) b, Bit#(32) c);
      indication.heard6(a, b, c);
   endmethod

   method Action say7(S3 v);
      indication.heard7(v.a, v.e1);
   endmethod
   */
endmodule