import Packet::*;
import GetPut::*;

typedef enum {Idle, Data} State deriving (Bits, Eq);

typedef 120 Offset;

module mkTest(Empty);
   Reg#(Bit#(64)) packet <- mkReg(64'h1111111111111111);
   
   DepacketIfc#(64, 128, Offset) depacketEng <- mkDepacketEngine();
   PacketIfc#(64, 128, Offset) packetEng <- mkPacketEngine();
   
   Reg#(State) state <- mkReg(Idle);
   
   Reg#(Bit#(32)) nPackets <- mkRegU();
   Reg#(Bit#(32)) nPackets_2 <- mkRegU();
   
   Reg#(Bit#(32)) testCnt <- mkReg(0);
   Bit#(32) nTests = 5;
   
   Reg#(Bit#(32)) numBufs <- mkRegU();
  
   
   rule process if (state == Idle);
      Int#(32) nBufs = 0; 
      if ( testCnt < nTests ) begin
         $display("depacketEngine Request No %d", testCnt);
         Bit#(32) numPackets = testCnt + 1;
         depacketEng.start(numPackets);
         Int#(32) modulus = (unpack(numPackets)*64 + fromInteger(valueOf(Offset)))%128;
         if ( modulus == 0) begin
            nBufs = (unpack(numPackets)*64 + fromInteger(valueOf(Offset)))/128;
         end
         else begin
            nBufs = (unpack(numPackets)*64 + fromInteger(valueOf(Offset)))/128 + 1;
         end
         packetEng.start(pack(nBufs), numPackets);
         nPackets <= numPackets;
         nPackets_2 <= numPackets;
         numBufs <= pack(nBufs);
         state <= Data;
         testCnt <= testCnt + 1;
      end
      else begin
         $display("Done");
         depacketEng.start(0);
         packetEng.start(0,0);
         $finish(0);
      end
   endrule
   
   rule process_1 if (state == Data);
      if (nPackets > 0) begin
         depacketEng.inPipe.put(packet);
         packet <= packet + 64'h1111111111111111;
         $display("depacketEngine inPipe put: %h", packet);
         nPackets <= nPackets - 1;
      end
      else begin
         //state <= Idle;
         packet <= 64'h1111111111111111;
      end
   endrule
   
   rule process_2;
      let v <- depacketEng.outPipe.get();
      $display("depacketEngine/packetEngine outPipe/inPipe got: %h", v);
      if ( numBufs > 0) begin
         packetEng.inPipe.put(v);
         numBufs <= numBufs - 1;
      end
   endrule
   
   rule process_3 if (state == Data);
      if (nPackets_2 > 0) begin
         let v <- packetEng.outPipe.get();
         $display("packetEngine outPiple got: %h",v);
         nPackets_2 <= nPackets_2 - 1;
      end
      else begin
         $display("going back to Idle");
         state <= Idle;
      end
   endrule
endmodule
