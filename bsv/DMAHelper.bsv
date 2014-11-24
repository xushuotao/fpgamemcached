import GetPut::*;
import ClientServer::*;
import Connectable::*;

import PortalMemory::*;
import MemTypes::*;
import MemreadEngine::*;
import MemwriteEngine::*;
import Pipe::*;
import IlaWrapper::*;

import FIFO::*;

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


   Reg#(Bit#(32)) burstCnt <- mkRegU();
   Reg#(Bit#(32)) numBursts <- mkRegU();
   Reg#(Bit#(32)) lastBurstSz <- mkRegU();
   Reg#(Bit#(32)) buffPtr <- mkRegU();
   
   Reg#(Bool) busy <- mkReg(False);
   
   Reg#(Bit#(32)) burstIterCnt <- mkRegU();
   Reg#(Bit#(32)) numOfResp <- mkRegU();

   FIFO#(Bit#(64)) respDtaQ <- mkFIFO;
   
   FIFO#(MemengineCmd) serverReqFifo <- mkFIFO;
   
   mkConnection(toGet(serverReqFifo), rServer.request);
   
   rule drive_read if (busy && burstCnt <= numBursts);
      //$display("drRdRq: burstCnt = %d, numBursts = %d", burstCnt, numBursts);
      if ( burstCnt == numBursts ) begin
         if ( lastBurstSz != 0) begin
            //$display("Last request");
            //rServer.request.put(MemengineCmd{sglId:buffPtr, base:extend(burstCnt<<7), len:truncate(lastBurstSz), burstLen:truncate(lastBurstSz)});
            serverReqFifo.enq(MemengineCmd{sglId:buffPtr, base:extend(burstCnt<<7), len:truncate(lastBurstSz), burstLen:truncate(lastBurstSz)});
         end
      end
      else begin
         //$display("Normal request");
        // rServer.request.put(MemengineCmd{sglId:buffPtr, base:extend(burstCnt<<7), len:128, burstLen:128});
         serverReqFifo.enq(MemengineCmd{sglId:buffPtr, base:extend(burstCnt<<7), len:128, burstLen:128});
      end
      burstCnt <= burstCnt + 1;
   endrule

   FIFO#(Bool) finishFIFO <- mkFIFO;
   rule finish_fifo;
      let rv1 <- rServer.response.get;
      finishFIFO.enq(True);
   endrule
   
   rule read_finish if (busy);
      //$display("read_finish %d", burstIterCnt, numOfResp);
      if ( burstIterCnt < numOfResp) begin
         //let rv0 <- rServer.response.get;
         let v <- toGet(finishFIFO).get();
      end
      else if ( burstIterCnt == numOfResp) begin
         busy <= False;
      end
      
      burstIterCnt <= burstIterCnt + 1;
   endrule
   
   rule read_Val;
      let v <- toGet(rPipe).get;
      //$display("DMA reader get val = %h", v);
      dmaDebug.setData(v);
      respDtaQ.enq(v); 
   endrule
   
   method Action readReq(Bit#(32) rp, Bit#(64) nBytes) if (!busy);
      dmaDebug.setAddr(rp);
      dmaDebug.setBytes(nBytes);
   
      burstCnt <= 0;
      numBursts <= truncate(nBytes >> 7);
      if ( nBytes[2:0] == 0 )
         lastBurstSz <= extend(nBytes[6:0]);
      else
         lastBurstSz <= extend(nBytes[6:3]+1)<<3;
   
      buffPtr <= rp;
      busy <= True;
      
      burstIterCnt <= 0;
      if (nBytes[6:0] == 0 )
         numOfResp <= truncate(nBytes >> 7);
      else
         numOfResp <= truncate(nBytes >> 7) + 1;
   
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
   Reg#(Bit#(32)) burstCnt <- mkRegU();
   Reg#(Bit#(32)) numBursts <- mkRegU();
   Reg#(Bit#(32)) lastBurstSz <- mkRegU();
   Reg#(Bit#(32)) buffPtr <- mkRegU();
   
   Reg#(Bool) busy <- mkReg(False);
   
   Reg#(Bit#(32)) burstIterCnt <- mkRegU();
   Reg#(Bit#(32)) numOfResp <- mkRegU();

   FIFO#(Bit#(64)) reqDtaQ <- mkFIFO;
   FIFO#(Bool) doneQ <- mkFIFO;
   
   FIFO#(MemengineCmd) serverReqFifo <- mkFIFO;
   
   mkConnection(toGet(serverReqFifo), wServer.request);
   
   rule drive_write if (busy && burstCnt <= numBursts);
      
      
      //$display("drWrRq: burstCnt = %d, numBursts = %d", burstCnt, numBursts);
      if ( burstCnt == numBursts ) begin
         if ( lastBurstSz != 0) begin
            //$display("Last request");
            //wServer.request.put(MemengineCmd{sglId:buffPtr, base:extend(burstCnt<<7), len:truncate(lastBurstSz), burstLen:truncate(lastBurstSz)});
            serverReqFifo.enq(MemengineCmd{sglId:buffPtr, base:extend(burstCnt<<7), len:truncate(lastBurstSz), burstLen:truncate(lastBurstSz)});
         end
      end
      else begin
         //$display("Normal request");
         //wServer.request.put(MemengineCmd{sglId:buffPtr, base:extend(burstCnt<<7), len:128, burstLen:128});
         serverReqFifo.enq(MemengineCmd{sglId:buffPtr, base:extend(burstCnt<<7), len:128, burstLen:128});
      end
      burstCnt <= burstCnt + 1;
   endrule
   
   FIFO#(Bool) finishFIFO <- mkFIFO;
   rule finish_fifo;
      let rv1 <- wServer.response.get;
      finishFIFO.enq(True);
   endrule
   
   rule write_finish if (busy);
      //$display("write_finish %d, %d", burstIterCnt, numOfResp);
      if ( burstIterCnt < numOfResp) begin
         let v <- toGet(finishFIFO).get();
      end
      else if ( burstIterCnt == numOfResp) begin
         doneQ.enq(True);
         busy <= False;
      end
      
      burstIterCnt <= burstIterCnt + 1;
   endrule
   
   rule drRdResp;
      let v <- toGet(reqDtaQ).get();
      dmaDebug.setData(v);
      wPipe.enq(v);
   endrule
   
   
   method Action writeReq(Bit#(32) wp, Bit#(64) nBytes) if (!busy);
      dmaDebug.setAddr(wp);
      dmaDebug.setBytes(nBytes);

      burstCnt <= 0;
      numBursts <= truncate(nBytes >> 7);
      if ( nBytes[2:0] == 0 )
         lastBurstSz <= extend(nBytes[6:0]);
      else
         lastBurstSz <= extend(nBytes[6:3]+1)<<3;
   
      buffPtr <= wp;
      busy <= True;
      
      burstIterCnt <= 0;
      if (nBytes[6:0] == 0 )
         numOfResp <= truncate(nBytes >> 7);
      else
         numOfResp <= truncate(nBytes >> 7) + 1;
   endmethod
   
   interface Put request = toPut(reqDtaQ);
   
   method Action done();
      let v <- toGet(doneQ).get();
      //$display("DMA writer done");
   endmethod
   
endmodule
