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

typedef Bit#(5) NodeT;

typedef struct{
   Bit#(32) hv_val;
   Bit#(32) hv_idx;
   Bit#(21) bodylen;
   TagT tag;
   } ReqHeaderEndT deriving (Bits, Eq);

typedef struct{
   Bit#(32) hv_val;
   Bit#(32) hv_idx;
   Bit#(21) bodylen;
   NodeT dstNode;
   TagT tag;
   } ReqHeaderT deriving (Bits, Eq);
               

interface RouterIfc;
   interface Put#(ReqHeaderT) sendReq;
   interface Get#(ReqHeaderT) recvReq;
   interface Put#(Tuple2#(Bit#(128), Bool)) dataInQ;
   interface Get#(Tuple2#(Bit#(128), Bool)) dataOutQ;
endinterface

module mkRouter(Vector#(tExtCount, AuroraExtUserIfc) extPorts);
   AuroraEndpointIfc#(ReqHeaderEndT) sendReq_end <- mkAuroraEndpointStatic(32, 4);
   AuroraEndpointIfc#(Bool) sendAck_end <- mkAuroraEndpointStatic(32, 4);
   AuroraEndpointIfc#(Bit#(128)) sendDta_end <- mkAuroraEndpointStatic(128, 64);

   let auroraList = cons(sendDta_end.cmd, cons(sendAck_end.cmd, cons(sendReq_end.cmd, nil)));
   AuroraExtArbiterBarIfc auroraExtArbiter <- mkAuroraExtArbiterBar(auroraExt119.user, auroraList);
   
   Reg#(NodeT) myNodeId <- mkRegU();
   Reg#(Bool) initialized <- mkReg(False);
   
   FIFO#(ReqHeaderT) sendReqQ <- mkFIFO();

   rule doSendReq;
      let req <- toGet(sendReqQ).get();
      if ( req.disNode == myNodeId ) begin
         //local
      end
      else begin
         sendReq_end.user.send(ReqHeaderEndT{hv_val:req.hv_val, hv_idx: req.hv_idx, bodylen: req.bodylen, tag:req.tag}, req.dstNode);
      end
   endrule

   
   interface Put sendReq = toPut(sendReqQ);
   interface Get recvReq;
   interface Put dataInQ;
   interface Get dataOutQ;
endmodule
