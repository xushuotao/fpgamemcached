import FIFO::*;
import Vector::*;

//`define DEBUG

interface JenkinsHashIfc;
   method Action start(Bit#(32) length);
   method Action putKey(Bit#(64) key);
   method ActionValue#(Bit#(32)) getHash();
endinterface

function Bit#(32) rot(Bit#(32) x, Bit#(5) offset);
   //return (x << offset) ^ ((x >> (~offset)+1));
   return rotateBitsBy(x, unpack(offset));
endfunction

interface DataAlignIfc;
   method Action start(Bit#(32) length);
   method Action putKeys(Bit#(64) v);
   method ActionValue#(Bit#(96)) resp();
endinterface

interface MixEngIfc;
   method Action start(Bit#(32) length);
   method Action putKeys(Bit#(32) key_0, Bit#(32) key_1, Bit#(32) key_2);
   method ActionValue#(Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bool)) resp();
endinterface

interface FinalMixEngIfc;
   method Action req(Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bool) v);
   //method ActionValue#(Bit#(32)) resp();
   method Bit#(32) resp();
endinterface

module mkDataAlign(DataAlignIfc);   
   
   FIFO#(Bit#(64)) keyFifo <- mkFIFO;
   FIFO#(Bit#(96)) procFifo <- mkFIFO;
   
   /****Data alignment ****/
   Reg#(Bit#(96)) hashBuf <- mkRegU();
   Reg#(Bit#(2)) bufCnt <- mkRegU();
   
   Reg#(Bit#(64)) wordBuf <- mkRegU();
   Reg#(Bit#(2)) wordCnt <- mkRegU();
   
   Reg#(Int#(32)) nBytes <- mkReg(-1);
   Reg#(Bit#(32)) burstLen <- mkRegU();
   
   rule align_data if ( nBytes > 0);
      $display("AlignData: nBytes = %d, burstLen = %d, wordCnt = %d, bufCnt = %d, wordBuf = %h, hashBuf = %h", nBytes, burstLen, wordCnt, bufCnt, wordBuf, hashBuf); 
      if (bufCnt > wordCnt) begin
         bufCnt <= bufCnt - wordCnt;
         hashBuf <= truncate({wordBuf, hashBuf} >> {wordCnt, 5'b0});
         if ( burstLen > 0 ) begin
            wordBuf <= keyFifo.first;
            keyFifo.deq();
            burstLen <= burstLen - 1;
            wordCnt <= 2;
         end
         else begin
            procFifo.enq(truncate({wordBuf, hashBuf} >> {bufCnt, 5'b0}));
            wordCnt <= 0;
            nBytes <= nBytes - 12;
         end
         
      end
      else begin
         bufCnt <= 3;
         wordCnt <= wordCnt - bufCnt;
         wordBuf <= wordBuf >> {bufCnt, 5'b0};
         procFifo.enq(truncate({wordBuf, hashBuf} >> {bufCnt, 5'b0}));
         nBytes <= nBytes - 12;
      end
   endrule
   
   method Action start(Bit#(32) length) if (nBytes <=0);
         
      bufCnt <= 3;
      wordCnt <= 0;
      
      nBytes <= unpack(length);
      $display("\x1b[32mHardware:: Initalize_phase, a = %h, b = %h, c = %h\x1b[0m", 32'hdeadbeef + length , 32'hdeadbeef + length, 32'hdeadbeef + length);
      if ( length[2:0] == 0 ) begin
         $display("\x1b[32mHardware:: nBytes = %d, burstLen = %d\x1b[0m", length, length>>3);
         burstLen <= truncate(length >> 3);
      end
      else begin
         $display("\x1b[32mHardware:: nBytes = %d, burstLen = %d\x1b[0m", length, (length>>3)+1);
         burstLen <= truncate(length >> 3) + 1;
      end
   endmethod
   
   method Action putKeys(Bit#(64) v);
      keyFifo.enq(v);
   endmethod
   
   method ActionValue#(Bit#(96)) resp();
      procFifo.deq();
      return procFifo.first();
   endmethod
   
endmodule

typedef enum {Idle, Phase0, Phase1} MixEngState deriving (Bits, Eq);
module mkMixEng(MixEngIfc);
   Reg#(Bit#(32)) reg_a <- mkReg(0);
   Reg#(Bit#(32)) reg_b <- mkReg(0);
   Reg#(Bit#(32)) reg_c <- mkReg(0);
   Reg#(Bit#(32)) keylen <- mkReg(0);
   
   Reg#(Bit#(32)) reg_aa <- mkReg(0);
   Reg#(Bit#(32)) reg_bb <- mkReg(0);
   Reg#(Bit#(32)) reg_cc <- mkReg(0);
   
   FIFO#(Bit#(96)) inputFifo <- mkFIFO;
   FIFO#(Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bool)) outputFifo <- mkFIFO;
   Reg#(MixEngState) state <- mkReg(Idle);
   
   rule mix_phase_0 if (keylen > 12 && state == Phase0);
      Vector#(3, Bit#(32)) key = unpack(inputFifo.first());
      inputFifo.deq();
      
      let a = reg_a + key[0];
      let b = reg_b + key[1];
      let c = reg_c + key[2];
      
       
      a = a-c;  a = a^rot(c, 4);  c = c+b;
      b = b-a;  b = b^rot(a, 6);  a = a+c; 
      c = c-b;  c = c^rot(b, 8);  b = b+a;
      
//      mixFifo.enq(Tuple3(a,b,c));
/*      a = a-c;  a = a^rot(c,16);  c = c+b;
      b = b-a;  b = b^rot(a,19);  a = a+c;
      c = c-b;  c = c^rot(b, 4);  b = b+a;
      
      $display("\x1b[32mHardware:: Mix_phase, a = %h, b = %h, c = %h\x1b[0m", a, b, c);*/
      reg_aa <= a;
      reg_bb <= b;
      reg_cc <= c;
      state <= Phase1;
      //keylen <= keylen - 12;
   endrule
   
   rule mix_phase_1 if (state == Phase1);

      let a = reg_aa;
      let b = reg_bb;
      let c = reg_cc;
      
      a = a-c;  a = a^rot(c,16);  c = c+b;
      b = b-a;  b = b^rot(a,19);  a = a+c;
      c = c-b;  c = c^rot(b, 4);  b = b+a;
      
      $display("\x1b[32mHardware:: Mix_phase, a = %h, b = %h, c = %h\x1b[0m", a, b, c);
      
      reg_a <= a;
      reg_b <= b;
      reg_c <= c;
      keylen <= keylen - 12;
      state <= Phase0;
   endrule
      
 
   rule final_mix if (keylen <= 12 && state == Phase0);
      
      if (keylen == 0) begin
         outputFifo.enq(tuple4(reg_a, reg_b, reg_c, True));
      end
      else begin
         Vector#(3, Bit#(32)) k = unpack(inputFifo.first());
         inputFifo.deq();
         let c = reg_c + k[2];
         let b = reg_b + k[1];
         let a = reg_a + k[0];
         $display("\x1b[32mHardware:: Final_mix, a = %h, b = %h, c = %h\x1b[0m", reg_a+k[0], reg_b+k[1], reg_c+k[2]);      
         
         outputFifo.enq(tuple4(a, b, c, False));
      end
      
      state <= Idle;
   endrule
   
   
   method Action start(Bit#(32) length) if (state == Idle);
      keylen <= length;
      reg_a <= 32'hdeadbeef + length;
      reg_b <= 32'hdeadbeef + length;
      reg_c <= 32'hdeadbeef + length;
      
      state <= Phase0;
     
   endmethod
   method Action putKeys(Bit#(32) key_0, Bit#(32) key_1, Bit#(32) key_2);
      inputFifo.enq({key_2, key_1, key_0});
   endmethod
   method ActionValue#(Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bool)) resp();
      outputFifo.deq();
      return outputFifo.first();
   endmethod
endmodule

module mkFinalMixEng(FinalMixEngIfc);
   Wire#(Bit#(32)) wire_a <- mkWire;
   Wire#(Bit#(32)) wire_b <- mkWire;
   Wire#(Bit#(32)) wire_c <- mkWire;
   Wire#(Bool) wire_skip <- mkWire;
   
   Wire#(Bit#(32)) hVal <- mkWire;
   
//   Wire#(Bool) poke <- mkWire;
//   FIFO#(Bit#(32)) outputFifo <- mkFIFO;
   
   FIFO#(Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bool)) finalFifo <- mkFIFO;
   /*
   rule final_phase_0;
      if (!wire_skip) begin
         let a = wire_a;
         let b = wire_b;
         let c = wire_c;
         
         c = c^b; c = c-rot(b,14);
         a = a^c; a = a-rot(c,11);
         b = b^a; b = b-rot(a,25);
         c = c^b; c = c-rot(b,16);
         a = a^c; a = a-rot(c,4); 
         b = b^a; b = b-rot(a,14);
         c = c^b; c = c-rot(b,24);
         $display("\x1b[32mHardware:: Final_phase, a = %h, b = %h, c = %h\x1b[0m", a, b, c);
      
      end
      else begin
    //     outputFifo.enq(wire_c);
         hVal <= wire_c;
      end
   endrule
   */
   rule final_phase_0;
      
      let a = wire_a;
      let b = wire_b;
      let c = wire_c;
      //$display("\x1b[32mHardware:: Final_phase, a = %h, b = %h, c = %h\x1b[0m", a, b, c);
      c = c^b; c = c-rot(b,14);
      a = a^c; a = a-rot(c,11);
      b = b^a; b = b-rot(a,25);
      /*c = c^b; c = c-rot(b,16);
      a = a^c; a = a-rot(c,4); 
      b = b^a; b = b-rot(a,14);
      c = c^b; c = c-rot(b,24);*/
      $display("\x1b[32mHardware:: Final_phase, a = %h, b = %h, c = %h\x1b[0m", a, b, c);
      //hashFifo.enq(c);
      //end
      //else
      // begin
      //hashFifo.enq(reg_c);
      //end
      
      finalFifo.enq(tuple4(a, b, c, wire_skip));
      
   endrule 
   
   rule final_phase_1;
      let d = finalFifo.first;
      finalFifo.deq;
      
      let a = tpl_1(d);
      let b = tpl_2(d);
      let c = tpl_3(d);
      let flag = tpl_4(d);
      
      if (!flag) begin
         c = c^b; c = c-rot(b,16);
         a = a^c; a = a-rot(c,4); 
         b = b^a; b = b-rot(a,14);
         c = c^b; c = c-rot(b,24);
      end
      
      hVal <= c;
      
   
   endrule

   method Action req(Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bool) v);
      wire_a <= tpl_1(v);
      wire_b <= tpl_2(v);
      wire_c <= tpl_3(v);
      wire_skip <= tpl_4(v);
//      poke <= True;
   endmethod
   method Bit#(32) resp();
//      outputFifo.deq();
      return hVal;// outputFifo.first();
   endmethod
endmodule
         
(*synthesize*)
module mkJenkinsHash (JenkinsHashIfc);
   
   FIFO#(Bit#(32)) hashFifo <- mkFIFO;
   
   let dataAlign <- mkDataAlign;
   let mixEng <- mkMixEng;
   let final_mixEng <- mkFinalMixEng;
   
   rule mix_phase;
      let v <- dataAlign.resp();
      Vector#(3, Bit#(32)) key = unpack(v);
      mixEng.putKeys(key[0], key[1], key[2]);
   endrule
   
   rule final_phase;
      let v <- mixEng.resp();
      final_mixEng.req(v);
   endrule
   
   rule output_phase;
      let v = final_mixEng.resp();
      hashFifo.enq(v);
   endrule

   method Action start(Bit#(32) length);
      dataAlign.start(length);
      mixEng.start(length);
   endmethod
   
   method Action putKey(Bit#(64) key);
      dataAlign.putKeys(key);
   endmethod
   
   method ActionValue#(Bit#(32)) getHash();
      hashFifo.deq();
      return hashFifo.first();
   endmethod
      
endmodule
