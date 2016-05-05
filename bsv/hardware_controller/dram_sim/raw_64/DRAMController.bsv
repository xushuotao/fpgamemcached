package DRAMController;

import Clocks          :: *;
//import XilinxVC707DDR3::*;
import DDR3Sim::*;
//import Xilinx       :: *;
//import XilinxCells ::*;

import FIFO::*;
import FIFOF::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;
import Counter::*;

import DRAMControllerTypes::*;

interface DRAMControllerIfc;
	
   method Action write(Bit#(64) addr, Bit#(512) data, Bit#(7) bytes);
   
   method ActionValue#(Bit#(512)) read;
   method Action readReq(Bit#(64) addr, Bit#(7) bytes);
   //interface Clock dram_clk;
   //interface Reset dram_rst_n;
   
   interface DDR3Client ddr3_cli;
   
   
endinterface

(*synthesize*)
module mkDRAMController(DRAMControllerIfc);
   Clock clk <- exposeCurrentClock;
   Reset rst_n <- exposeCurrentReset;
      
   //Clock ddr3_clk = user.clock;
   //Reset ddr3_rstn = user.reset_n;
   
   FIFO#(DDR3Request) reqs <- mkFIFO();
   FIFO#(DDR3Response) resps <- mkFIFO();
   
   //SyncFIFOIfc#(Tuple3#(Bit#(64), Bit#(512), Bit#(64))) dramCDataInQ <- mkSyncFIFO(32, clk, rst_n, ddr3_clk);
   FIFOF#(Tuple3#(Bit#(64), Bit#(512), Bit#(64))) dramCDataInQ <- mkFIFOF;
   FIFOF#(Tuple2#(Bit#(64), Bit#(7))) dramCReadReqQ <- mkFIFOF;
   FIFO#(Bit#(6)) readOffsetQ <- mkSizedFIFO(32);
  
   
   
   rule driverWrie (dramCDataInQ.notEmpty);// (writeReqOrderQ.first == procReqIdx) ;
      dramCDataInQ.deq;
      let d = dramCDataInQ.first;
      let addr = tpl_1(d);
      let data = tpl_2(d);
      let wmask = tpl_3(d);
      
      
      let offset = addr[5:0];
      
      Bit#(64) rowidx = addr>>6;
      
      //user.request(truncate(addr>>3), wmask << offset, data << {offset,3'b0});
      reqs.enq(DDR3Request{writeen: wmask << offset,
                           address: rowidx << 3,
                           datain: data << {offset,3'b0}
                           });
      
      //procReqIdx <= procReqIdx + 1;
      //writeReqOrderQ.deq;
   endrule
   //FIXME dramCDataInQ and dramCDataOutQ might cause RAW hazard unless force ordered
   //probably will not happen, so left like this for now. FIXME!!
   //SyncFIFOIfc#(Tuple2#(Bit#(64), Bit#(7))) dramCReadReqQ <- mkSyncFIFO(32, clk, rst_n, ddr3_clk);
    rule driverReadC (dramCReadReqQ.notEmpty); // (readReqOrderQ.first == procReqIdx);
      dramCReadReqQ.deq;
      Bit#(64) addr = tpl_1(dramCReadReqQ.first);
      Bit#(64) rowidx = addr>>6;
      
      readOffsetQ.enq(addr[5:0]);
      
      //user.request(truncate(addr>>3), 0, 0);
       $display("\x1b[35mDRAMController(%t): get read req, addr = %d, bytes = %d\x1b[0m", $time, rowidx<<3, 64);
      reqs.enq(DDR3Request{writeen: 0,
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
   
   method Action write(Bit#(64) addr, Bit#(512) data, Bit#(7) bytes);
      //$display("\x1b[35mDRAMController(%t): get write req, addr = %d, bytes = %d, data = %h\x1b[0m", $time, addr, bytes, data);
      let offset = addr & extend(6'b111111);
      
      Bit#(64) wmask = (1<<bytes) - 1;
      Bit#(64) rowidx = addr>>6;
      
      dramCDataInQ.enq(tuple3(addr, data, wmask));
   endmethod
   method Action readReq(Bit#(64) addr, Bit#(7) bytes);
      //$display("\x1b[35mDRAMController(%t): get read req, addr = %d, bytes = %d\x1b[0m", $time, addr, bytes);
      dramCReadReqQ.enq(tuple2(addr, bytes));
      
   endmethod
   method ActionValue#(Bit#(512)) read;
      //$display("\x1b[35mDRAMController(%t): sends back read value  = %h\x1b[0m", $time, dramCDataOutQ.first);
      dramCDataOutQ.deq;
      return dramCDataOutQ.first;
   endmethod
   //interface dram_clk = clk;
   //interface dram_rst_n = rst_n;
   
   interface DDR3Client ddr3_cli;
      interface Get request = toGet(reqs);
      interface Put response = toPut(resps);
   endinterface
   
endmodule

typedef 32 MAX_OUTSTANDING_READS;

instance Connectable#(DDR3Client, DDR3_User_VC707_Sim);
   module mkConnection#(DDR3Client cli, DDR3_User_VC707_Sim usr)(Empty);
   
      // Make sure we have enough buffer space to not drop responses!
      Counter#(TLog#(MAX_OUTSTANDING_READS)) reads <- mkCounter(0, clocked_by(usr.clock), reset_by(usr.reset_n));
      FIFO#(DDR3Response) respbuf <- mkSizedFIFO(valueof(MAX_OUTSTANDING_READS), clocked_by(usr.clock), reset_by(usr.reset_n));
      //FIFO#(DDR3Response) respbuf <- mkFIFO(clocked_by(usr.clock), reset_by(usr.reset_n));
   
      rule request  (reads.value() != fromInteger(valueof(MAX_OUTSTANDING_READS)-1));
         let req <- cli.request.get();
         usr.request(truncate(req.address), req.writeen, req.datain);
         
         if (req.writeen == 0) begin
            reads.up();
         end
      endrule
   
      rule response (True);
         let x <- usr.read_data;
         respbuf.enq(x);
         //cli.response.put(x);
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

    SyncFIFOIfc#(DDR3Request) reqs <- mkSyncFIFO(32, sclk, srst, dclk);
    SyncFIFOIfc#(DDR3Response) resps <- mkSyncFIFO(32, dclk, drst, sclk);

   //mkConnection(toPut(reqs), toGet(ddr2.request));
   mkConnection(toGet(ddr2.request), toPut(reqs));
   rule doConn;
      let v <- toGet(resps).get();
      $display("Put response %h", v);
      ddr2.response.put(v);
   endrule
   //mkConnection(toGet(resps), toPut(ddr2.response));

    interface Get request = toGet(reqs);
    interface Put response = toPut(resps);
endmodule

endpackage: DRAMController
