package Hashtable;

import Connectable::*;
import ClientServer::*;
import GetPut::*;
import FIFO::*;
import Time::*;
import MemcachedTypes::*;
import ValuestrCommon::*;
import DRAMCommon::*;
import DRAMArbiter::*;

//`define DEBUG

import HashtableTypes::*;
import HashtableArbiter::*;
import HeaderReader::*;
import HeaderWriter::*;

interface HashtableInitIfc;
   method Action initTable(Bit#(64) lgOffset);
   method Bool initialized;
endinterface

interface HashtableIfc;
   interface Server#(HashtableReqT, HashtableRespType) server;
   interface HashtableInitIfc init;
   interface DRAMClient dramClient;
   interface Put#(HeaderUpdateReqT) hdrUpdateRequest;
   interface ValAllocClient valAllocClient;   
endinterface


(*synthesize*)
module mkAssocHashtb(HashtableIfc);
   let clk <- mkLogicClock();
   
   let hdrRd <- mkHeaderReader();
   let hdrWr <- mkHeaderWriter(hdrRd.sFifoPort);
   let htArbiter <- mkHashtableArbiter();

   mkConnection(hdrRd.dramClient, htArbiter.hdrRdServer);
   mkConnection(hdrWr.dramClient, htArbiter.hdrWrServer);
   mkConnection(hdrRd.response, hdrWr.request);
   mkConnection(hdrRd.wrAck, htArbiter.wrAck);   
   mkConnection(hdrWr.hdrUpdDRAMClient, htArbiter.hdrUpdDramServer);
   
   DRAMArbiterIfc#(2) dramSwitch <- mkDRAMArbiter;
   mkConnection(htArbiter.dramClient, dramSwitch.dramServers[0]);
   
   Reg#(PhyAddr) addr <- mkReg(0);
   FIFO#(PhyAddr) addrMaxQ <- mkFIFO;
   Reg#(Bool) initialized <- mkReg(False);
   rule doinit;
      let addrMax = addrMaxQ.first();
      if ( addr + 64 >= addrMax ) begin
         addr <= 0;
         addrMaxQ.deq;
         initialized <= True;
      end
      else begin
         addr <= addr + 64;
      end
      //$display("addr = %d, numBytes = %d", addr, 64);
      dramSwitch.dramServers[1].request.put(DRAMReq{rnw: False,
                                                    addr: addr, 
                                                    data: 0,
                                                    numBytes: 64});
   endrule
     
   Reg#(HashValueT) hvMax <- mkRegU();
        
   Reg#(Bit#(32)) hvCnt <- mkReg(0);
   
   interface Server server;
      interface Put request;
         method Action put(HashtableReqT v) if (initialized);
            hdrRd.request.put(HdrRdReqT{hv: v.hv & hvMax,
                                        hvKey: v.hvKey,
                                        key_size: v.key_size,
                                        value_size: v.value_size,
                                        time_now: clk.get_time(),
                                        rnw: v.rnw
                                        });
         endmethod
      endinterface
      interface Get response = hdrWr.response;
   endinterface

   interface HashtableInitIfc init;
      method Action initTable(Bit#(64) lgOffset);
         //hvMax <= unpack((1 << lgOffset) - 1) / fromInteger(valueOf(ItemOffset));
         hvMax <= (1 << lgOffset) - 1;
         PhyAddr maxAddr = (1 << lgOffset) << 6;
      //`ifndef BSIM
         addrMaxQ.enq(maxAddr);
         //initialized <= False;
         //`else
         //initialized <= True;
         //`endif
      endmethod
   
      method Bool initialized;
         return initialized;
      endmethod
   endinterface
   
   interface DRAMClient dramClient = dramSwitch.dramClient;
   interface Put hdrUpdateRequest = hdrWr.hdrUpdateRequest;
   interface ValAllocClient valAllocClient = hdrWr.valAllocClient;
endmodule

endpackage: Hashtable

