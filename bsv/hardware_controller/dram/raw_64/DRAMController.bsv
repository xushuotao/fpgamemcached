package DRAMController;

import Clocks          :: *;
import XilinxVC707DDR3::*;
//import DDR3Sim::*;
//import DDR3Controller::*;
import Xilinx       :: *;
import XilinxCells ::*;

import FIFO::*;
import FIFOF::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;
import Counter::*;


import DRAMControllerTypes::*;


interface DebugProbe;
   method DDRRequest req;
   method DDRResponse resp;
endinterface


interface DRAMControllerIfc;
	
   method Action write(Bit#(64) addr, Bit#(512) data, Bit#(7) bytes);
      
   method ActionValue#(Bit#(512)) read;
   method Action readReq(Bit#(64) addr, Bit#(7) bytes);
   //interface Clock dram_clk;
   //interface Reset dram_rst_n;
      
   interface DDR3Client ddr3_cli;
   
   interface DebugProbe debug;
endinterface

//(*synthesize*)
module mkDRAMController(DRAMControllerIfc);
   Clock clk <- exposeCurrentClock;
   Reset rst_n <- exposeCurrentReset;
      
   //Clock ddr3_clk = user.clock;
   //Reset ddr3_rstn = user.reset_n;
   
   FIFO#(DDRRequest) reqs <- mkFIFO();
   FIFO#(DDRResponse) resps <- mkFIFO();
   
   //SyncFIFOIfc#(Tuple3#(Bit#(64), Bit#(512), Bit#(64))) dramCDataInQ <- mkSyncFIFO(32, clk, rst_n, ddr3_clk);
   FIFO#(Tuple3#(Bit#(64), Bit#(512), Bit#(64))) dramCDataInQ <- mkFIFO();
   
   rule driverWrie;// (writeReqOrderQ.first == procReqIdx) ;
      dramCDataInQ.deq;
      let d = dramCDataInQ.first;
      let addr = tpl_1(d);
      let data = tpl_2(d);
      let wmask = tpl_3(d);
      
      
      let offset = addr[5:0];
      
      Bit#(64) rowidx = addr>>6;
      
      //user.request(truncate(addr>>3), wmask << offset, data << {offset,3'b0});
      reqs.enq(DDRRequest{writeen: wmask << offset,
                           address: rowidx << 3,
                           datain: data << {offset,3'b0}
                           });
      
      //procReqIdx <= procReqIdx + 1;
      //writeReqOrderQ.deq;
   endrule
   //FIXME dramCDataInQ and dramCDataOutQ might cause RAW hazard unless force ordered
   //probably will not happen, so left like this for now. FIXME!!
   //SyncFIFOIfc#(Tuple2#(Bit#(64), Bit#(7))) dramCReadReqQ <- mkSyncFIFO(32, clk, rst_n, ddr3_clk);
   FIFO#(Tuple2#(Bit#(64), Bit#(7))) dramCReadReqQ <- mkFIFO();
   
   //FIFO#(Bit#(3)) readOffsetQ <- mkSizedFIFO(32, clocked_by ddr3_clk, reset_by ddr3_rstn);
   FIFO#(Bit#(6)) readOffsetQ <- mkSizedFIFO(32);
   rule driverReadC; // (readReqOrderQ.first == procReqIdx);
      dramCReadReqQ.deq;
      Bit#(64) addr = tpl_1(dramCReadReqQ.first);
      Bit#(64) rowidx = addr>>6;
      
      readOffsetQ.enq(addr[5:0]);
      
      //user.request(truncate(addr>>3), 0, 0);
      reqs.enq(DDRRequest{writeen: 0,
                           address: rowidx<<3,
                           datain: 0
                           });
      
   endrule
   
   //SyncFIFOIfc#(Bit#(512)) dramCDataOutQ <- mkSyncFIFO(32, ddr3_clk, ddr3_rstn, clk);
   FIFO#(Bit#(512)) dramCDataOutQ <- mkFIFO();
   rule recvRead ;
      //Bit#(512) res <- user.read_data;
      Bit#(512) res <- toGet(resps).get();
      let offset = readOffsetQ.first;
      readOffsetQ.deq;
      dramCDataOutQ.enq(res >> {offset,3'b0});
      //dramCDataOutQ.enq(res);
   endrule

   Wire#(DDRRequest) req_wire <- mkWire;
   Wire#(DDRResponse) resp_wire <- mkWire;
   
   method Action write(Bit#(64) addr, Bit#(512) data, Bit#(7) bytes);
      
      let offset = addr & extend(6'b111111);
      
      Bit#(64) wmask = (1<<bytes) - 1;
      Bit#(64) rowidx = addr>>6;
      
      dramCDataInQ.enq(tuple3(addr, data, wmask));
   endmethod
   method Action readReq(Bit#(64) addr, Bit#(7) bytes);
      
      dramCReadReqQ.enq(tuple2(addr, bytes));
      
   endmethod
   method ActionValue#(Bit#(512)) read;
      dramCDataOutQ.deq;
      return dramCDataOutQ.first;
   endmethod
   //interface dram_clk = clk;
   //interface dram_rst_n = rst_n;
   
   interface DDR3Client ddr3_cli;
      //interface Get request = toGet(reqs);
      //interface Put response = toPut(resps);
      interface Get request;// = toGet(reqs);
         method ActionValue#(DDRRequest) get();
            let v <- toGet(reqs).get();
            req_wire <= v;
            return v;
         endmethod
      endinterface
      
      interface Put response;
         method Action put(DDRResponse v);
            resp_wire <= v;
            toPut(resps).put(v);
         endmethod
      endinterface
   endinterface
   
   interface DebugProbe debug;
      method DDRRequest req;
         return req_wire;
      endmethod
      method DDRResponse resp;
         return resp_wire;
      endmethod
   endinterface

   
endmodule

typedef 32 MAX_OUTSTANDING_READS;

instance Connectable#(DDR3Client, DDR3_User_VC707);
   module mkConnection#(DDR3Client cli, DDR3_User_VC707 usr)(Empty);
      
      // Make sure we have enough buffer space to not drop responses!
      Counter#(TLog#(MAX_OUTSTANDING_READS)) reads <- mkCounter(0, clocked_by(usr.clock), reset_by(usr.reset_n));
      FIFO#(DDRResponse) respbuf <- mkSizedFIFO(valueof(MAX_OUTSTANDING_READS), clocked_by(usr.clock), reset_by(usr.reset_n));
   
      rule request (reads.value() != fromInteger(valueof(MAX_OUTSTANDING_READS)-1));
         let req <- cli.request.get();
         usr.request(truncate(req.address), req.writeen, req.datain);
         
         if (req.writeen == 0) begin
            reads.up();
         end
      endrule
   
      rule response (True);
         let x <- usr.read_data;
         respbuf.enq(x);
      endrule
   
      rule forward (True);
         let x <- toGet(respbuf).get();
         cli.response.put(x);
         reads.down();
      endrule
   endmodule
endinstance


// Brings a DDR3Client from one clock domain to another.
module mkDDR3ClientSync#(DDR3Client ddr2,
    Clock sclk, Reset srst, Clock dclk, Reset drst
    ) (DDR3Client);

    SyncFIFOIfc#(DDRRequest) reqs <- mkSyncFIFO(32, sclk, srst, dclk);
    SyncFIFOIfc#(DDRResponse) resps <- mkSyncFIFO(32, dclk, drst, sclk);

    mkConnection(toPut(reqs), toGet(ddr2.request));
    mkConnection(toGet(resps), toPut(ddr2.response));

    interface Get request = toGet(reqs);
    interface Put response = toPut(resps);
endmodule


endpackage: DRAMController
