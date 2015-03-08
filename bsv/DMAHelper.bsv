import GetPut::*;
import ClientServer::*;
import Connectable::*;

import PortalMemory::*;
import MemTypes::*;
import MemreadEngine::*;
import MemwriteEngine::*;
import Pipe::*;
import IlaWrapper::*;

import ParameterTypes::*;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;

typedef struct{
   Bit#(32) numBursts;
   Bit#(32) lastBurstSz;
   Bit#(32) buffPtr;
} DMAReq deriving (Bits, Eq);
   

interface DMAReadIfc;
   method Action readReq(Bit#(32) rp, Bit#(64) nBytes);
   //method ActionValue#(Bit#(64)) readVal();
   interface Get#(Bit#(64)) response;
endinterface

interface DMAWriteIfc;
   method Action writeReq(Bit#(32) wp, Bit#(64) nBytes);
//   method Action writeVal(Bit#(64) dta);
   interface Put#(Bit#(64)) request;
   method Action done();
endinterface

module mkDMAReader#(Server#(MemengineCmd,Bool) rServer,
                    PipeOut#(Bit#(64)) rPipe,
                    DebugDMA dmaDebug
                    )(DMAReadIfc);


   Reg#(Bit#(32)) burstCnt <- mkReg(0);
   /*
   Reg#(Bit#(32)) numBursts <- mkRegU();
   Reg#(Bit#(32)) lastBurstSz <- mkRegU();
   Reg#(Bit#(32)) buffPtr <- mkRegU();
   
   Reg#(Bool) busy <- mkReg(False);
   
   Reg#(Bit#(32)) burstIterCnt <- mkRegU();
   Reg#(Bit#(32)) numOfResp <- mkRegU();*/

   FIFO#(Bit#(64)) respDtaQ <- mkFIFO;
   
   FIFO#(MemengineCmd) serverReqFifo <- mkFIFO;
   
   mkConnection(toGet(serverReqFifo), rServer.request);
   
   FIFO#(DMAReq) reqQ <- mkFIFO();
   
   rule drive_read;// if (busy && burstCnt <= numBursts);
      //$display("drRdRq: burstCnt = %d, numBursts = %d", burstCnt, numBursts);
      let args = reqQ.first();
      let buffPtr = args.buffPtr;
      let lastBurstSz = args.lastBurstSz;
      let numBursts = args.numBursts;
      if ( burstCnt == numBursts ) begin
         if ( lastBurstSz != 0) begin
            //$display("Last request");
            //rServer.request.put(MemengineCmd{sglId:buffPtr, base:extend(burstCnt<<7), len:truncate(lastBurstSz), burstLen:truncate(lastBurstSz)});
            serverReqFifo.enq(MemengineCmd{sglId:buffPtr, base:extend(burstCnt<<7), len:truncate(lastBurstSz), burstLen:truncate(lastBurstSz)});
         end
         reqQ.deq();
         burstCnt <= 0;
      end
      else begin
         //$display("Normal request");
        // rServer.request.put(MemengineCmd{sglId:buffPtr, base:extend(burstCnt<<7), len:128, burstLen:128});
         serverReqFifo.enq(MemengineCmd{sglId:buffPtr, base:extend(burstCnt<<7), len:128, burstLen:128});
         burstCnt <= burstCnt + 1;
      end
   endrule

   FIFO#(Bool) finishFIFO <- mkFIFO;
   rule finish_fifo;
      let rv1 <- rServer.response.get;
      //finishFIFO.enq(True);
   endrule
   
/*   rule read_finish if (busy);
      //$display("read_finish %d", burstIterCnt, numOfResp);
      if ( burstIterCnt < numOfResp) begin
         //let rv0 <- rServer.response.get;
         let v <- toGet(finishFIFO).get();
      end
      else if ( burstIterCnt == numOfResp) begin
         busy <= False;
      end
      
      burstIterCnt <= burstIterCnt + 1;
   endrule*/
   
   rule read_Val;
      let v <- toGet(rPipe).get;
      //$display("DMA reader get val = %h", v);
      dmaDebug.setData(v);
      respDtaQ.enq(v); 
   endrule
   
   method Action readReq(Bit#(32) rp, Bit#(64) nBytes);// if (!busy);
      dmaDebug.setAddr(rp);
      dmaDebug.setBytes(nBytes);
   
      //burstCnt <= 0;
      Bit#(32) numBursts = truncate(nBytes >> 7);
      Bit#(32) lastBurstSz;
      Bit#(32) buffPtr;
      if ( nBytes[2:0] == 0 )
         lastBurstSz = extend(nBytes[6:0]);
      else
         lastBurstSz = extend(nBytes[6:3]+1)<<3;
   
      buffPtr = rp;
      //busy <= True;
      
      /*burstIterCnt <= 0;
      if (nBytes[6:0] == 0 )
         numOfResp <= truncate(nBytes >> 7);
      else
         numOfResp <= truncate(nBytes >> 7) + 1;
      */
   
      reqQ.enq(DMAReq{numBursts: numBursts, lastBurstSz: lastBurstSz, buffPtr: buffPtr});
   endmethod
   
/*   method ActionValue#(Bit#(64)) readVal();
      v <- toGet(respDtaQ).get();
      return v;
   endmethod*/
   interface Get response = toGet(respDtaQ);
endmodule

module mkDMAWriter#(Server#(MemengineCmd,Bool) wServer,
                    PipeIn#(Bit#(64)) wPipe,
                    DebugDMA dmaDebug
                    )(DMAWriteIfc);
   Reg#(Bit#(32)) burstCnt <- mkReg(0);
   //Reg#(Bit#(32)) numBursts <- mkRegU();
   //Reg#(Bit#(32)) lastBurstSz <- mkRegU();
   //Reg#(Bit#(32)) buffPtr <- mkRegU();
   
   //Reg#(Bool) busy <- mkReg(False);
   
   Reg#(Bit#(32)) burstIterCnt <- mkReg(0);
   //Reg#(Bit#(32)) numOfResp <- mkRegU();

   FIFO#(Bit#(64)) reqDtaQ <- mkFIFO;
   FIFO#(Bool) doneQ <- mkFIFO;
   
   FIFO#(MemengineCmd) serverReqFifo <- mkFIFO;
   
   mkConnection(toGet(serverReqFifo), wServer.request);
   
   FIFO#(Tuple3#(Bit#(32), Bit#(32), Bit#(32))) cmdQ <- mkSizedFIFO(numStages);
   FIFO#(Bit#(32)) numOfRespQ <- mkSizedFIFO(numStages);
   
   rule drive_write;// if (busy && burstCnt <= numBursts);
      let v = cmdQ.first;
      let buffPtr = tpl_1(v);
      let numBursts = tpl_2(v);
      let lastBurstSz = tpl_3(v);
      
      $display("drWrRq: burstCnt = %d, numBursts = %d", burstCnt, numBursts);
      if ( burstCnt +1 == numBursts && lastBurstSz != 0) begin
         $display("Last request");
         //wServer.request.put(MemengineCmd{sglId:buffPtr, base:extend(burstCnt<<7), len:truncate(lastBurstSz), burstLen:truncate(lastBurstSz)});
         serverReqFifo.enq(MemengineCmd{sglId:buffPtr, base:extend(burstCnt<<7), len:truncate(lastBurstSz), burstLen:truncate(lastBurstSz)});
      end
      else if ( burstCnt + 1 < numBursts) begin
         $display("Normal request");
         //wServer.request.put(MemengineCmd{sglId:buffPtr, base:extend(burstCnt<<7), len:128, burstLen:128});
         serverReqFifo.enq(MemengineCmd{sglId:buffPtr, base:extend(burstCnt<<7), len:128, burstLen:128});
      end
      
      if ( burstCnt + 1 < numBursts ) begin
         burstCnt <= burstCnt + 1;
      end
      else begin
         burstCnt <= 0;
         cmdQ.deq();
      end
      
   endrule
   
   FIFO#(Bool) finishFIFO <- mkFIFO;
   rule finish_fifo;
      let rv1 <- wServer.response.get;
      finishFIFO.enq(True);
   endrule
   
   rule write_finish;// if (busy);
      
      let numOfResp = numOfRespQ.first();
      $display("write_finish %d, %d", burstIterCnt, numOfResp);
      if ( numOfResp > 0) 
         let v <- toGet(finishFIFO).get();
      if ( burstIterCnt + 1 < numOfResp) begin
         burstIterCnt <= burstIterCnt + 1;
      end
      else  begin
         doneQ.enq(True);
         burstIterCnt <= 0;
         numOfRespQ.deq();
         //busy <= False;
      end
      
      
   endrule
   
   rule drRdResp;
      let v <- toGet(reqDtaQ).get();
      dmaDebug.setData(v);
      $display("DMA Helper Got Data: %d", v);
      wPipe.enq(v);
   endrule
   
   
   
   method Action writeReq(Bit#(32) wp, Bit#(64) nBytes);// if (!busy);
      dmaDebug.setAddr(wp);
      dmaDebug.setBytes(nBytes);

      //burstCnt <= 0;
      //Bit#(32) numBursts = ?;
      Bit#(32) numOfResp = ?;
      Bit#(32) lastBurstSz = ?;
      //numBursts <= truncate(nBytes >> 7);
      if ( nBytes[2:0] == 0 )
         lastBurstSz = extend(nBytes[6:0]);
      else
         lastBurstSz = extend(nBytes[6:3]+1)<<3;
   
      //buffPtr <= wp;
      //busy <= True;
      
      //burstIterCnt <= 0;
      if (nBytes[6:0] == 0 )
         numOfResp = truncate(nBytes >> 7);
      else
         numOfResp = truncate(nBytes >> 7) + 1;
      
      cmdQ.enq(tuple3(wp, numOfResp, lastBurstSz));
      numOfRespQ.enq(numOfResp);
   endmethod
   
   interface Put request = toPut(reqDtaQ);
   
   method Action done();
      let v <- toGet(doneQ).get();
      //$display("DMA writer done");
   endmethod
   
endmodule
