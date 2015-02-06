import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import GetPut::*;
import Connectable::*;
//import Packet::*;
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
   
   //method Action putKeys(Bit#(64) v);
   //method ActionValue#(Bit#(96)) resp();
   interface Put#(Bit#(64)) request;
   interface Get#(Bit#(96)) response;
   interface Get#(Bit#(32)) lengthQ;
   
endinterface
   

interface FinalMixEngIfc;
   //method Action req(Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bool) v);
   //method ActionValue#(Bit#(32)) resp();
   //method Bit#(32) resp();
   interface Put#(Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bool)) request;
   interface Get#(Bit#(32)) response;
endinterface

typedef struct{
   Bool cont;
   Bit#(64) packet;
   } PacketType deriving (Bits, Eq);

   
interface SerializerIfc;
   interface Put#(PacketType) request;
   interface Get#(Bit#(96)) response;
endinterface

module mkSerializer(SerializerIfc);
   FIFO#(PacketType) inputFifo <- mkBypassFIFO;
   FIFO#(Bit#(96)) outputFifo <- mkBypassFIFO;
   //Bit#(8) inputPtr <- mkReg(16);
   Reg#(Bit#(8)) outputPtr <- mkReg(0);
   Reg#(Bit#(128)) buff <- mkReg(0);
   Reg#(Bool) last <- mkReg(False);
   rule doInput;
     
      if (!last) begin
         let v <- toGet(inputFifo).get;
         let word = v.packet;
         let cont = v.cont;
         if (outputPtr < 4) begin
            if (cont) begin
               buff <= truncate({buff, word});
               //            inputPtr <= inputPtr - 8;
               outputPtr <= outputPtr + 8;
            end
            else begin
               outputPtr <= 0;
               outputFifo.enq(zeroExtend(word));
            end
         end
         else begin
            if ( outputPtr == 8 && !cont ) begin
               last <= True;
            end
            
            outputPtr <= outputPtr - 4;
            if ( outputPtr == 8) begin
               Bit#(64) temp = truncate(buff);
               //outputFifo.enq(truncate({});
               outputFifo.enq(truncate({word,temp}));
               //$display("%h",word);
               buff <= zeroExtend(word>>32);
            end
            else begin
               Bit#(32) temp = truncate(buff);
               outputFifo.enq(truncate({word,temp}));
               buff <= 0;
            //let v <- toGet(inputFIFO);
            end
         end
      end
      else begin
         outputFifo.enq(truncate(buff));
         outputPtr <= 0;
         buff <= 0;
         last <= False;
      end


      
   endrule
   interface Put request = toPut(inputFifo); 
   interface Get response = toGet(outputFifo);


endmodule

module mkDataAlign(DataAlignIfc);
   FIFO#(Bit#(64)) keyFifo <- mkFIFO;

   Reg#(Bit#(32)) cnt <- mkReg(0);
   Reg#(Bit#(32)) maxByte <- mkReg(0);
   FIFOF#(Bit#(32)) byteQ <- mkFIFOF();
   FIFO#(Bit#(32)) lenQ <- mkSizedFIFO(32);
   
   let serializer <- mkSerializer;
   
   rule doAlign;

      Bit#(64) keyToken = ?;
      if ( maxByte > 0) begin
         keyToken <- toGet(keyFifo).get();
      end

      //$display("doAllign: cnt = %d, maxByte = %d, word = %d", cnt, maxByte, keyToken);
      if ( cnt + 8 >= maxByte) begin
         if (byteQ.notEmpty) begin
            maxByte <= byteQ.first();
            cnt <= 0;
            byteQ.deq();
         end
         else begin
            cnt <= 0;
            maxByte <= 0;
         end
         
         if (maxByte > 0) begin
            //$display("data aligner enqueing last word = %d", keyToken);
            serializer.request.put(PacketType{cont:False, packet: keyToken});
         end
      end
      else begin
         serializer.request.put(PacketType{cont:True, packet: keyToken});
         cnt <= cnt + 8;
      end
   endrule
      
   method Action start(Bit#(32) length);// if (nBytes <=0);
      lenQ.enq(length);
      //cnt <= 0;
      //nBytes <= unpack(length);
      byteQ.enq(length);
   /*
      $display("\x1b[32mHardware:: Initalize_phase, a = %h, b = %h, c = %h\x1b[0m", 32'hdeadbeef + length , 32'hdeadbeef + length, 32'hdeadbeef + length);
      if ( length[2:0] == 0 ) begin
         $display("\x1b[32mHardware:: nBytes = %d, burstLen = %d\x1b[0m", length, length>>3);
         burstLen <= truncate(length >> 3);
      end
      else begin
         $display("\x1b[32mHardware:: nBytes = %d, burstLen = %d\x1b[0m", length, (length>>3)+1);
         burstLen <= truncate(length >> 3) + 1;
      end*/
   endmethod

   interface Put request = toPut(keyFifo);
   interface Get response = serializer.response;//toGet(procFifo);
   
   interface Get lengthQ = toGet(lenQ);
   
endmodule

typedef struct{
   Bit#(32) a;
   Bit#(32) b;
   Bit#(32) c;
   Bit#(32) k0;
   Bit#(32) k1;
   Bit#(32) k2;
   Bit#(32) stageId;
   Bool doKey;
   Bool lastToken;
   Bool toFinal;
   } MixStageType deriving(Eq, Bits);

interface MixStageIfc;
   interface Put#(MixStageType) request;
   interface Get#(MixStageType) response;
endinterface

module mkMixStage#(Integer stage_id)(MixStageIfc);
   Reg#(Bit#(32)) reg_a <- mkReg(0);
   Reg#(Bit#(32)) reg_b <- mkReg(0);
   Reg#(Bit#(32)) reg_c <- mkReg(0);
   
/*   Reg#(Bit#(32)) reg_aa <- mkReg(0);
   Reg#(Bit#(32)) reg_bb <- mkReg(0);
   Reg#(Bit#(32)) reg_cc <- mkReg(0);*/
   
   Integer myStage = stage_id;
   
   FIFO#(MixStageType) inputFifo <- mkBypassFIFO;
   FIFO#(MixStageType) immediateFifo <- mkFIFO;
   FIFO#(MixStageType) outputFifo <- mkFIFO;

   
   rule mix_phase_0;// if (keylen > 12 && state == Phase0);
      let args  <- toGet(inputFifo).get();
      //let keys = tpl_1(v);
      //let keylen = tpl_2(v);
      //let cont = tpl_3(v);
      //Vector#(3, Bit#(32)) key = unpack(keys);
      
      if ( args.stageId == fromInteger(myStage)) begin
         if (args.doKey) begin
            if ( !args.toFinal ) begin
               //$display("\x1b[32mHardware:: Mix_phase, k[0] = %h, k[1] = %h, k[2] = %h\x1b[0m", args.k0, args.k1, args.k2);
               let a = reg_a + args.k0;
               let b = reg_b + args.k1;
               let c = reg_c + args.k2;
               
       
               a = a-c;  a = a^rot(c, 4);  c = c+b;
               b = b-a;  b = b^rot(a, 6);  a = a+c; 
               c = c-b;  c = c^rot(b, 8);  b = b+a;
               
               args.a = a;
               args.b = b;
               args.c = c;
               args.doKey = True;
            end
            else begin
               let c = reg_c + args.k2;
               let b = reg_b + args.k1;
               let a = reg_a + args.k0;
               args.a = a;
               args.b = b;
               args.c = c;
               //$display("\x1b[32mHardware:: Final_mix, a = %h, b = %h, c = %h\x1b[0m", a, b, c);      
               args.doKey = False;
            end
         end
         else begin
            reg_a <= args.a;
            reg_b <= args.b;
            reg_c <= args.c;
            args.doKey = False;            
         end
      end
         
      immediateFifo.enq(args);
   endrule
   
   rule mix_phase_1;// if (state == Phase1);
      let args <- toGet(immediateFifo).get();
      if (args.stageId == fromInteger(myStage)) begin
         if (args.doKey) begin
            let a = args.a;
            let b = args.b;
            let c = args.c;
            
            a = a-c;  a = a^rot(c,16);  c = c+b;
            b = b-a;  b = b^rot(a,19);  a = a+c;
            c = c-b;  c = c^rot(b, 4);  b = b+a;
      
            //$display("\x1b[32mHardware:: Mix_phase, a = %h, b = %h, c = %h\x1b[0m", a, b, c);
            
            args.a = a;
            args.b = b;
            args.c = c;
            args.stageId = fromInteger(myStage + 1);
            args.doKey = False;
         end
      end
      outputFifo.enq(args);
   endrule

 /*
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
   */
   
   /*method Action start(Bit#(32) length) if (state == Idle);
      keylen <= length;
      reg_a <= 32'hdeadbeef + length;
      reg_b <= 32'hdeadbeef + length;
      reg_c <= 32'hdeadbeef + length;
      
      state <= Phase0;
     
   endmethod*/
   
   /*method Action putKeys(Bit#(32) key_0, Bit#(32) key_1, Bit#(32) key_2);
      inputFifo.enq({key_2, key_1, key_0});
   endmethod
   method ActionValue#(Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bool)) resp();
      outputFifo.deq();
      return outputFifo.first();
   endmethod*/
   interface Put request = toPut(inputFifo);
   interface Get response = toGet(outputFifo);
endmodule

interface MixEngIfc;
   interface Put#(Bit#(32)) startQ;
   interface Put#(Bit#(96)) request;
   interface Get#(Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bool)) response;
endinterface

module mkMixEng(MixEngIfc);
   
   Vector#(22, MixStageIfc) mixStages;
   for ( Integer i = 0; i < 22; i = i + 1) begin
      mixStages[i] <- mkMixStage(i);
   end
   
   for (Integer i = 0; i < 21; i = i + 1) begin
      mkConnection(mixStages[i].response, mixStages[i+1].request);
   end
   
   Reg#(Bit#(16)) reqCnt <- mkReg(0);
   FIFO#(Tuple2#(Bit#(32), Bit#(16))) lenQ <- mkFIFO;
   Reg#(Bit#(32)) lenCnt <- mkReg(0);
   Reg#(Bit#(32)) stageCnt <- mkReg(0);
   
   FIFO#(Bit#(96)) keyFifo <- mkFIFO();
   FIFO#(Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bool)) outputFifo <- mkBypassFIFO();
   
   rule sendToPipe;
      let lenMax = tpl_1(lenQ.first());
      let keys <- toGet(keyFifo).get();
      Vector#(3, Bit#(32)) k = unpack(keys);
      $display("\x1b[32mJenkins[reqId = %d]:: Mix_phase, key0 = %h, key1 = %h, key2 = %h\x1b[0m", tpl_2(lenQ.first()), k[0] , k[1], k[2]);
      if ( lenCnt + 12 > lenMax) begin
         mixStages[0].request.put(MixStageType{k0:k[0], k1:k[1], k2:k[2], stageId: stageCnt, doKey: True, lastToken: True, toFinal: True});
         lenCnt <= 0;
         lenQ.deq();
         stageCnt <= 0;
      end
      else if (lenCnt + 12 == lenMax) begin
         mixStages[0].request.put(MixStageType{k0:k[0], k1:k[1], k2:k[2], stageId: stageCnt, doKey: True, lastToken: True, toFinal: False});
         lenCnt <= 0;
         lenQ.deq();
         stageCnt <= 0;
      end
      else begin
         mixStages[0].request.put(MixStageType{k0:k[0], k1:k[1], k2:k[2], stageId: stageCnt, doKey: True, lastToken: False});
         lenCnt <= lenCnt + 12;
         stageCnt <= stageCnt + 1;
      end
   endrule

   Reg#(Bit#(16)) reqCnt_2 <- mkReg(0);
   rule receiveFromPipe;
      let args <- mixStages[21].response.get;
      
      if (args.lastToken) begin
         reqCnt_2 <= reqCnt_2 + 1;
         $display("\x1b[32mJenkins[reqId = %d] mixEngs get result, stageId = %d, a = %h, b = %h, c = %h, toFinal = %b\x1b[0m", reqCnt_2, args.stageId, args.a, args.b, args.c, args.toFinal);
         outputFifo.enq(tuple4(args.a, args.b, args.c, !args.toFinal));
      end
   endrule
   
   interface Put startQ;
      method Action put(Bit#(32) length);
         reqCnt <= reqCnt + 1;
         $display("\x1b[32mJenkins[reqId = %d]:: Initalize_phase, a = %h, b = %h, c = %h\x1b[0m", reqCnt, 32'hdeadbeef + length , 32'hdeadbeef + length, 32'hdeadbeef + length);
         /*keylen <= length;
         reg_a <= 32'hdeadbeef + length;
         reg_b <= 32'hdeadbeef + length;
         reg_c <= 32'hdeadbeef + length;*/
         
         let init_val = 32'hdeadbeef + length;
         lenQ.enq(tuple2(length,reqCnt));
         mixStages[0].request.put(MixStageType{a: init_val, b: init_val, c: init_val, stageId: 0,  doKey: False, lastToken: False});
      endmethod
   endinterface
   
   interface Put request = toPut(keyFifo);
   interface Get response = toGet(outputFifo);
endmodule
   

module mkFinalMixEng(FinalMixEngIfc);
   Wire#(Bit#(32)) wire_a <- mkWire;
   Wire#(Bit#(32)) wire_b <- mkWire;
   Wire#(Bit#(32)) wire_c <- mkWire;
   Wire#(Bool) wire_skip <- mkWire;
   
   //Wire#(Bit#(32)) hVal <- mkWire;
   //FIFO#(Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bool)) finalFifo <- mkFIFO;
   
//   Wire#(Bool) poke <- mkWire;
   //FIFO#(Bit#(32)) outputFifo <- mkLFIFO;
   FIFO#(Bit#(32)) outputFifo <- mkFIFO;
   
   //FIFO#(Tuple5#(Bit#(32), Bit#(32), Bit#(32), Bool, Bit#(32))) finalFifo <- mkLFIFO;
   FIFO#(Tuple5#(Bit#(32), Bit#(32), Bit#(32), Bool, Bit#(32))) finalFifo <- mkFIFO;
   
   /*rule final_phase_0;
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
         //hVal <= c;
         outputFifo.enq(c);
      end
      else begin
         outputFifo.enq(wire_c);
         //hVal <= wire_c;
      end
   endrule*/
   
/*   rule final_phase_0;
      
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
      c = c^b; c = c-rot(b,24);
      $display("\x1b[32mHardware:: Final_phase, a = %h, b = %h, c = %h\x1b[0m", a, b, c);
      //hashFifo.enq(c);
      //end
      //else
      // begin
      //hashFifo.enq(reg_c);
      //end
      
      finalFifo.enq(tuple5(a, b, c, wire_skip, wire_c));
      
   endrule */
   
   Reg#(Bit#(16)) reqCnt <- mkReg(0);
   rule final_phase_1;
      let d = finalFifo.first;
      finalFifo.deq;
      
      let a = tpl_1(d);
      let b = tpl_2(d);
      let c = tpl_3(d);
      let flag = tpl_4(d);
      let old_c = tpl_5(d);
      
      reqCnt <= reqCnt + 1;
      $display("\x1b[32mJenkins[reqId = %d]:: Final_phase, a = %h, b = %h, c = %h, old_c = %h, flag = %b\x1b[0m", reqCnt, a, b, c, old_c, flag);

      if (!flag) begin
         c = c^b; c = c-rot(b,16);
         a = a^c; a = a-rot(c,4); 
         b = b^a; b = b-rot(a,14);
         c = c^b; c = c-rot(b,24);
         outputFifo.enq(c);
      end
      else
         outputFifo.enq(old_c);
      
   
   endrule

   /*method Action req(Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bool) v);
      wire_a <= tpl_1(v);
      wire_b <= tpl_2(v);
      wire_c <= tpl_3(v);
      wire_skip <= tpl_4(v);
//      poke <= True;
   endmethod*/
   /*method Bit#(32) resp();
//      outputFifo.deq();
      return hVal;// outputFifo.first();
   endmethod*/
   
   interface Put request;
      method Action put(Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bool) v);
/*         wire_a <= tpl_1(v);
         wire_b <= tpl_2(v);
         wire_c <= tpl_3(v);
         wire_skip <= tpl_4(v);*/
         let a = tpl_1(v);
         let b = tpl_2(v);
         let c = tpl_3(v);
         let skip = tpl_4(v);
         //$display("\x1b[32mHardware:: Final_phase, a = %h, b = %h, c = %h\x1b[0m", a, b, c);
         c = c^b; c = c-rot(b,14);
         a = a^c; a = a-rot(c,11);
         b = b^a; b = b-rot(a,25);
      
         finalFifo.enq(tuple5(a, b, c, skip, tpl_3(v)));
//      poke <= True;
      endmethod
   endinterface
   interface Get response = toGet(outputFifo);
endmodule
         
//(*synthesize*)
module mkJenkinsHash (JenkinsHashIfc);
   
   //FIFO#(Bit#(32)) hashFifo <- mkFIFO;
   
   let dataAlign <- mkDataAlign;
   let mixEng <- mkMixEng;
   let final_mixEng <- mkFinalMixEng;
   
   mkConnection(dataAlign.lengthQ, mixEng.startQ);
   mkConnection(dataAlign.response, mixEng.request);
   mkConnection(mixEng.response, final_mixEng.request);

   Reg#(Bit#(16)) respCnt <- mkReg(0);
   method Action start(Bit#(32) length);
      dataAlign.start(length);
      //mixEng.start(length);
   endmethod 
 
   method Action putKey(Bit#(64) key);
      dataAlign.request.put(key);
   endmethod

   
   method ActionValue#(Bit#(32)) getHash();
      respCnt <= respCnt + 1;
      let v <- final_mixEng.response.get();
      $display("Jenkins got hash, reqId = %d, hash = %h", respCnt, v);
      return v;
   endmethod
      
endmodule
