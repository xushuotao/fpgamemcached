package Packet;

import FIFO::*;

import GetPut::*;


interface DepacketIfc#(numeric type packetSz, numeric type bufSz, numeric type offset);
   method Action start(Bit#(32) nBufs, Bit#(32) nPackets);
   interface Put#(Bit#(packetSz)) inPipe;
   interface Get#(Bit#(bufSz)) outPipe;
endinterface

interface PacketIfc#(numeric type packetSz, numeric type bufSz, numeric type offset);
   method Action start(Bit#(32) nBufs, Bit#(32) nPackets);
   interface Put#(Bit#(bufSz)) inPipe;
   interface Get#(Bit#(packetSz)) outPipe;
endinterface

//(*synthesize*)
module mkDepacketEngine(DepacketIfc#(packetSz, bufSz, offset))
   provisos(Add#(a__, TAdd#(TLog#(packetSz), 1), TAdd#(TLog#(bufSz), 1)));
   
   Integer initialSz = valueOf(bufSz) - valueOf(offset);
   Integer remainder = initialSz%valueOf(packetSz);
   Integer residual = valueOf(packetSz) - remainder;
   
   FIFO#(Bit#(packetSz)) packetFifo <- mkFIFO();
   FIFO#(Bit#(bufSz)) bufFifo <- mkFIFO();
   
   Reg#(Bool) busy <- mkReg(False);

   Reg#(Bit#(bufSz)) bufFifoBuf <- mkReg(0);
   Reg#(Bit#(TAdd#(TLog#(packetSz),1))) packetPtr <- mkReg(fromInteger(valueOf(packetSz))); 
   Reg#(Bit#(TAdd#(TLog#(bufSz),1))) bufPtr <- mkReg(fromInteger(initialSz));
   
   Reg#(Bit#(32)) bufCnt <- mkReg(0);
   Reg#(Bit#(32)) packetCnt <- mkReg(0);
      
   
   rule process if (busy);
     
      if ( bufCnt == 0 && packetCnt == 0 ) begin
         busy <= False;
      end
      else begin
         $display("DepacketEngine, packetPtr = %d, bufPtr = %d, bufCnt = %d, packetCnt = %d", packetPtr, bufPtr, bufCnt, packetCnt);
         if ( extend(packetPtr) <= bufPtr ) begin
            if (packetCnt > 0) begin
               let packet = packetFifo.first;
               if (packetPtr == fromInteger(valueOf(packetSz))) begin
                  bufFifoBuf <= truncateLSB({packet, bufFifoBuf});
               end
               else begin
                  Bit#(packetSz) temp = packet >> fromInteger(remainder);
                  bufFifoBuf <= truncateLSB({temp,bufFifoBuf} << fromInteger(remainder));
               end
               packetPtr <= fromInteger(valueOf(packetSz));
               bufPtr <= bufPtr - extend(packetPtr);
               packetFifo.deq();
               packetCnt <= packetCnt - 1;
            end
            else begin
               bufFifo.enq(bufFifoBuf >> bufPtr);
               bufCnt <= bufCnt - 1;
            end
         end
         else begin 
            Bit#(packetSz) packet = 0;
            if ( packetCnt > 0) begin
               packet = packetFifo.first;
            end
            bufFifo.enq(truncateLSB({packet, bufFifoBuf} << fromInteger(residual)));
            bufPtr <= fromInteger(valueOf(bufSz));
            packetPtr <= packetPtr - truncate(bufPtr);
            bufCnt <= bufCnt - 1;
         end
      end
   endrule
   
   method Action start(Bit#(32) nBufs, Bit#(32) nPackets) if (!busy);
      $display("DepacketEng start, nBufs = %d, nPackets = %d", nBufs, nPackets);
      packetPtr <= fromInteger(valueOf(packetSz)); 
      bufPtr <= fromInteger(initialSz);
      packetCnt <= nPackets;
      bufCnt <= nBufs;
      bufFifoBuf <= 0;
      busy <= True;
   endmethod
   interface Put inPipe = toPut(packetFifo);
   interface Get outPipe = toGet(bufFifo);
endmodule
   
//(*synthesize*)
module mkPacketEngine(PacketIfc#(packetSz, bufSz, offset))
   provisos(Add#(a__, TAdd#(TLog#(packetSz), 1), TAdd#(TLog#(bufSz), 1)),
            Add#(b__, packetSz, bufSz));
   
   Integer initialSz = valueOf(bufSz) - valueOf(offset);
   Integer remainder = initialSz%valueOf(packetSz);
   Integer residual = valueOf(packetSz) - remainder;
   
   FIFO#(Bit#(packetSz)) packetFifo <- mkFIFO();
   FIFO#(Bit#(bufSz)) bufFifo <- mkFIFO();
   
   Reg#(Bool) busy <- mkReg(False);
   Reg#(Bool) firstLine <- mkReg(False);
   
   Reg#(Bit#(packetSz)) tempPacket <- mkReg(0);
   Reg#(Bit#(bufSz)) tempBuf <- mkReg(0);
   Reg#(Bit#(TAdd#(TLog#(packetSz),1))) packetPtr <- mkReg(fromInteger(valueOf(packetSz))); 
   Reg#(Bit#(TAdd#(TLog#(bufSz),1))) bufPtr <- mkReg(fromInteger(initialSz));
   
   Reg#(Bit#(32)) bufCnt <- mkReg(0);
   Reg#(Bit#(32)) packetCnt <- mkReg(0);
      
   
   rule process if (busy);
      if ( bufCnt == 0 && packetCnt == 0 ) begin
         busy <= False;
      end
      /* First buf data received*/
      else 
         if (firstLine) begin
            $display("PacketEngine, firstLine, packetPtr = %d, bufPtr = %d, bufCnt = %d, packetCnt = %d", packetPtr, bufPtr, bufCnt, packetCnt);
            firstLine <= False;
            let v = bufFifo.first;
            bufFifo.deq();
            tempBuf <= v >> fromInteger(valueOf(offset));
            bufCnt <= bufCnt - 1;
         end
         else begin
            $display("PacketEngine, packetPtr = %d, bufPtr = %d, bufCnt = %d, packetCnt = %d", packetPtr, bufPtr, bufCnt, packetCnt);
            if (extend(packetPtr) > bufPtr) begin
               if ( bufCnt == 0 ) begin
                  tempBuf <= 0;
               end
               else begin
                  bufCnt <= bufCnt - 1;
                  let v = bufFifo.first;
                  bufFifo.deq();
                  tempBuf <= v;
               end
               bufPtr <= fromInteger(valueOf(bufSz));
               packetPtr <= packetPtr - truncate(bufPtr);
               tempPacket <= truncate(tempBuf) << fromInteger(residual);
            end
            else begin 
               if (packetPtr == fromInteger(valueOf(packetSz))) begin
                  packetFifo.enq(truncate(tempBuf));
                  tempBuf <= tempBuf >> fromInteger(valueOf(packetSz));
               end
               else begin
                  //packetFifo.enq(truncate({tempPacket,tempBuf} >> fromInteger(valueOf(bufSz) - remainder)));
                  packetFifo.enq(truncate({tempBuf,tempPacket} >> fromInteger(residual)));
                  tempBuf <= tempBuf >> fromInteger(residual);
               end
               bufPtr <= bufPtr - extend(packetPtr);
               packetPtr <= fromInteger(valueOf(packetSz));
               packetCnt <= packetCnt - 1;
            end
         end
   endrule
   
   method Action start(Bit#(32) nBufs, Bit#(32) nPackets) if (!busy);
      $display("PacketEng start, nBufs = %d, nPackets = %d", nBufs, nPackets);
      packetPtr <= fromInteger(valueOf(packetSz));
      bufPtr <= fromInteger(initialSz);
      packetCnt <= nPackets;
      bufCnt <= nBufs;
      busy <= True;
      firstLine <= True;
   endmethod
   interface Put inPipe = toPut(bufFifo);
   interface Get outPipe = toGet(packetFifo);
endmodule
   
endpackage
