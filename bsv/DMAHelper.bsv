import GetPut::*;
import ClientServer::*;
import ClientServerHelper::*;
import Connectable::*;

import MemTypes::*;
import MemreadEngine::*;
import MemwriteEngine::*;

import ParameterTypes::*;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;

typedef struct{
   Bit#(32) base;
   Bit#(32) numBursts;
   Bit#(32) lastBurstSz;
   Bit#(32) buffPtr;
} DMAReq deriving (Bits, Eq);
   

interface DMAReadIfc;
   interface Server#(Tuple3#(Bit#(32), Bit#(32), Bit#(64)), Bool) server;
   interface Client#(MemengineCmd,Bool) dmaClient;
   /*interface Put#(Bit#(128)) inPipe;
   interface Get#(Bit#(128)) outPipe;*/
endinterface

interface DMAWriteIfc;
   interface Server#(Tuple3#(Bit#(32), Bit#(32), Bit#(64)), Bool) server;
   interface Client#(MemengineCmd,Bool) dmaClient;
endinterface

(*synthesize*)
module mkDMAReader(DMAReadIfc);
   
   Reg#(Bit#(32)) burstCnt <- mkReg(0);
 
   FIFO#(MemengineCmd) dmaReqQ <- mkFIFO();
   FIFO#(Bool) dmaRespQ <- mkFIFO;
   Reg#(Bit#(32)) respCnt <- mkReg(0);
   FIFO#(Bit#(32)) respMaxQ <- mkSizedFIFO(128);
   
   FIFO#(DMAReq) reqQ <- mkSizedFIFO(128);
   FIFO#(Bool) doneQ <- mkFIFO();
   
   //FIFO#(Bit#(128)) inQ <- mkFIFO();
   //FIFO#(Bit#(128)) outQ <- mkFIFO();
  
   rule drive_read;

      let args = reqQ.first();
      let buffPtr = args.buffPtr;
      let lastBurstSz = args.lastBurstSz;
      let numBursts = args.numBursts;
      let base = args.base;
      $display("drRdRq: base = %d, burstCnt = %d, numBursts = %d, lastBurstSz = %d", base, burstCnt, numBursts, lastBurstSz);
      if ( burstCnt + 1 == numBursts ) begin
         dmaReqQ.enq(MemengineCmd{sglId:buffPtr, base:extend(base+(burstCnt<<7)), len:truncate(lastBurstSz), burstLen:truncate(lastBurstSz)});
         reqQ.deq();
         burstCnt <= 0;
      end
      else begin
         //$display("Normal request");
         dmaReqQ.enq(MemengineCmd{sglId:buffPtr, base:extend(base+(burstCnt<<7)), len:128, burstLen:128});
         burstCnt <= burstCnt + 1;
      end
   endrule

   rule finish_fifo;
      let rv1 <- toGet(dmaRespQ).get();
      let respMax = respMaxQ.first();
      if (respCnt + 1 == respMax) begin
         respMaxQ.deq();
         doneQ.enq(True);
         respCnt <= 0;
      end
      else begin
         respCnt <= respCnt + 1;
      end
   endrule
   
   /*Reg#(Bit#(32)) byteCnt <- mkReg(0);
   FIFO#(Tuple2#(Bit#(32),Bit#(32))) byteMaxQ <- mkSizedFIFO(16);
   rule filter_data;
      let byteMax = tpl_1(byteMaxQ.first());
      let numBytes = tpl_2(byteMaxQ.first());
      let d <- toGet(inQ).get();
      
      $display("DMA Reader Getting Data %h, byteCnt = %d", d, byteCnt);
      
      if ( byteCnt < numBytes)
         outQ.enq(d);
      
      if (byteCnt + 16 == byteMax) begin
         byteMaxQ.deq();
         byteCnt <= 0;
      end
      else begin
         byteCnt <= byteCnt + 16;
      end
   endrule*/
   
   interface Server server;
      interface Put request;
         method Action put(Tuple3#(Bit#(32), Bit#(32), Bit#(64)) v);
            let rp = tpl_1(v);
            let base = tpl_2(v);
            let nBytes = tpl_3(v);
            $display("DMAHelper read request, rp = %d, base = %d, nBytes = %d",rp, base, nBytes);
            Bit#(32) numBursts = truncate(nBytes >> 7);
           
            Bit#(32) lastBurstSz;
            Bit#(32) buffPtr;
            if ( nBytes[3:0] == 0 )
               lastBurstSz = extend(nBytes[6:0]);
            else
               lastBurstSz = (extend(nBytes[6:4])+1)<<4;
      
            if ( nBytes[6:0] != 0) begin
               numBursts = numBursts + 1;
            end
            else begin
               lastBurstSz = 128;
            end
      
            buffPtr = rp;
   
            //lastBurstSz = 128;
   
            //byteMaxQ.enq(tuple2(numBursts << 7, truncate(nBytes)));
         
            if ( base[6:0] != 0 ) begin
               $display("base is not word aligned");
               $finish();
            end
      
            reqQ.enq(DMAReq{numBursts: numBursts, lastBurstSz: lastBurstSz, buffPtr: buffPtr, base: base});
            respMaxQ.enq(numBursts);
         endmethod
      endinterface
      interface Get response = toGet(doneQ);
   endinterface
   
   /*interface Put inPipe = toPut(inQ);
   interface Get outPipe = toGet(outQ);*/


   interface Client dmaClient = toClient(dmaReqQ, dmaRespQ);
   
endmodule

(*synthesize*)
module mkDMAWriter(DMAWriteIfc);
   Reg#(Bit#(32)) burstCnt <- mkReg(0);
   
   Reg#(Bit#(32)) burstIterCnt <- mkReg(0);
  
   FIFO#(Bool) doneQ <- mkFIFO;
   
   FIFO#(MemengineCmd) dmaReqQ <- mkFIFO;
   FIFO#(Bool) dmaRespQ <- mkFIFO;
   
      
   FIFO#(Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bit#(32))) cmdQ <- mkSizedFIFO(numStages);
   FIFO#(Bit#(32)) numOfRespQ <- mkSizedFIFO(numStages);
   
   rule drive_write;
      let v = cmdQ.first;
      let buffPtr = tpl_1(v);
      let numBursts = tpl_2(v);
      let lastBurstSz = tpl_3(v);
      let base = tpl_4(v);
      
      $display("drWrRq: base = %d, burstCnt = %d, numBursts = %d, lastBurstSz", base, burstCnt, numBursts, lastBurstSz);
      if ( burstCnt +1 == numBursts ) begin
         $display("Last request");
         dmaReqQ.enq(MemengineCmd{sglId:buffPtr, base:extend(base+(burstCnt<<7)), len:truncate(lastBurstSz), burstLen:truncate(lastBurstSz)});
         burstCnt <= 0;
         cmdQ.deq();
      end
      else if ( burstCnt + 1 < numBursts) begin
         $display("Normal request");
         dmaReqQ.enq(MemengineCmd{sglId:buffPtr, base:extend(base+(burstCnt<<7)), len:128, burstLen:128});
         burstCnt <= burstCnt + 1;
      end
            
   endrule
   
   
   rule write_finish;
      let numOfResp = numOfRespQ.first();
      $display("write_finish %d, %d", burstIterCnt, numOfResp);
      //if ( numOfResp > 0) 
      let v <- toGet(dmaRespQ).get();
      if ( burstIterCnt + 1 < numOfResp) begin
         burstIterCnt <= burstIterCnt + 1;
      end
      else  begin
         doneQ.enq(True);
         burstIterCnt <= 0;
         numOfRespQ.deq();
      end
   endrule
   
   
   interface Server server;
      interface Put request;
         method Action put(Tuple3#(Bit#(32), Bit#(32), Bit#(64)) v);
            let wp = tpl_1(v);
            let base = tpl_2(v);
            let nBytes = tpl_3(v);
            
            $display("DMAHelper write request, wp = %d, base = %d, nBytes = %d", wp, base, nBytes);

   
            Bit#(32) numBursts = truncate(nBytes >> 7);
           
            Bit#(32) lastBurstSz;
            if ( nBytes[3:0] == 0 )
               lastBurstSz = extend(nBytes[6:0]);
            else
               lastBurstSz = (extend(nBytes[6:4])+1)<<4;
               
            if ( nBytes[6:0] != 0) begin
               numBursts = numBursts + 1;
            end
            else begin
               lastBurstSz = 128;
            end
      
            if ( base[6:0] != 0 ) begin
               $display("base is not word aligned");
               $finish();
            end
            cmdQ.enq(tuple4(wp, numBursts, lastBurstSz, base));
            numOfRespQ.enq(numBursts);
         endmethod
      endinterface
      interface Get response = toGet(doneQ);
   endinterface

   interface Client dmaClient = toClient(dmaReqQ, dmaRespQ);
endmodule
