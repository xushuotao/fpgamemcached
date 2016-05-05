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

import ValFlashCtrlTypes::*;

interface HashtableInitIfc;
   method ActionValue#(Bool) initialized;
endinterface

interface HashtableIfc;
   interface Server#(HashtableReqT, HashtableRespType) server;
   interface HashtableInitIfc init;
   interface DRAMClient dramClient;
   interface Client#(FlashStoreCmd, FlashAddrType) flashClient;
endinterface


(*synthesize*)
module mkAssocHashtb(HashtableIfc);
   let clk <- mkLogicClock();
   
   let hdrRd <- mkHeaderReader();
   let hdrWr <- mkHeaderWriter();
   let htArbiter <- mkHashtableArbiter();

   mkConnection(hdrRd.dramClient, htArbiter.hdrRdServer);
   mkConnection(hdrWr.dramClient, htArbiter.hdrWrServer);
   mkConnection(hdrRd.response, hdrWr.request);
   mkConnection(hdrRd.wrAck, htArbiter.wrAck);   
      
   DRAMArbiterIfc#(2) dramSwitch <- mkDRAMArbiter;
   mkConnection(htArbiter.dramClient, dramSwitch.dramServers[0]);
   
   Reg#(PhyAddr) addr <- mkReg(0);
   FIFO#(PhyAddr) addrMaxQ <- mkFIFO;
   
   
   
   `ifdef BSIM
   Integer dramSz = valueOf(TExp#(25));
   `else
   Integer dramSz = valueOf(TExp#(30));
   `endif
   Integer writeBufSz = valueOf(TMul#(2,TExp#(20)));
   Integer htableSz = (dramSz - writeBufSz);
   Integer hvMax = htableSz/64;
   //FIFO#(Bool) initializedQ <- mkFIFO();
   
   `ifndef BSIM
   Reg#(Bool) initialized <- mkReg(False);
   rule doinit if (!initialized);
      //let addrMax = addrMaxQ.first();
      if ( addr + 64 >= fromInteger(htableSz) ) begin
         addr <= 0;
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
   `else
   Reg#(Bool) initialized <- mkReg(True);
   `endif
     
   //Reg#(HashValueT) hvMax <- mkRegU();
        
   Reg#(Bit#(32)) hvCnt <- mkReg(0);
   
   interface Server server;
      interface Put request;
         method Action put(HashtableReqT v) if (initialized);
            hdrRd.request.put(HdrRdReqT{hv: v.hv % fromInteger(hvMax),
                                        hvKey: v.hvKey,
                                        key_size: v.key_size,
                                        value_size: v.value_size,
                                        time_now: clk.get_time(),
                                        opcode: v.opcode,
                                        reqId: v.reqId
                                        });
         endmethod
      endinterface
      interface Get response = hdrWr.response;
   endinterface

   interface HashtableInitIfc init;
   
      method ActionValue#(Bool) initialized if (initialized);
         `ifdef BSIM
         hdrWr.reset();
         `endif
         return True;
      endmethod
   endinterface
   
   interface DRAMClient dramClient = dramSwitch.dramClient;
   interface Client flashClient = hdrWr.flashClient;   
endmodule

endpackage: Hashtable

