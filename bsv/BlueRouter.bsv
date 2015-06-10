import FIFO::*;
import FIFOF::*;


import Clocks::*;
import Xilinx::*;
`ifndef BSIM
import XilinxCells::*;
`endif

import AuroraImportFmc1::*;

import ControllerTypes::*;
import FlashCtrlVirtex::*;
import FlashCtrlModel::*;

import AuroraExtArbiterBar::*;
import AuroraExtEndpoint::*;
import AuroraExtImport::*;

interface RouterIfc;
   method Action sendReq(Bit#(32) length, Bit#(5) nodeId);
   method ActionValue#(Bit#(5)) sendAck();
   method Action sendDta(Bit#(128) packet, Bit#(5) nodeId);
   //interface Vector#(tEndpointCount, AuroraEndpointCmdIfc) endpoints;
endinterface

module mkRouter(Vector#(tExtCount, AuroraExtUserIfc) extPorts);
   AuroraEndpointIfc#(Bit#(32)) sendReq_end <- mkAuroraEndpointStatic(32, 4);
   AuroraEndpointIfc#(Bool) sendAck_end <- mkAuroraEndpointStatic(32, 4);
   AuroraEndpointIfc#(Bit#(128)) sendDta_end <- mkAuroraEndpointStatic(128, 64);
   let auroraList = cons(sendDta_end.cmd, cons(sendAck_end.cmd, cons(sendReq_end.cmd, nil)));
   AuroraExtArbiterBarIfc auroraExtArbiter <- mkAuroraExtArbiterBar(auroraExt119.user, auroraList);

   method Action sendReq(Bit#(32) length, Bit#(5) nodeId);
      sendReq_end.user.send(length, extend(nodeId))
   endmethod
   method ActionValue#(Bit#(5)) sendAck();
      let data <- sendAck_end.user.receive();
      return truncate(tpl_2(data));
   endmethod
   method Action sendDta(Bit#(128) packet, Bit#(5) nodeId);
   endmethod
endmodule
