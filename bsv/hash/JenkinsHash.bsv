import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import GetPut::*;
import Connectable::*;
import SerDes::*;
//import Packet::*;
//`define DEBUG

//`ifdef Debug
//Bool debug = True;
//`else
Bool debug = False;
//`endif


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
   interface Put#(Bit#(64)) request;
   interface Get#(Bit#(96)) response;
   interface Get#(Bit#(32)) lengthQ;
endinterface
   

interface FinalMixEngIfc;
   interface Put#(Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bool)) request;
   interface Get#(Bit#(32)) response;
endinterface

module mkDataAlign(DataAlignIfc);
   FIFO#(Bit#(64)) keyFifo <- mkFIFO;

   Reg#(Bit#(32)) cnt <- mkReg(0);
   Reg#(Bit#(32)) maxByte <- mkReg(0);
   FIFOF#(Bit#(32)) byteQ <- mkFIFOF();
   FIFO#(Bit#(32)) lenQ <- mkSizedFIFO(32);
   
   DeserializerIfc#(64,192, Bit#(0)) des <- mkDeserializer();
   
   mkConnection(des.demarshall, toGet(keyFifo));
   
   Reg#(Bit#(32)) tokenCnt <- mkReg(0);
   FIFO#(Bit#(32)) tokenMaxQ <- mkFIFO();
   rule doDes;
      let tokenMax = tokenMaxQ.first();
      
      if ( tokenCnt + 3 < tokenMax) begin
         des.request(3, ?);
         tokenCnt <= tokenCnt + 3;
      end
      else begin
         des.request(truncate(tokenMax-tokenCnt),?);
         tokenCnt <= 0;
         tokenMaxQ.deq();
      end
   endrule
   
   SerializerIfc#(192, 96, Bit#(0)) ser <- mkSerializer();
   Reg#(Bit#(32)) byteCnt <- mkReg(0);
   FIFO#(Bit#(32)) byteMaxQ <- mkFIFO();
   rule doSer;
      let byteMax = byteMaxQ.first();
      let v <- des.getVal;
      let d = tpl_1(v);
      if (debug) $display("Got d = %h", d);
      if (byteCnt + 24 < byteMax) begin
         ser.marshall(d, 2,?);
         byteCnt <= byteCnt + 24;
      end
      else begin
         if ((byteMax - byteCnt) > 12)
            ser.marshall(d, 2,?);
         else
            ser.marshall(d, 1,?);
         byteCnt <= 0;
         byteMaxQ.deq();
      end
   endrule
      
      
   method Action start(Bit#(32) length);
      Bit#(32) tokenMax = length >> 3;
      if ( length[2:0] != 0)
         tokenMax = tokenMax + 1;
      tokenMaxQ.enq(tokenMax);
      lenQ.enq(length);
        byteMaxQ.enq(length);
   endmethod

   interface Put request = toPut(keyFifo);
   interface Get response;
      method ActionValue#(Bit#(96)) get();
         let v <- ser.getVal;
         return tpl_1(v);
      endmethod
   endinterface
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
   
   Integer myStage = stage_id;
   
   //FIFO#(MixStageType) inputFifo <- mkBypassFIFO;
   FIFO#(MixStageType) immediateFifo <- mkFIFO;
   FIFO#(MixStageType) outputFifo <- mkFIFO;
   
   rule mix_phase_1;
      let args <- toGet(immediateFifo).get();
      if (!args.toFinal) begin
         if (args.stageId == fromInteger(myStage)) begin
            let a = args.a;
            let b = args.b;
            let c = args.c;
            
            a = a-c;  a = a^rot(c,16);  c = c+b;
            b = b-a;  b = b^rot(a,19);  a = a+c;
            c = c-b;  c = c^rot(b, 4);  b = b+a;
         
         
            args.a = a;
            args.b = b;
            args.c = c;
            
            reg_a <= args.a;
            reg_b <= args.b;
            reg_c <= args.c;
         end
      end

      if (args.stageId == fromInteger(myStage+1)) begin
         args.a = reg_a;
         args.b = reg_b;
         args.c = reg_c;
      end
      
      outputFifo.enq(args);
   endrule

   interface Put request;// = toPut(inputFifo);
      method Action put(MixStageType args);
          if ( args.stageId == fromInteger(myStage)) begin
             if ( !args.toFinal ) begin
                if (debug) $display("\x1b[32mHardware:: Mix_phase[%d], a = %h, b = %h, k[2] = %h\x1b[0m", myStage, args.a, args.b, args.c);
                if (debug) $display("\x1b[32mHardware:: Mix_phase[%d], k[0] = %h, k[1] = %h, k[2] = %h\x1b[0m", myStage, args.k0, args.k1, args.k2);
           
                let a = args.a + args.k0;
                let b = args.b + args.k1;
                let c = args.c + args.k2;
               
                
                a = a-c;  a = a^rot(c, 4);  c = c+b;
                b = b-a;  b = b^rot(a, 6);  a = a+c; 
                c = c-b;  c = c^rot(b, 8);  b = b+a;
                
                args.a = a;
                args.b = b;
                args.c = c;
                /*if (debug) $display("\x1b[32mHardware:: Mix_phase[%d], a = %h, b = %h, k[2] = %h\x1b[0m", myStage, args.a, args.b, args.c);
                if (debug) $display("\x1b[32mHardware:: Mix_phase[%d], k[0] = %h, k[1] = %h, k[2] = %h\x1b[0m", myStage, args.k0, args.k1, args.k2);*/
             end
             else begin
                let c = args.c + args.k2;
                let b = args.b + args.k1;
                let a = args.a + args.k0;
                args.a = a;
                args.b = b;
                args.c = c;
                if (debug) $display("\x1b[32mHardware:: Final_mix[%d], a = %h, b = %h, c = %h\x1b[0m", myStage, a, b, c);      
                if (debug) $display("\x1b[32mHardware:: Final_mix[%d], k[0] = %h, k[1] = %h, k[2] = %h\x1b[0m", myStage, args.k0, args.k1, args.k2);

             end
          end
         immediateFifo.enq(args);
      endmethod
   endinterface
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
      Bit#(32) init = 32'hdeadbeef + lenMax;
      Vector#(3, Bit#(32)) k = unpack(keys);
      if (debug) $display("\x1b[32mJenkins[reqId = %d]:: Mix_phase, key0 = %h, key1 = %h, key2 = %h\x1b[0m", tpl_2(lenQ.first()), k[0] , k[1], k[2]);
      if ( lenCnt + 12 >= lenMax) begin
         mixStages[0].request.put(MixStageType{a:init, b:init, c:init, k0:k[0], k1:k[1], k2:k[2], stageId: stageCnt, toFinal: True});
         lenCnt <= 0;
         lenQ.deq();
         stageCnt <= 0;
      end
      else begin
         mixStages[0].request.put(MixStageType{a:init, b:init, c:init, k0:k[0], k1:k[1], k2:k[2], stageId: stageCnt, toFinal: False});
         lenCnt <= lenCnt + 12;
         stageCnt <= stageCnt + 1;
      end
      
   endrule

   Reg#(Bit#(16)) reqCnt_2 <- mkReg(0);
   rule receiveFromPipe;
      let args <- mixStages[21].response.get;
      if (args.toFinal) begin
         reqCnt_2 <= reqCnt_2 + 1;
         if (debug) $display("\x1b[32mJenkins[reqId = %d] mixEngs get result, stageId = %d, a = %h, b = %h, c = %h, toFinal = %b\x1b[0m", reqCnt_2, args.stageId, args.a, args.b, args.c, args.toFinal);
         outputFifo.enq(tuple4(args.a, args.b, args.c, !args.toFinal));
      end
   endrule
   
   interface Put startQ;
      method Action put(Bit#(32) length);
         reqCnt <= reqCnt + 1;
         lenQ.enq(tuple2(length,reqCnt));
      endmethod
   endinterface
   
   interface Put request = toPut(keyFifo);
   interface Get response = toGet(outputFifo);
endmodule
   

module mkFinalMixEng(FinalMixEngIfc);
   
   FIFO#(Bit#(32)) outputFifo <- mkFIFO;
   
   FIFO#(Tuple5#(Bit#(32), Bit#(32), Bit#(32), Bool, Bit#(32))) finalFifo <- mkFIFO;
   
   
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
      if (debug) $display("\x1b[32mJenkins[reqId = %d]:: Final_phase, a = %h, b = %h, c = %h, old_c = %h, flag = %b\x1b[0m", reqCnt, a, b, c, old_c, flag);

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
   
   interface Put request;
      method Action put(Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bool) v);
         let a = tpl_1(v);
         let b = tpl_2(v);
         let c = tpl_3(v);
         let skip = tpl_4(v);
         //if (debug) $display("\x1b[32mHardware:: Final_phase, a = %h, b = %h, c = %h\x1b[0m", a, b, c);
         c = c^b; c = c-rot(b,14);
         a = a^c; a = a-rot(c,11);
         b = b^a; b = b-rot(a,25);
      
         finalFifo.enq(tuple5(a, b, c, skip, tpl_3(v)));
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
      if (debug) $display("Jenkins got hash, reqId = %d, hash = %h", respCnt, v);
      return v;
   endmethod
      
endmodule

interface MixStageIfc_192;
   interface Put#(Vector#(2, MixStageType)) request;
   interface Get#(Vector#(2, MixStageType)) response;
endinterface

module mkMixStage_192#(Integer stageId)(MixStageIfc_192);
   let mixEng0 <- mkMixStage(2*stageId);
   let mixEng1 <- mkMixStage(2*stageId+1);
   
   FIFO#(Vector#(2, MixStageType)) inputFIFO <- mkFIFO();
   FIFO#(Vector#(2, MixStageType)) outputFIFO <- mkFIFO();
   
   Vector#(2, FIFO#(MixStageType)) stageInQs <- replicateM(mkSizedFIFO(3));
   
   Vector#(3, Reg#(Bit#(32))) regV <- replicateM(mkRegU());
   
   rule doStage_2;
      let v <- toGet(stageInQs[0]).get();
      
      let d <- mixEng0.response.get();
      
      v.a = d.a;
      v.b = d.b;
      v.c = d.c;
      
      mixEng1.request.put(v);
      
      stageInQs[1].enq(d);
   endrule
   
   interface Put request;
      method Action put(Vector#(2, MixStageType) v);
         mixEng0.request.put(v[0]);
         stageInQs[0].enq(v[1]);
      endmethod
   endinterface
   interface Get response;
      method ActionValue#(Vector#(2, MixStageType)) get;
         let d <- mixEng1.response.get();
         let v <- toGet(stageInQs[1]).get();
         
         v.a = d.a;
         v.b = d.b;
         v.c = d.c;
   
         //if (debug) $display("StageId = %d, %d,%d", stageId, v.stageId, d.stageId);
         if (v.stageId == fromInteger(2*stageId + 2)) begin
            //if (debug) $display("You suck");
            v.a = regV[0];
            v.b = regV[1];
            v.c = regV[2];
         end
   
         regV[0] <= d.a;
         regV[1] <= d.b;
         regV[2] <= d.c;
         
         Vector#(2, MixStageType) retval;
         retval[0] = v;
         retval[1] = d;
      
         return retval;
      endmethod 
   endinterface
endmodule


interface MixEngIfc_192;
   interface Put#(Bit#(32)) startQ;
   interface Put#(Bit#(192)) request;
   interface Get#(Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bool)) response;
   method Action seed(Bit#(32) v);
endinterface


module mkMixEng_192(MixEngIfc_192);
   
   Vector#(22, MixStageIfc_192) mixStages;
   for ( Integer i = 0; i < 11; i = i + 1) begin
      mixStages[i] <- mkMixStage_192(i);
   end
   
   for (Integer i = 0; i < 10; i = i + 1) begin
      mkConnection(mixStages[i].response, mixStages[i+1].request);
   end
   
   Reg#(Bit#(16)) reqCnt <- mkReg(0);
   FIFO#(Tuple2#(Bit#(32), Bit#(16))) lenQ <- mkFIFO;
   Reg#(Bit#(32)) lenCnt <- mkReg(0);
   Reg#(Bit#(32)) stageCnt <- mkReg(0);
   
   FIFO#(Bit#(192)) keyFifo <- mkFIFO();
   FIFO#(Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bool)) outputFifo <- mkBypassFIFO();
   
   Reg#(Bit#(32)) seedReg <- mkReg(32'hdeadbeef);
   
   rule sendToPipe;
      let lenMax = tpl_1(lenQ.first());
      let keys <- toGet(keyFifo).get();
      //Bit#(32) init = 32'hdeadbeef + lenMax;
      Bit#(32) init = seedReg + lenMax;
      Vector#(6, Bit#(32)) k = unpack(keys);
      
      Vector#(2, MixStageType) args;
      args[0] = MixStageType{a:init, b:init, c:init, k0:k[0], k1:k[1], k2:k[2], stageId: stageCnt, toFinal: False};
      args[1] = MixStageType{a:init, b:init, c:init, k0:k[3], k1:k[4], k2:k[5], stageId: stageCnt + 1, toFinal: False};
      
      if ( lenCnt + 24 >= lenMax) begin
         
         if ( lenMax - lenCnt > 12 ) begin
            args[1].toFinal = True;
         end
         else begin
            args[0].toFinal = True;
            args[1].toFinal = False;
            args[1].stageId = -1;
         end
         lenCnt <= 0;
         lenQ.deq();
         stageCnt <= 0;
      end
      else begin
         lenCnt <= lenCnt + 24;
         stageCnt <= stageCnt + 2;
      end
      
      mixStages[0].request.put(args);
   endrule

   Reg#(Bit#(16)) reqCnt_2 <- mkReg(0);
   rule receiveFromPipe;
      let args <- mixStages[10].response.get;
      if (args[0].toFinal || args[1].toFinal) begin
         reqCnt_2 <= reqCnt_2 + 1;
         //if (debug) $display("\x1b[32mJenkins[reqId = %d] mixEngs get result, stageId = %d, a = %h, b = %h, c = %h, toFinal = %b\x1b[0m", reqCnt_2, args.stageId, args.a, args.b, args.c, args.toFinal);
         outputFifo.enq(tuple4(args[1].a, args[1].b, args[1].c, False));
      end
   endrule
   
   interface Put startQ;
      method Action put(Bit#(32) length);
         reqCnt <= reqCnt + 1;
         lenQ.enq(tuple2(length,reqCnt));
      endmethod
   endinterface
   
   interface Put request = toPut(keyFifo);
   interface Get response = toGet(outputFifo);
   method Action seed(Bit#(32) v);
      seedReg <= v;
   endmethod
endmodule


interface DataAlign_192_Ifc;
   method Action start(Bit#(32) length);
   interface Put#(Bit#(128)) request;
   interface Get#(Bit#(192)) response;
   interface Get#(Bit#(32)) lengthQ;
endinterface

module mkDataAlign_192(DataAlign_192_Ifc);
   FIFO#(Bit#(128)) keyFifo <- mkSizedFIFO(4);

   Reg#(Bit#(32)) cnt <- mkReg(0);
   Reg#(Bit#(32)) maxByte <- mkReg(0);
   FIFOF#(Bit#(32)) byteQ <- mkFIFOF();
   FIFO#(Bit#(32)) lenQ <- mkSizedFIFO(32);
   
   DeserializerIfc#(128,384, Bit#(0)) des <- mkDeserializer();
   
   mkConnection(des.demarshall, toGet(keyFifo));
   
   Reg#(Bit#(32)) tokenCnt <- mkReg(0);
   FIFO#(Bit#(32)) tokenMaxQ <- mkFIFO();
   rule doDes;
      let tokenMax = tokenMaxQ.first();
      
      if ( tokenCnt + 3 < tokenMax) begin
         des.request(3, ?);
         tokenCnt <= tokenCnt + 3;
      end
      else begin
         des.request(truncate(tokenMax-tokenCnt),?);
         tokenCnt <= 0;
         tokenMaxQ.deq();
      end
   endrule
   
   SerializerIfc#(384, 192, Bit#(0)) ser <- mkSerializer();
   Reg#(Bit#(32)) byteCnt <- mkReg(0);
   FIFO#(Bit#(32)) byteMaxQ <- mkFIFO();
   rule doSer;
      let byteMax = byteMaxQ.first();
      let v <- des.getVal;
      let d = tpl_1(v);
      if (debug) $display("Got d = %h", d);
      if (byteCnt + 48 < byteMax) begin
         ser.marshall(d, 2,?);
         byteCnt <= byteCnt + 48;
      end
      else begin
         if ((byteMax - byteCnt) > 24)
            ser.marshall(d, 2,?);
         else
            ser.marshall(d, 1,?);
         byteCnt <= 0;
         byteMaxQ.deq();
      end
   endrule
      
      
   method Action start(Bit#(32) length);
      Bit#(32) tokenMax = length >> 4;
      if ( length[3:0] != 0)
         tokenMax = tokenMax + 1;
      tokenMaxQ.enq(tokenMax);
      lenQ.enq(length);
      byteMaxQ.enq(length);
   endmethod

   interface Put request = toPut(keyFifo);
   interface Get response;
      method ActionValue#(Bit#(192)) get();
         let v <- ser.getVal;
         //if (debug) $display("here");
         return tpl_1(v);
      endmethod
   endinterface
   interface Get lengthQ = toGet(lenQ);
   
endmodule

interface JenkinsHash_128_Ifc;
   method Action start(Bit#(32) length);
   //method Action putKey(Bit#(128) key);
   interface Put#(Bit#(128)) inPipe;
   //method ActionValue#(Bit#(32)) getHash();
   interface Get#(Bit#(32)) response;
   method Action seed(Bit#(32) v);
endinterface

(*synthesize*)
module mkJenkinsHash_128(JenkinsHash_128_Ifc);
      
   let dataAlign <- mkDataAlign_192;
   let mixEng <- mkMixEng_192;
   let final_mixEng <- mkFinalMixEng;
   
   mkConnection(dataAlign.lengthQ, mixEng.startQ);
   mkConnection(dataAlign.response, mixEng.request);
   mkConnection(mixEng.response, final_mixEng.request);

   Reg#(Bit#(16)) respCnt <- mkReg(0);
   method Action start(Bit#(32) length);
      dataAlign.start(length);
   endmethod 
 
   interface Put inPipe = dataAlign.request;
   interface Get response = final_mixEng.response;
   
   method Action seed(Bit#(32) v);
      mixEng.seed(v);
   endmethod
endmodule
