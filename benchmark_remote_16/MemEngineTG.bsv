import ClientServer::*;
import Vector::*;
import LFSR::*;
import FIFOF::*;
import FIFO::*;
import SpecialFIFOs::*;
import GetPut::*;

import MemTypes::*;
import Pipe::*;

interface MemreadEngineReset#(numeric type dataWidth, numeric type cmdQDepth, numeric type numServers);
   interface MemreadEngineV#(dataWidth, cmdQDepth, numServers) re;
   method Action setReset(Bit#(64) v);
endinterface


module mkReadTrafficGen(MemreadEngineReset#(dataWidth, cmdQDepth, numServers))
   provisos(Add#(a__, 64, dataWidth));
   Vector#(numServers, FIFOF#(MemengineCmd)) reqQs <- replicateM(mkFIFOF);
   Vector#(numServers, FIFOF#(Bit#(dataWidth))) dataQs <- replicateM(mkFIFOF);
   Vector#(numServers, FIFO#(Bool)) doneQs <- replicateM(mkFIFO);
   
   Reg#(Bit#(64)) resetMax <- mkRegU();
   Reg#(Bool) doget <- mkReg(False);
   
   Vector#(numServers, Reg#(Bit#(64))) seeds<- replicateM(mkReg(0));
   Vector#(numServers, Reg#(Bit#(33))) cnts<- replicateM(mkReg(0));
   
   for (Integer i = 0; i < valueOf(numServers); i = i + 1) begin
      //Reg#(Bit#(64)) seeds[i] <- mkReg(0);
      
      //Reg#(Bit#(33)) cnts[i] <- mkReg(0);
      
      
      rule process;
         let cmd = reqQs[i].first();
         Bit#(33) cntMax = extend(cmd.len);
         
         //$display("cnt = %d, cntMax = %d", cnt, cntMax);
         if (cnts[i] + 8 >= cntMax) begin
            reqQs[i].deq();
            cnts[i] <= 0;
         end
         else begin
            cnts[i] <= cnts[i] + 8;
         end
         
         dataQs[i].enq(extend(seeds[i]));
         
         if ( !doget ) begin
            if ( seeds[i] + 1 >= resetMax ) begin
               seeds[i] <= 0;
               doget <= True;
            end
            else begin
               seeds[i] <= seeds[i] + 1;
            end
         end
         else begin
            if ( seeds[i][2:0] == 7 ) begin
               seeds[i] <= seeds[i] + 9;
            end
            else begin
               seeds[i] <= seeds[i] + 1;
            end
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

   interface MemreadEngineV re;
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
   endinterface
   
   method Action setReset(Bit#(64) v);
      resetMax <= v;
      doget <= False;
   
      for (Integer i = 0; i < valueOf(numServers); i = i + 1) begin
         seeds[i] <= 0;
         cnts[i] <= 0;
      end
   endmethod
endmodule


module mkWriteTrafficGen(MemwriteEngineV#(dataWidth, cmdQDepth, numServers));
   Vector#(numServers, FIFO#(MemengineCmd)) reqQs <- replicateM(mkSizedFIFO(32));
   Vector#(numServers, FIFOF#(Bit#(dataWidth))) dataQs <- replicateM(mkFIFOF);
   Vector#(numServers, FIFO#(Bool)) doneQs <- replicateM(mkFIFO);
   
   for (Integer i = 0; i < valueOf(numServers); i = i + 1) begin 
      FIFO#(Bit#(33)) lenQ <- mkFIFO();
      Reg#(Bit#(33)) cnt <- mkReg(0);
      
      //(* descending_urgency = "process_output, process_cmd" *)
      
      /*rule process_cmd;
         let cmd <- toGet(reqQs[i]).get();
         lenQ.enq(extend(cmd.len));
         cnt <= 0;
      endrule*/
      
      rule process_output;
         //let length = lenQ.first();
         Bit#(33) length = extend(reqQs[i].first().len);
         
         let v <- toGet(dataQs[i]).get();
         $display("MemReadEng got data = %d, cnt = %d, length = %d", v, cnt, length);         
         if ( cnt + 8 >= length ) begin
            reqQs[i].deq();
            doneQs[i].enq(True);
            cnt <= 0;
         end
         else begin
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
