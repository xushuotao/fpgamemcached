import FIFO::*;
import Vector::*;

//`define DEBUG

interface JenkinsHashIfc;
   method Action start(Bit#(32) length);
   method Action putKey(Bit#(96) key);
   method ActionValue#(Bit#(32)) getHash();
endinterface

function Bit#(32) rot(Bit#(32) x, Bit#(5) offset);
   return (x << offset) ^ ((x >> (~offset)+1));
endfunction

/*`define mix(a,b,c)
{
 a -= c;  a ^= rot(c, 4);  c += b;
 b -= a;  b ^= rot(a, 6);  a += c; 
 c -= b;  c ^= rot(b, 8);  b += a;
 a -= c;  a ^= rot(c,16);  c += b;
 b -= a;  b ^= rot(a,19);  a += c;
 c -= b;  c ^= rot(b, 4);  b += a;
 }
 */         

module mkJenkinsHash (JenkinsHashIfc);
   Reg#(Bool) idle <- mkReg(True);
   Reg#(Bool) skip <- mkRegU();
   Reg#(Bit#(32)) keylen <- mkRegU();
   
   FIFO#(Bit#(96)) keyFifo <- mkFIFO;
   FIFO#(Bit#(32)) hashFifo <- mkFIFO;
   
   Reg#(Bit#(32)) reg_a <- mkReg(0);
   Reg#(Bit#(32)) reg_b <- mkReg(0);
   Reg#(Bit#(32)) reg_c <- mkReg(0);
   
   
   rule mix_phase if (keylen > 12 && !idle);
     
      
      Vector#(3, Bit#(32)) key = unpack(keyFifo.first());
      keyFifo.deq();
      
      let a = reg_a + key[0];
      let b = reg_b + key[1];
      let c = reg_c + key[2];
      
      //'ifdef DEBUG
      
      //'endif
      
      a = a-c;  a = a^rot(c, 4);  c = c+b;
      b = b-a;  b = b^rot(a, 6);  a = a+c; 
      c = c-b;  c = c^rot(b, 8);  b = b+a;
      a = a-c;  a = a^rot(c,16);  c = c+b;
      b = b-a;  b = b^rot(a,19);  a = a+c;
      c = c-b;  c = c^rot(b, 4);  b = b+a;
      
      $display("\x1b[32mHardware:: Mix_phase, a = %h, b = %h, c = %h\x1b[0m", a, b, c);
      reg_a <= a;
      reg_b <= b;
      reg_c <= c;
      keylen <= keylen - 12;
   endrule
   
   rule final_mix if (keylen <= 12 && keylen>0 && !idle);
      
      Vector#(3, Bit#(32)) k = unpack(keyFifo.first());
      keyFifo.deq();
      reg_c <= reg_c + k[2];
      reg_b <= reg_b + k[1];
      reg_a <= reg_a + k[0];
      $display("\x1b[32mHardware:: Final_mix, a = %h, b = %h, c = %h\x1b[0m", reg_a+k[0], reg_b+k[1], reg_c+k[2]);      
      /*
      switch(length)
      {
       case 12: c+=k[2]; b+=k[1]; a+=k[0]; break;
       case 11: c+=k[2]&0xffffff; b+=k[1]; a+=k[0]; break;
       case 10: c+=k[2]&0xffff; b+=k[1]; a+=k[0]; break;
       case 9 : c+=k[2]&0xff; b+=k[1]; a+=k[0]; break;
       case 8 : b+=k[1]; a+=k[0]; break;
       case 7 : b+=k[1]&0xffffff; a+=k[0]; break;
       case 6 : b+=k[1]&0xffff; a+=k[0]; break;
       case 5 : b+=k[1]&0xff; a+=k[0]; break;
       case 4 : a+=k[0]; break;
       case 3 : a+=k[0]&0xffffff; break;
       case 2 : a+=k[0]&0xffff; break;
       case 1 : a+=k[0]&0xff; break;
       case 0 : return c;  // zero length strings require no mixing 
       }
      */
          
      keylen <= 0;
      skip <= False;
   endrule
   
   rule final_phase (keylen == 0 && !idle);
      if (!skip)
         begin
            let a = reg_a;
            let b = reg_b;
            let c = reg_c;
            //$display("\x1b[32mHardware:: Final_phase, a = %h, b = %h, c = %h\x1b[0m", a, b, c);
            c = c^b; c = c-rot(b,14);
            a = a^c; a = a-rot(c,11);
            b = b^a; b = b-rot(a,25);
            c = c^b; c = c-rot(b,16);
            a = a^c; a = a-rot(c,4); 
            b = b^a; b = b-rot(a,14);
            c = c^b; c = c-rot(b,24);
            $display("\x1b[32mHardware:: Final_phase, a = %h, b = %h, c = %h\x1b[0m", a, b, c);
            hashFifo.enq(c);
         end
      else
         begin
            hashFifo.enq(reg_c);
         end
      
      //skip <= False;
      idle <= True;
      /*
      #define final(a,b,c) \
      { \
       c ^= b; c -= rot(b,14); \
       a ^= c; a -= rot(c,11); \
       b ^= a; b -= rot(a,25); \
       c ^= b; c -= rot(b,16); \
       a ^= c; a -= rot(c,4);  \
       b ^= a; b -= rot(a,14); \
       c ^= b; c -= rot(b,24); \
       }
       */

   endrule 
      
   
   method Action start(Bit#(32) length) if (idle);
      
      keylen <= length;
      reg_a <= 32'hdeadbeef + length;
      reg_b <= 32'hdeadbeef + length;
      reg_c <= 32'hdeadbeef + length;
      idle <= False;
      skip <= True;
      
   //   `ifdef DEBUG
 //     let a = 32'hdeadbeef + length;
      $display("\x1b[32mHardware:: Initalize_phase, a = %h, b = %h, c = %h\x1b[0m", 32'hdeadbeef + length , 32'hdeadbeef + length, 32'hdeadbeef + length);
     // `endif
   endmethod
   
   method Action putKey(Bit#(96) key);
      keyFifo.enq(key);
   endmethod
   
   method ActionValue#(Bit#(32)) getHash();
      hashFifo.deq();
      return hashFifo.first();
   endmethod
      
endmodule