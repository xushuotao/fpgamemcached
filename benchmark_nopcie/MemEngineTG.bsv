import ClientServer::*;
import Vector::*;
import LFSR::*;
import FIFOF::*;
import FIFO::*;
import GetPut::*;

import MemTypes::*;
import Pipe::*;


module mkReadTrafficGen(MemreadEngineV#(dataWidth, cmdQDepth, numServers))
   provisos(Add#(a__, 64, dataWidth));
   Vector#(numServers, FIFO#(MemengineCmd)) reqQs <- replicateM(mkFIFO);
   Vector#(numServers, FIFOF#(Bit#(dataWidth))) dataQs <- replicateM(mkFIFOF);
   Vector#(numServers, FIFO#(Bool)) doneQs <- replicateM(mkFIFO);
   
   for (Integer i = 0; i < valueOf(numServers); i = i + 1) begin
      Reg#(Bit#(1)) globalCnt <- mkReg(0);
      Reg#(Bit#(64)) seed <- mkReg(1);
      
      FIFO#(Bit#(33)) lenQ <- mkFIFO;
      Reg#(Bit#(33)) cnt <- mkRegU();
      Bit#(64) feed = 0;
      feed[63] = 1;
      feed[62] = 1;
      feed[61] = 1;
      feed[60] = 1;
      LFSR#(Bit#(64)) randGen <- mkFeedLFSR(feed);
      //Reg#(Bit#(64)) randReg <- mkReg(0);
      
      (* descending_urgency = "process_output, process_cmd" *)
      
      rule process_cmd;
         let cmd <- toGet(reqQs[i]).get();
         $display("length = %d", cmd.len);
         lenQ.enq(extend(cmd.len));
         cnt <= 0;
         randGen.seed(seed);
         if (globalCnt == 1)
            seed <= seed + 1;
         globalCnt <= globalCnt + 1;
      endrule
      
      rule process_output;
         let length = lenQ.first();
         if ( cnt >= length ) begin
            lenQ.deq();
            doneQs[i].enq(True);
            $display("dma Done");
         end
         else begin
            let data = randGen.value;
            //let data = randReg;
            //randReg <= randReg + 1;
            randGen.next();
            dataQs[i].enq(extend(data));
            $display("dma inPipe[%d] = %h", cnt, data);
            cnt <= cnt + 8;
         end
      endrule
   end
            

   function MemreadServer#(dataWidth) bar(Server#(MemengineCmd,Bool) cs, PipeOut#(Bit#(dataWidth)) p) =
      (interface MemreadServer;
          interface cmdServer = cs;
          interface dataPipe  = p;
       endinterface);         
         
   
   Vector#(numServers, Server#(MemengineCmd,Bool)) rs;
   for (Integer i = 0; i < valueOf(numServers); i = i + 1)
      rs[i] = (interface Server#(MemengineCmd,Bool);
                  interface Put request;
                     method Action put(MemengineCmd c);
                        reqQs[i].enq(c);
                     endmethod
                  endinterface
                  interface Get response;
                     method ActionValue#(Bool) get;
                        let v <- toGet(doneQs[i]).get();
                        return v;
                     endmethod
                  endinterface
               endinterface);
               
   interface readServers = rs;
         
   interface ObjectReadClient dmaClient;
      interface Get readReq;
         method ActionValue#(ObjectRequest) get();
            return ?;
         endmethod
      endinterface
      interface Put readData;
         method Action put(ObjectData#(dataWidth) d);
         endmethod
      endinterface
   endinterface
   
   interface dataPipes = map(toPipeOut, dataQs);
   interface read_servers = zipWith(bar, rs, map(toPipeOut,dataQs));
endmodule


module mkWriteTrafficGen(MemwriteEngineV#(dataWidth, cmdQDepth, numServers));
   Vector#(numServers, FIFO#(MemengineCmd)) reqQs <- replicateM(mkFIFO);
   Vector#(numServers, FIFOF#(Bit#(dataWidth))) dataQs <- replicateM(mkFIFOF);
   Vector#(numServers, FIFO#(Bool)) doneQs <- replicateM(mkFIFO);
   
   for (Integer i = 0; i < valueOf(numServers); i = i + 1) begin 
      FIFO#(Bit#(33)) lenQ <- mkFIFO();
      Reg#(Bit#(33)) cnt <- mkRegU();
      
      (* descending_urgency = "process_output, process_cmd" *)
      
      rule process_cmd;
         let cmd <- toGet(reqQs[i]).get();
         lenQ.enq(extend(cmd.len));
         cnt <= 0;
      endrule
      
      rule process_output;
         let length = lenQ.first();
         if ( cnt >= length ) begin
            lenQ.deq();
            doneQs[i].enq(True);
         end
         else begin
            let v <- toGet(dataQs[i]).get();
            cnt <= cnt + 8;
         end
      endrule
   end
      
   Vector#(numServers, Server#(MemengineCmd,Bool)) ws;
   for (Integer i = 0; i < valueOf(numServers); i = i + 1)
      ws[i] = (interface Server#(MemengineCmd,Bool);
                  interface Put request;
                     method Action put(MemengineCmd c);
                        reqQs[i].enq(c);
                     endmethod
                  endinterface
                  interface Get response;
                     method ActionValue#(Bool) get;
                        let v <- toGet(doneQs[i]).get();
                        return v;
                     endmethod
                  endinterface
               endinterface);
               
   interface writeServers = ws;
         
   interface ObjectWriteClient dmaClient;
      interface Get writeReq;
         method ActionValue#(ObjectRequest) get();
            return ?;
         endmethod
      endinterface
      interface Get writeData;
         method ActionValue#(ObjectData#(dataWidth)) get;
            return ?;
         endmethod
      endinterface
   endinterface
   
   interface dataPipes = map(toPipeIn, dataQs);
endmodule
