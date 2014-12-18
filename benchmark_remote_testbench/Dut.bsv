
import ClientServer::*;
import GetPut::*;
import BRAM::*;
import FIFO::*;
import ProtocolHeader::*;

`ifndef BSIM
import AuroraEndpointHelper::*;
`else
import AuroraEndpointHelper_Verifier::*;
`endif



interface ProcIfc;
   method Action start(Bit#(32) numTests);
   method ActionValue#(Bool) done();
   method Action setNetId(Bit#(32) netid);
   method Action dumpStart();
   interface Get#(MemReqType) dumpReqs;
   interface Get#(Bit#(64)) dumpDta;
   
endinterface

module mkProc#(RemoteIfc auroraIfc)(ProcIfc);
   
   Reg#(Bit#(32)) numTest <- mkReg(0);
   
   Reg#(Bit#(32)) cmdCnt_send_0 <- mkReg(0);
   Reg#(Bit#(32)) dtaCnt_send_0 <- mkReg(0);
   Reg#(Bit#(32)) cmdCnt_recv_0 <- mkReg(0);
   Reg#(Bit#(32)) dtaCnt_recv_0 <- mkReg(0);
   
   Reg#(Bit#(32)) cmdCnt_send_1 <- mkReg(0);
   Reg#(Bit#(32)) dtaCnt_send_1 <- mkReg(0);
   Reg#(Bit#(32)) cmdCnt_recv_1 <- mkReg(0);
   Reg#(Bit#(32)) dtaCnt_recv_1 <- mkReg(0);
 
   
   Reg#(Bool) started <- mkReg(False);
   

   Reg#(Bit#(32)) netId <- mkReg(0);
   
   Wire#(Bool) done0 <- mkWire();
   Wire#(Bool) done1 <- mkWire();
   Wire#(Bool) done2 <- mkWire();
   Wire#(Bool) done3 <- mkWire();
   
   //FIFO#(MemReqType) cmdQ <- mkSizedBRAMFIFO(64);
   //FIFO#(Tuple#(Bit#(64),Bool)) dataQ <- mkSizedBRAMFIFO(1024);
   
   BRAM_Configure cfg = defaultValue;
   BRAM2Port#(Bit#(6), MemReqType) cmdStr <- mkBRAM2Server(cfg);
   BRAM2Port#(Bit#(10), Bit#(64)) dtaStr <- mkBRAM2Server(cfg);
   
   //rule doNode0 (netId == 0);
   rule sendCmds (started && (netId == 0));
      if ( cmdCnt_send_0 < numTest ) begin
         $display("Node 0 sending cmd %d", cmdCnt_send_0);
         auroraIfc.requestPort.sendPort.sendCmd(MemReqType{opcode:PROTOCOL_BINARY_CMD_SET, keylen: 64, vallen: 64, hv: -1}, 1);
         cmdCnt_send_0 <= cmdCnt_send_0 + 1;
      end
      else begin
         done0 <= True;
      end
   endrule
   
   rule sendDta (started && (netId == 0));
      if ( dtaCnt_send_0 < (numTest << 4) ) begin
         $display("Node 0 sending dta %d, %d", dtaCnt_send_0, numTest<<4);
         auroraIfc.requestPort.sendPort.inPipe.put(64'h0123456789abcef);
         dtaCnt_send_0 <= dtaCnt_send_0 + 1;
      end
      else begin
         done1 <= True;
      end
   endrule
   
   rule recvCmds (started && (netId == 0));
      if ( cmdCnt_recv_0 < numTest ) begin
         let v <- auroraIfc.responsePort.recvPort.recvCmd;
         $display("Node 0 received cmd %d", cmdCnt_recv_0);
         cmdStr.portA.request.put(BRAMRequest{
            write: True,
            responseOnWrite:False,
            address: truncate(cmdCnt_recv_0),
            datain: tpl_1(v)
            });
         cmdCnt_recv_0 <= cmdCnt_recv_0 + 1;
      end
      else begin
         done2 <= True;
      end

   endrule
   
   rule recvDta (started && (netId == 0));
      if ( dtaCnt_recv_0 < (numTest << 4)) begin
         let v <- auroraIfc.responsePort.recvPort.outPipe.get();
         $display("Node 0 received dta %d", dtaCnt_recv_0);
         if ( v!= 64'h0123456789abcef ) $finish();
         dtaStr.portA.request.put(BRAMRequest{
            write: True,
            responseOnWrite:False,
            address: truncate(dtaCnt_recv_0),
            datain: v
            });
         dtaCnt_recv_0 <= dtaCnt_recv_0 + 1;
      end
      else begin
         done3 <= True;
      end

   endrule
   
   //endrule
   

   rule recvCmds_1 if (started && (netId == 1));
      if ( cmdCnt_recv_1 < numTest ) begin
         let v <- auroraIfc.requestPort.recvPort.recvCmd;
         $display("Node 1 received cmd %d", cmdCnt_recv_1);
         auroraIfc.responsePort.sendPort.sendCmd(MemReqType{opcode:PROTOCOL_BINARY_CMD_GET, keylen: 0, vallen: 128, hv: -1}, 0);
         cmdStr.portA.request.put(BRAMRequest{
            write: True,
            responseOnWrite:False,
            address: truncate(cmdCnt_recv_1),
            datain: tpl_1(v)
            });
         cmdCnt_recv_1 <= cmdCnt_recv_1 + 1;
      end
      else begin
         done0 <= True;
         done1 <= True;
      end
   endrule
   
   rule recvDta_1 if (started && (netId == 1));
      if ( dtaCnt_recv_1 < (numTest << 4)) begin
         $display("Node 1 received dta %d", dtaCnt_recv_1);
         let v <- auroraIfc.requestPort.recvPort.outPipe.get();
         if ( v!= 64'h0123456789abcef ) $finish();
         auroraIfc.responsePort.sendPort.inPipe.put(v);
         dtaStr.portA.request.put(BRAMRequest{
                                              write: True,
                                              responseOnWrite:False,
                                              address: truncate(dtaCnt_recv_1),
                                              datain: v
                                              });
         dtaCnt_recv_1 <= dtaCnt_recv_1 + 1;
      end
      else begin
         done2 <= True;
         done3 <= True;
      end
   endrule

   
   FIFO#(MemReqType) cmdQ <- mkFIFO();
   FIFO#(Bit#(64)) dtaQ <- mkFIFO();
   
   Reg#(Bit#(32)) cmdCnt_dump <- mkReg(0);
   Reg#(Bit#(32)) dtaCnt_dump <- mkReg(0);
   
   Reg#(Bool) dumpStarted <- mkReg(False);
   
   rule dumpCmds if (dumpStarted) ;
      if ( cmdCnt_dump < numTest ) begin
         cmdStr.portB.request.put(BRAMRequest{
                                              write: False,
                                              responseOnWrite:False,
                                              address: truncate(cmdCnt_dump),
                                              datain: ?
                                              });
         cmdCnt_dump <= cmdCnt_dump + 1;
      end
   endrule
   
  
   rule dumpDtas if (dumpStarted);
      if ( dtaCnt_dump < (numTest<<4) ) begin
         dtaStr.portB.request.put(BRAMRequest{
                                              write: False,
                                              responseOnWrite:False,
                                              address: truncate(dtaCnt_dump),
                                              datain: ?
                                              });
         dtaCnt_dump <= dtaCnt_dump + 1;
      end
   endrule
      
   
   method Action start(Bit#(32) numTests);
      if (numTests > 64)
         numTest <= 0;
      else
         numTest <= numTests;
      cmdCnt_send_0 <= 0;
      dtaCnt_send_0 <= 0;
      cmdCnt_recv_0 <= 0;
      dtaCnt_recv_0 <= 0;
      
      cmdCnt_send_1 <= 0;
      dtaCnt_send_1 <= 0;
      cmdCnt_recv_1 <= 0;
      dtaCnt_recv_1 <= 0;
      started <= True;
      dumpStarted <= False;
   endmethod

   method ActionValue#(Bool) done() if (done0&&done1&&done2&&done3);
      started <= False;
      return True;
   endmethod
   
   method Action setNetId(Bit#(32) netid);
      netId <= netid;
   endmethod
   
   method Action dumpStart();
      cmdCnt_dump <= 0;
      dtaCnt_dump <= 0;
      dumpStarted <= True;
   endmethod
      
   interface dumpReqs = cmdStr.portB.response;
   interface dumpDta = dtaStr.portB.response;

            
endmodule
