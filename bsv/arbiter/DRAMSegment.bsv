import ClientServer::*;
import GetPut::*;
import Vector::*;
import FIFO::*;
import FIFOF::*;
import MyArbiter::*;
import DRAMCommon::*;
import DRAMController::*;


interface DRAMSegmentIfc#(numeric type numServers);
   interface Vector#(numServers, DRAMServer) dramServers;
   interface Vector#(numServers, Put#(Bit#(64))) initializers;
   interface DRAMClient dramClient;
   method Action reset();
endinterface

interface DRAM_LOCK_SegmentIfc#(numeric type numServers);
   interface Vector#(numServers, DRAM_LOCK_Server) dramServers;
   interface Vector#(numServers, Put#(Bit#(64))) initializers;
   interface DRAMClient dramClient;
   interface Get#(Bit#(TLog#(numServers))) nextBurstSeg;
   method Action reset();
endinterface

interface DRAM_LOCK_Segment_Bypass#(numeric type numServers);
   interface Vector#(numServers, DRAM_LOCK_Server) dramServers;
   interface Vector#(numServers, Put#(Bit#(64))) initializers;
   interface DRAM_LOCK_Client dramClient;
   method Action reset();
endinterface




//typedef 30 LogMaxAddr;

module mkDRAMSegments(DRAMSegmentIfc#(numServers));
   
   //Integer addrSeg = valueOf(TExp#(TSub#(LogMaxAddr,TLog#(2))));
   Vector#(numServers, Reg#(Bit#(64))) baseAddrs <- replicateM(mkRegU());
   Vector#(numServers, Reg#(Bit#(64))) segSizes <- replicateM(mkRegU());
   Vector#(numServers, Reg#(Bool)) initFlags <- replicateM(mkReg(False));
   
   
   Arbiter_IFC#(numServers) arbiter <- mkArbiter(True);

   Vector#(numServers, FIFOF#(DRAMReq)) reqs<- replicateM(mkFIFOF);
   Vector#(numServers, FIFO#(Bit#(512))) resps<- replicateM(mkFIFO);
   
   
   FIFO#(DRAMReq) cmdQ <- mkFIFO;
   //FIFO#(Bit#(512)) dataQ <- mkFIFO;
   FIFO#(Bit#(512)) dataQ <- mkSizedFIFO(32);
   
   FIFO#(Bit#(TLog#(numServers))) tagQ <- mkSizedFIFO(32);
   
   
   function Bool readReg(Reg#(Bool) v);
      return v;
   endfunction
   
   
   Reg#(Bool) init <- mkReg(False);
   Reg#(Bit#(TLog#(numServers))) cnt <- mkReg(0);
   rule doInit if ( !init && all(readReg, initFlags));
      if ( cnt + 1 == 0 ) begin
         init <= True;
      end

      cnt <= cnt + 1;

      
      if ( cnt == 0) begin
         baseAddrs[cnt] <= 0;
      end
      else begin
         baseAddrs[cnt] <= baseAddrs[cnt-1] + segSizes[cnt-1];
      end
   endrule
      
   for (Integer i = 0; i < valueOf(numServers); i = i + 1) begin
      rule doReqs_0 if (reqs[i].notEmpty && init);
         arbiter.clients[i].request;
      endrule
      
      rule doReqs_1 if (arbiter.grant_id == fromInteger(i));
         let req <- toGet(reqs[i]).get();
         `ifdef BSIM
         if (req.addr < segSizes[i] ) begin
            //$display("%m:: req.addr = %d, baseAddr[%d] = %d", req.addr, i, baseAddrs[i]);
            `endif
            req.addr = req.addr + baseAddrs[i];
            cmdQ.enq(req);
            if (req.rnw) begin
               tagQ.enq(fromInteger(i));
            end
            `ifdef BSIM
         end
         else begin
            $display("%m:: Segmentation Fault, addr = %d, maxAddr = %d", req.addr, segSizes[i]);
         end
         `endif
      endrule
      
      rule doResp if ( tagQ.first() == fromInteger(i));
         let data = dataQ.first;
         resps[i].enq(data);
         tagQ.deq();
         dataQ.deq();
      endrule
   end



   Vector#(numServers, DRAMServer) ds;
   for (Integer i = 0; i < valueOf(numServers); i = i + 1)
      ds[i] = (interface DRAMServer;
                  interface Put request = toPut(reqs[i]);
                  interface Get response = toGet(resps[i]);
               endinterface);
   
   Vector#(numServers, Put#(Bit#(64))) inits;
   for (Integer i = 0; i < valueOf(numServers); i = i + 1)
      inits[i] = (interface Put#(Bit#(64));
                     method Action put(Bit#(64) v) if (!initFlags[i]);
                        $display("%m:: DRAMSeg Init[%d], SegSize = %d", i, v);
                        segSizes[i] <= v;
                        initFlags[i] <= True;
                     endmethod
                  endinterface);
   
   interface dramServers = ds;
   interface initializers = inits;
   
   
   interface DRAMClient dramClient;
      interface Get request = toGet(cmdQ);
      interface Put response = toPut(dataQ);
   endinterface
   method Action reset();
      init <= False;
      for (Integer i = 0; i < valueOf(numServers); i = i + 1) begin
         initFlags[i] <= False;
      end
   endmethod
endmodule


module mkDRAM_LOCK_Segments(DRAM_LOCK_SegmentIfc#(numServers));
   
   //Integer addrSeg = valueOf(TExp#(TSub#(LogMaxAddr,TLog#(2))));
   Vector#(numServers, Reg#(Bit#(64))) baseAddrs <- replicateM(mkRegU());
   Vector#(numServers, Reg#(Bit#(64))) segSizes <- replicateM(mkRegU());
   Vector#(numServers, Reg#(Bool)) initFlags <- replicateM(mkReg(False));
   
   
   Arbiter_IFC#(numServers) arbiter <- mkArbiter(False);

   Vector#(numServers, FIFOF#(DRAM_LOCK_Req)) reqs<- replicateM(mkFIFOF);
   Vector#(numServers, FIFO#(Bit#(512))) resps<- replicateM(mkFIFO);
   
   
   FIFO#(DRAMReq) cmdQ <- mkFIFO;
   //FIFO#(Bit#(512)) dataQ <- mkFIFO;
   FIFO#(Bit#(512)) dataQ <- mkSizedFIFO(32);
   
   FIFO#(Bit#(TLog#(numServers))) tagQ <- mkSizedFIFO(32);
   
   FIFO#(Bit#(TLog#(numServers))) orderQ <- mkSizedFIFO(32);
   
   
   Reg#(Maybe#(Bit#(TLog#(numServers)))) lockReg <- mkReg(Invalid);
      
   function Bool readReg(Reg#(Bool) v);
      return v;
   endfunction
   
   
   Reg#(Bool) init <- mkReg(False);
   Reg#(Bit#(TLog#(numServers))) cnt <- mkReg(0);
   rule doInit if ( !init && all(readReg, initFlags));
      if ( cnt + 1 == 0 ) begin
         init <= True;
      end

      cnt <= cnt + 1;

      
      if ( cnt == 0) begin
         baseAddrs[cnt] <= 0;
      end
      else begin
         baseAddrs[cnt] <= baseAddrs[cnt-1] + segSizes[cnt-1];
      end
   endrule
      
   FIFO#(Bit#(64)) debugAddrQ <- mkSizedFIFO(32);
   for (Integer i = 0; i < valueOf(numServers); i = i + 1) begin
      rule doReqs_0 if ((reqs[i].first.ignoreLock || fromInteger(i) == fromMaybe(fromInteger(i),lockReg)) && init);
         arbiter.clients[i].request;
      endrule
      Reg#(Bit#(32)) debug_cnt <- mkReg(0);
      rule doReqs_1 if (arbiter.grant_id == fromInteger(i));
         let req <- toGet(reqs[i]).get();
         `ifdef BSIM
         if (req.addr < segSizes[i] ) begin
            //$display("%m:: req.addr = %d, baseAddr[%d] = %d", req.addr, i, baseAddrs[i]);
            `endif
            $display("%m cmd i = %d, lock = %d, ignoreLock = %d, rnw = %d, addr = %d, numBytes = %d", i, req.lock, req.ignoreLock, req.rnw, req.addr, req.numBytes);
            req.addr = req.addr + baseAddrs[i];
            cmdQ.enq(DRAMReq{rnw: req.rnw, addr: req.addr, data: req.data, numBytes: req.numBytes});

            $display(lockReg);
            
            if (!req.ignoreLock) begin
               if ( req.initlock ) begin
                  $display("enqueing next burst Id = %d, addr = %d, debug_cnt = %d", i, req.addr - baseAddrs[i], debug_cnt);
                  debug_cnt <= debug_cnt + 1;
                  orderQ.enq(fromInteger(i));
               end

               if (req.lock) begin
                  lockReg <= tagged Valid fromInteger(i);
                  //if ( !isValid(lockReg) ) begin
               end
               else begin
                  lockReg <= tagged Invalid;
               end
            end
            
            if (req.rnw) begin
               tagQ.enq(fromInteger(i));
               
               debugAddrQ.enq(req.addr);
            end
            `ifdef BSIM
         end
         else begin
            $display("%m:: Segmentation Fault, addr = %d, maxAddr = %d", req.addr, segSizes[i]);
         end
         `endif
      endrule
      
      rule doResp if ( tagQ.first() == fromInteger(i));
         $display("%m return data for addr = %d, to client %d", debugAddrQ.first(), i);
         debugAddrQ.deq();
         let data = dataQ.first;
         resps[i].enq(data);
         tagQ.deq();
         dataQ.deq();
      endrule
   end



   Vector#(numServers, DRAM_LOCK_Server) ds;
   for (Integer i = 0; i < valueOf(numServers); i = i + 1)
      ds[i] = (interface DRAM_LOCK_Server;
                  interface Put request = toPut(reqs[i]);
                  interface Get response = toGet(resps[i]);
               endinterface);
   
   Vector#(numServers, Put#(Bit#(64))) inits;
   for (Integer i = 0; i < valueOf(numServers); i = i + 1)
      inits[i] = (interface Put#(Bit#(64));
                     method Action put(Bit#(64) v) if (!initFlags[i]);
                        $display("%m:: DRAMSeg Init[%d], SegSize = %d", i, v);
                        segSizes[i] <= v;
                        initFlags[i] <= True;
                     endmethod
                  endinterface);
   
   interface dramServers = ds;
   interface initializers = inits;
   
   interface DRAMClient dramClient;
      interface Get request = toGet(cmdQ);
      interface Put response = toPut(dataQ);
   endinterface
      
   interface Get nextBurstSeg = toGet(orderQ);

   method Action reset();
      init <= False;
      for (Integer i = 0; i < valueOf(numServers); i = i + 1) begin
         initFlags[i] <= False;
      end
   endmethod

endmodule

module mkDRAM_LOCK_Segments_Bypass(DRAM_LOCK_Segment_Bypass#(numServers));
   
   //Integer addrSeg = valueOf(TExp#(TSub#(LogMaxAddr,TLog#(2))));
   Vector#(numServers, Reg#(Bit#(64))) baseAddrs <- replicateM(mkRegU());
   Vector#(numServers, Reg#(Bit#(64))) segSizes <- replicateM(mkRegU());
   Vector#(numServers, Reg#(Bool)) initFlags <- replicateM(mkReg(False));
   
   
   Arbiter_IFC#(numServers) arbiter <- mkArbiter(False);

   Vector#(numServers, FIFOF#(DRAM_LOCK_Req)) reqs<- replicateM(mkFIFOF);
   Vector#(numServers, FIFO#(Bit#(512))) resps<- replicateM(mkFIFO);
   
   
   FIFO#(DRAM_LOCK_Req) cmdQ <- mkFIFO;
   //FIFO#(Bit#(512)) dataQ <- mkFIFO;
   FIFO#(Bit#(512)) dataQ <- mkSizedFIFO(32);
   
   FIFO#(Bit#(TLog#(numServers))) tagQ <- mkSizedFIFO(32);
   
   
   function Bool readReg(Reg#(Bool) v);
      return v;
   endfunction
   
   
   Reg#(Bool) init <- mkReg(False);
   Reg#(Bit#(TLog#(numServers))) cnt <- mkReg(0);
   rule doInit if ( !init && all(readReg, initFlags));
      if ( cnt + 1 == 0 ) begin
         init <= True;
      end

      cnt <= cnt + 1;

      
      if ( cnt == 0) begin
         baseAddrs[cnt] <= 0;
      end
      else begin
         baseAddrs[cnt] <= baseAddrs[cnt-1] + segSizes[cnt-1];
      end
   endrule
      
   for (Integer i = 0; i < valueOf(numServers); i = i + 1) begin
      rule doReqs_0 if (reqs[i].notEmpty && init);
         arbiter.clients[i].request;
      endrule
      
      rule doReqs_1 if (arbiter.grant_id == fromInteger(i));
         let req <- toGet(reqs[i]).get();
         `ifdef BSIM
         if (req.addr < segSizes[i] ) begin
            //$display("%m:: req.addr = %d, baseAddr[%d] = %d", req.addr, i, baseAddrs[i]);
            `endif
            req.addr = req.addr + baseAddrs[i];
            cmdQ.enq(req);
            if (req.rnw) begin
               tagQ.enq(fromInteger(i));
            end
            `ifdef BSIM
         end
         else begin
            $display("%m:: Segmentation Fault, addr = %d, maxAddr = %d", req.addr, segSizes[i]);
         end
         `endif
      endrule
      
      rule doResp if ( tagQ.first() == fromInteger(i));
         let data = dataQ.first;
         resps[i].enq(data);
         tagQ.deq();
         dataQ.deq();
      endrule
   end



   Vector#(numServers, DRAM_LOCK_Server) ds;
   for (Integer i = 0; i < valueOf(numServers); i = i + 1)
      ds[i] = (interface DRAM_LOCK_Server;
                  interface Put request = toPut(reqs[i]);
                  interface Get response = toGet(resps[i]);
               endinterface);
   
   Vector#(numServers, Put#(Bit#(64))) inits;
   for (Integer i = 0; i < valueOf(numServers); i = i + 1)
      inits[i] = (interface Put#(Bit#(64));
                     method Action put(Bit#(64) v) if (!initFlags[i]);
                        $display("%m:: DRAMSeg Init[%d], SegSize = %d", i, v);
                        segSizes[i] <= v;
                        initFlags[i] <= True;
                     endmethod
                  endinterface);
   
   interface dramServers = ds;
   interface initializers = inits;
   
   interface DRAM_LOCK_Client dramClient;
      interface Get request = toGet(cmdQ);
      interface Put response = toPut(dataQ);
   endinterface
   
   method Action reset();
      init <= False;
      for (Integer i = 0; i < valueOf(numServers); i = i + 1) begin
         initFlags[i] <= False;
      end
   endmethod

endmodule
