import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import ClientServerHelper::*;
import MyArbiter::*;
import DRAMCommon::*;

interface HashtableArbiter;
   interface DRAMServer hdrRdServer;
   interface Put#(DRAMReq) hdrWrServer;
   interface Get#(Bool) wrAck;
   
   interface DRAMClient dramClient;
endinterface

(*synthesize*)
module mkHashtableArbiter(HashtableArbiter);
   Vector#(2, FIFOF#(DRAMReq)) dramReqQs <- replicateM(mkFIFOF);
   
   FIFO#(DRAMReq) dramCmdQ <- mkSizedFIFO(32);
   FIFO#(Bit#(512)) dramRespQ <- mkFIFO;
   
   FIFO#(Bool) wrAckQ <- mkBypassFIFO;
   FIFO#(Bool) hdrUpdAckQ <- mkBypassFIFO;
   
   Arbiter_IFC#(2) arb <- mkArbiter(False);
   
   for (Integer i = 0; i < 2; i = i + 1) begin
      rule doArbReq if ( dramReqQs[i].notEmpty);
         arb.clients[i].request();
      endrule
      
      rule doArbResp if ( arb.clients[i].grant );
         let req <- toGet(dramReqQs[i]).get();
         
         $display("HtableArbiter: sending Req i = %d", i);
         $display("rnw = %d, addr = %d, data = %h, nBytes = %d", req.rnw, req.addr, req.data, req.numBytes);
         
         if ( i == 1 ) begin
            $display("HtableArbiter: HeaderWriter Ack sent");
            if ( req.numBytes > 0 ) begin
               dramCmdQ.enq(req);
            end
            wrAckQ.enq(True);
         end
         else begin
            dramCmdQ.enq(req);
         end
      endrule
   end
   
   
   
   
   interface DRAMServer hdrRdServer;
      interface Put request = toPut(dramReqQs[0]);
      interface Get response = toGet(dramRespQ);
   endinterface
   interface Put hdrWrServer = toPut(dramReqQs[1]);
   interface Get wrAck = toGet(wrAckQ);

   interface DRAMClient dramClient = toClient(dramCmdQ, dramRespQ);
   
endmodule
