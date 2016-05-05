import FIFO::*;
import FIFOF::*;
import BRAMFIFO::*;
import MemcachedTypes::*;
import ProtocolHeader::*;
import Connectable::*;
import GetPut::*;
import ClientServer::*;
import ReorderBuffer::*;
import Vector::*;
import MyArbiter::*;
import AuroraEndPointHelper::*;

import ParameterTypes::*;

import BRAM::*;


import ControllerTypes::*;

`ifdef RequestRouteType
typedef `RequestRouteType RequestRouteType;
`else 
typedef 4 RequestRouteType;
`endif
Integer reqRouteType = valueOf(RequestRouteType);

typedef struct{
   Protocol_Binary_Command opcode;
   Bit#(32) hv_val;
   Bit#(32) hv_idx;
   Bit#(8) keylen;
   Bit#(21) bodylen;
   TagT reqId;
   } ReqHeaderEndT deriving (Bits, Eq);

typedef struct{
   TagT srcTag;
   TagT dstTag;
   Bit#(21) bodylen;
   } AckHeaderEndT deriving (Bits, Eq);

typedef struct{
   Protocol_Binary_Request_Header cmd;
   Bit#(32) hv_val;
   Bit#(32) hv_idx;
   TagT localId;
   //Bit#(32) opaque;
   } ReqHeaderT deriving (Bits, Eq);

typedef struct{
   Protocol_Binary_Request_Header cmd;
   Bit#(32) hv_val;
   Bit#(32) hv_idx;
   ReqIdT globalId;
   //Bool isLocal;
   NodeT srcId;
   //Bit#(32) opaque;
   } RespHeaderT deriving (Bits, Eq);

interface ReqEndPointClients;
   interface EndPointClient#(ReqHeaderEndT) req_end;
   interface EndPointClient#(AckHeaderEndT) ack_end;
   interface EndPointClient#(Tuple2#(Tuple2#(Bit#(128), Bool), TagT)) dta_end;
endinterface


interface ReqEndPointServers;
   interface EndPointServer#(ReqHeaderEndT) req_end;
   interface EndPointServer#(AckHeaderEndT) ack_end;
   interface EndPointServer#(Tuple2#(Tuple2#(Bit#(128), Bool), TagT)) dta_end;
endinterface

instance Connectable#(ReqEndPointClients, ReqEndPointServers);
   module mkConnection#(ReqEndPointClients cli, ReqEndPointServers ser)(Empty);
      mkConnection(cli.req_end, ser.req_end);
      mkConnection(cli.ack_end, ser.ack_end);
      mkConnection(cli.dta_end, ser.dta_end);
   endmodule
endinstance


instance Connectable#(ReqEndPointServers, ReqEndPointClients);
   module mkConnection#(ReqEndPointServers ser, ReqEndPointClients cli)(Empty);
      mkConnection(cli.req_end, ser.req_end);
      mkConnection(cli.ack_end, ser.ack_end);
      mkConnection(cli.dta_end, ser.dta_end);
   endmodule
endinstance

interface ReqRouterIfc;
   interface Put#(ReqHeaderT) sendReq;
   interface Get#(RespHeaderT) recvReq;
   interface Put#(Tuple2#(Bit#(128), Bool)) dataInQ;
   interface Get#(Tuple3#(Bit#(8), Bit#(32), TagT)) writeRequest;
   interface Get#(Bit#(128)) keyOut;
   interface Get#(Tuple2#(Bit#(128), Bool)) dataOutQ;
   method Action setNodeIdx(NodeT nodeId);
   interface ReqEndPointClients endpoints;
endinterface

(*synthesize*)
module mkReqRouter(ReqRouterIfc);
   FIFO#(ReqHeaderT) sendReqQ <- mkFIFO();
   //AuroraEndpointIfc#(ReqHeaderEndT) sendReq_end <- mkAuroraEndpointStatic(32, 4);
   FIFO#(Tuple2#(ReqHeaderEndT, NodeT)) sendReq_end_send <- mkFIFO();
   FIFO#(Tuple2#(ReqHeaderEndT, NodeT)) sendReq_end_recv <- mkFIFO();
   //AuroraEndpointIfc#(ReqHeaderEndT) sendAck_end <- mkAuroraEndpointStatic(32, 4);
   FIFO#(Tuple2#(AckHeaderEndT, NodeT)) sendAck_end_send <- mkFIFO();
   FIFO#(Tuple2#(AckHeaderEndT, NodeT)) sendAck_end_recv <- mkFIFO();
   //AuroraEndpointIfc#(Tuple2#(Tuple2#(Bit#(128), Bool), TagT)) sendDta_end <- mkAuroraEndpointStatic(128, 64);
   FIFO#(Tuple2#(Tuple2#(Tuple2#(Bit#(128), Bool), TagT), NodeT)) sendDta_end_send <- mkFIFO();
   FIFO#(Tuple2#(Tuple2#(Tuple2#(Bit#(128), Bool), TagT), NodeT)) sendDta_end_recv <- mkFIFO();
   
   FIFO#(Tuple3#(ReqHeaderEndT, NodeT, Bool)) sendReq_end_send_pre <- mkSizedFIFO(numStages);

   Reg#(NodeT) myNodeId <- mkRegU();
   Reg#(Bool) initialized <- mkReg(False);
   
   
   ReorderBurstBuffer sendBuf <- mkReorderBurstBuffer;

   FIFO#(Tuple2#(Bit#(21), Bool)) inByteQ <- mkFIFO;
   
   FIFOF#(RespHeaderT) localRespQ <- mkFIFOF;
   FIFOF#(RespHeaderT) remoteRespQ_Set <- mkFIFOF;
   FIFOF#(RespHeaderT) remoteRespQ_noSet <- mkFIFOF;
   
   Vector#(3, FIFOF#(RespHeaderT)) respQs = newVector;
   respQs[0] = localRespQ;
   respQs[1] = remoteRespQ_Set;
   respQs[2] = remoteRespQ_noSet;
   Reg#(Bit#(32)) reqCnt_doSendReq <- mkReg(0);
   
   FIFO#(Tuple3#(Bit#(8), Bit#(32), TagT)) writeRequestQ <- mkFIFO();
   FIFO#(Bit#(128)) keyOutQ <- mkFIFO;
   FIFO#(Tuple2#(ReqHeaderT, NodeT)) sendReqQ_dstNode<- mkFIFO();
   rule doDstNode;
      let req <- toGet(sendReqQ).get();
      NodeT dstNode = ?;
      
      if ( reqRouteType == 4) begin
         dstNode = truncate(req.hv_val % 4) + 5;
      end
      else if ( reqRouteType == 3) begin
         dstNode = truncate(req.hv_val % 3) + 5;
      end
      else if ( reqRouteType == 2) begin
         dstNode = truncate(req.hv_val % 2) + 5;
      end
      else if ( reqRouteType == 1 ) begin
         dstNode = 6;
         //if ( myNodeId == 5 ) dstNode = 6;
      end
      else if ( reqRouteType == 0 ) begin
         dstNode = myNodeId;
      end
      if ( req.cmd.opcode == PROTOCOL_BINARY_CMD_EOM ) dstNode = myNodeId;
      
      sendReqQ_dstNode.enq(tuple2(req, dstNode));
      
   endrule
   
   rule doSendReq;
      let d <- toGet(sendReqQ_dstNode).get();
      let req = tpl_1(d);
      let dstNode = tpl_2(d);
         
      
     //NodeT dstNode = truncate(req.hv_val);
      $display("%m: get request dstNode = %d, myNodeId = %d, opcode = %h, reqCnt = %d", dstNode, myNodeId, req.cmd.opcode, reqCnt_doSendReq);
      reqCnt_doSendReq <= reqCnt_doSendReq + 1;
      if ( dstNode != myNodeId && req.cmd.opcode != PROTOCOL_BINARY_CMD_EOM ) begin
         //if remote, request sent to the remote node
         //sendReq_end.user.send(ReqHeaderEndT{opcode: req.cmd.opcode, hv_val:req.hv_val, hv_idx: req.hv_idx, bodylen: truncate(req.cmd.bodylen), tag:req.tag}, req.dstNode);
         Bool doReserve = False;
         if ( req.cmd.opcode == PROTOCOL_BINARY_CMD_SET ) begin
            // if set, the key value pairs are sent to remote node
            sendBuf.enqReq(req.localId, truncate(req.cmd.bodylen));
            inByteQ.enq(tuple2(truncate(req.cmd.bodylen), False));
            // localRespQ.enq(RespHeaderT{cmd: req.cmd, hv_val:req.hv_val, hv_idx: req.hv_idx, globalId: ReqIdT{nodeId: dstNode, tagId: req.localId}, srcId: myNodeId});
            //writeRequestQ.enq(tuple3(0, cmd.opaque, reqId.tagId));
            doReserve = True;
         end
         else begin
            // if get or delete, the keys are buffed in to local buffers;
            inByteQ.enq(tuple2(truncate(req.cmd.bodylen), True));
            //writeRequestQ.enq(tuple3(truncate(cmd.keylen), cmd.opaque, reqId.tagId));
            //localRespQ.enq(RespHeaderT{cmd: req.cmd, hv_val:req.hv_val, hv_idx: req.hv_idx, globalId: ReqIdT{nodeId: dstNode, tagId: req.localId}, isLocal: True});
            // localRespQ.enq(RespHeaderT{cmd: req.cmd, hv_val:req.hv_val, hv_idx: req.hv_idx, globalId: ReqIdT{nodeId: dstNode, tagId: req.localId}, srcId: myNodeId});
         end
         sendReq_end_send_pre.enq(tuple3(ReqHeaderEndT{opcode: req.cmd.opcode, hv_val:req.hv_val, hv_idx: req.hv_idx, keylen: truncate(req.cmd.keylen), bodylen: truncate(req.cmd.bodylen), reqId:req.localId}, dstNode, doReserve));
      end
      else begin
         //local
         inByteQ.enq(tuple2(truncate(req.cmd.bodylen), True));
         //localRespQ.enq(RespHeaderT{cmd: req.cmd, hv_val:req.hv_val, hv_idx: req.hv_idx, globalId: ReqIdT{nodeId: dstNode, tagId: req.localId}, isLocal: True});
         //localRespQ.enq(RespHeaderT{cmd: req.cmd, hv_val:req.hv_val, hv_idx: req.hv_idx, globalId: ReqIdT{nodeId: dstNode, tagId: req.localId}, srcId: myNodeId});
         localRespQ.enq(RespHeaderT{cmd: req.cmd, hv_val:req.hv_val, hv_idx: req.hv_idx, globalId: ReqIdT{nodeId: myNodeId, tagId: req.localId}, srcId: myNodeId});
      end
      
      if ( req.cmd.opcode == PROTOCOL_BINARY_CMD_SET ) begin
         writeRequestQ.enq(tuple3(0, req.cmd.opaque, req.localId));         
      end
      else begin
         writeRequestQ.enq(tuple3(truncate(req.cmd.keylen), req.cmd.opaque, req.localId));
      end
   endrule
   
   
   rule doRemoteReq;
      let d <- toGet(sendReq_end_send_pre).get();
      if ( tpl_3(d) )
         let dummy <- sendBuf.enqResp();
      sendReq_end_send.enq(tuple2(tpl_1(d), tpl_2(d)));
   endrule
   
   Reg#(Bit#(21)) byteCnt_enq <- mkReg(0);
   
   FIFO#(Tuple2#(Bit#(128), Bool)) localDtaQ <- mkFIFO();
   
   //FIFO#(Tuple2#(Bit#(128), Bool)) inDtaQ <- mkFIFO();
   FIFO#(Tuple2#(Bit#(128), Bool)) inDtaQ <- mkSizedBRAMFIFO(128);
   Reg#(Bit#(32)) reqCnt <- mkReg(0);
   rule enqData;
      let v = inByteQ.first();
      let byteMax = tpl_1(v);
      let isLocal = tpl_2(v);
     
      if ( byteCnt_enq + 16 < byteMax) begin
         byteCnt_enq <= byteCnt_enq + 16;
      end
      else begin
         byteCnt_enq <= 0;
         inByteQ.deq();
         reqCnt <= reqCnt + 1;
      end
      

      if ( byteMax > 0 ) begin
         let d <- toGet(inDtaQ).get();
         $display("%m:: enqData byteCnt_enq = %d, byteMax = %d, isLocal = %d, data = %h, reqCnt = %d", byteCnt_enq, byteMax, isLocal, d, reqCnt);   
         if ( isLocal) begin
            if ( tpl_2(d) ) 
               keyOutQ.enq(tpl_1(d));
            else
               localDtaQ.enq(d);            
         end
         else begin
            sendBuf.inPipe.put(d);
         end
      end
   endrule
   
   FIFO#(Tuple3#(Bit#(21), TagT,  NodeT)) dtaDstQ <- mkFIFO();
   rule recvRemoteAck;
      //let v <- sendAck_end.user.receive;
      let v <- toGet(sendAck_end_recv).get();
      let req = tpl_1(v);
      let src = tpl_2(v);
      $display("%m:: receive acknowedge from remote node = %d, myNodeId = %d, srcTag = %d, bodylen = %d, dstTag = %d", src, myNodeId, req.srcTag, req.bodylen, req.dstTag);
      sendBuf.deqReq(req.srcTag, req.bodylen);
      dtaDstQ.enq(tuple3(req.bodylen, req.dstTag, src));
   endrule
   
   Reg#(Bit#(21)) byteCnt_deq <- mkReg(0);
   Reg#(Bit#(32)) reqCnt_doSendDta <- mkReg(0);
   rule doSendDta;
      let v = dtaDstQ.first();
      let byteMax = tpl_1(v);
      let dstTag = tpl_2(v);
      let dst = tpl_3(v);

      if ( byteCnt_deq + 16 < byteMax ) begin
         byteCnt_deq <= byteCnt_deq + 16;
      end
      else begin
         byteCnt_deq <= 0;
         dtaDstQ.deq();
         reqCnt_doSendDta <= reqCnt_doSendDta + 1;
      end
      
      let d <- sendBuf.outPipe.get();
      $display("%m:: send data to remote node = %d, myNodeId = %d, dstTag = %d, byteCnt_deq = %d, byteMax = %d, reqCnt = %d, data = %h", dst, myNodeId, dstTag, byteCnt_deq, byteMax, reqCnt_doSendDta, tpl_1(d));
      //sendDta_end.user.send(tuple2(d, dstTag), dst);
      sendDta_end_send.enq(tuple2(tuple2(d, dstTag), dst));
   endrule
   
   ReorderBuffer recvBuf <- mkReorderBuffer;
   FIFO#(Tuple3#(ReqHeaderEndT,NodeT, Bool)) reserve2ack <- mkFIFO();
   Reg#(Bit#(32)) reqCnt_recvRemoteReq <- mkReg(0);
   rule recvRemoteReq;
      //let v <- sendReq_end.user.receive;

      let v <- toGet(sendReq_end_recv).get();
      let req = tpl_1(v);
      let src = tpl_2(v);
      $display("%m:: receive request from remote node = %d, myNodeId = %d, opcode = %h, keylen = %d, bodylen = %d, reqCnt = %d", src, myNodeId, req.opcode, req.keylen, req.bodylen, reqCnt_recvRemoteReq);
      reqCnt_recvRemoteReq <= reqCnt_recvRemoteReq + 1;
      if ( req.opcode == PROTOCOL_BINARY_CMD_SET ) begin
         recvBuf.reserveServer.request.put(req.bodylen);
         reserve2ack.enq(tuple3(req, src, True));
      end
      else begin
         reserve2ack.enq(tuple3(req, src, False));
      end
   endrule

   //FIFO#(Maybe#(TagT)) recvBufDeqTag <- mkFIFO;
   FIFO#(Tuple2#(TagT, Bool)) recvBufDeqTag <- mkFIFO;
   Reg#(Bit#(32)) reqCnt_sendAck <- mkReg(0);
   
   BRAM2Port#(TagT, Tuple6#(Bit#(8), Bit#(21), Bit#(32), Bit#(32), ReqIdT, NodeT)) respTable <- mkBRAM2Server(defaultValue);
   rule sendAck;

      let v <- toGet(reserve2ack).get();
      let req = tpl_1(v);
      let src = tpl_2(v);
      let doReserve = tpl_3(v);
      $display("%m:: send acknowledge to remote node = %d, myNodeId = %d, opcode = %h, keylen = %d, bodylen = %d, doReserve = %d, reqCnt = %d", src, myNodeId, req.opcode, req.keylen, req.bodylen, doReserve, reqCnt_sendAck);
      reqCnt_sendAck <= reqCnt_sendAck + 1;
      //Maybe#(TagT) deqTag = tagged Invalid;
      TagT deqTag = ?;
      if ( doReserve) begin
         //let tag <- recvBuf.reserveServer.response.get;
         deqTag <- recvBuf.reserveServer.response.get;
         $display("%m:: receive buffer tag = %d", deqTag);
         //sendAck_end.user.send(AckHeaderEndT{srcTag: req.tag, bodylen: req.bodylen, dstTag: tag}, src);
         sendAck_end_send.enq(tuple2(AckHeaderEndT{srcTag: req.reqId, bodylen: req.bodylen, dstTag: deqTag}, src));
         //deqTag = tagged Valid tag;
      end
      Protocol_Binary_Request_Header cmd = unpack(0);
      cmd.magic = PROTOCOL_BINARY_REQ;
      cmd.opcode = req.opcode;
      cmd.keylen = extend(req.keylen);
      cmd.bodylen = extend(req.bodylen);
      //remoteRespQ.enq(RespHeaderT{cmd: cmd, hv_val:req.hv_val, hv_idx: req.hv_idx, globalId: ReqIdT{nodeId: src, tagId: req.reqId}, isLocal: False});
      
      let retval = RespHeaderT{cmd: cmd, hv_val:req.hv_val, hv_idx: req.hv_idx, globalId: ReqIdT{nodeId: myNodeId, tagId: req.reqId}, srcId: src};
      if ( doReserve) begin
         respTable.portA.request.put(BRAMRequest{write: True,
                                                 responseOnWrite: False,
                                                 address: deqTag,
                                                 datain: tuple6(req.keylen, req.bodylen, req.hv_val, req.hv_idx, ReqIdT{nodeId: myNodeId, tagId: req.reqId}, src)});
      end
      else begin
         remoteRespQ_noSet.enq(retval);
      end
      //recvBufDeqTag.enq(deqTag);
      //recvBufDeqTag.enq(tuple2(deqTag, doReserve));
   endrule
   
   FIFO#(TagT) deqTagQ <- mkSizedFIFO(4);
   rule doDeqReady;
      let deqTag <- recvBuf.deqReady.get();
      respTable.portB.request.put(BRAMRequest{write: False,
                                              responseOnWrite: False,
                                              address: deqTag,
                                              datain: ?});
      deqTagQ.enq(deqTag);
      
   endrule
   
   rule doRemoteRespBurst;
      let d <- respTable.portB.response.get();
      let deqTag <- toGet(deqTagQ).get();
      let keylen = tpl_1(d);
      let bodylen = tpl_2(d);
      let hv_val = tpl_3(d);
      let hv_idx = tpl_4(d);
      let globalId = tpl_5(d);
      let srcId = tpl_6(d);
      
      Protocol_Binary_Request_Header cmd = unpack(0);
      cmd.magic = PROTOCOL_BINARY_REQ;
      cmd.opcode = PROTOCOL_BINARY_CMD_SET;
      cmd.keylen = extend(keylen);
      cmd.bodylen = extend(bodylen);
      
      remoteRespQ_Set.enq(RespHeaderT{cmd: cmd, hv_val:hv_val, hv_idx: hv_idx, globalId: globalId, srcId: srcId});
      //recvBufDeqTag.enq(tuple2(deqTag, doReserve));
      recvBuf.deqReq(deqTag, bodylen);            
   endrule

   
   Reg#(Bit#(32)) byteCnt <- mkReg(0);
   rule recvRemoteDta;
      //let v <- sendDta_end.user.receive();
      let v <- toGet(sendDta_end_recv).get();
      let d = tpl_1(v);
      let src = tpl_2(v);
      let data = tpl_1(d);
      let tag = tpl_2(d);
      byteCnt <= byteCnt + 16;
      $display("%m:: receive remote data from node = %d, myNodeId = %d, recvBuf tag = %d, data = %h, byteCnt = %d", src, myNodeId, tag, tpl_1(data), byteCnt);
      recvBuf.inData(tag, data);
   endrule
   
   Arbiter_IFC#(3) arbiter <- mkArbiter(False);
   FIFO#(RespHeaderT) respQ <- mkFIFO();
   FIFO#(Tuple2#(Bit#(1), Bit#(21))) deqReqQ <- mkFIFO();
   //FIFO#() dtaDeq <- mkFIFO();
   Reg#(Bit#(32)) reqCnt_arbResp <- mkReg(0);
   for ( Integer i = 0; i < 3; i = i + 1) begin
      rule doArbReq if ( respQs[i].notEmpty);
         arbiter.clients[i].request();
      endrule
      
      rule doArbResp if ( arbiter.grant_id == fromInteger(i) ) ;
         let resp <- toGet(respQs[i]).get();
         respQ.enq(resp);
         reqCnt_arbResp <= reqCnt_arbResp + 1;
         if (i == 0) begin
            //if ( (resp.globalId.nodeId == myNodeId) || (resp.cmd.opcode == PROTOCOL_BINARY_CMD_GET)) begin
            if ( resp.cmd.opcode == PROTOCOL_BINARY_CMD_SET ) begin
               $display("%m:: deqReq from local note, bodylen = %d, reqId = %d, reqCnt = %d", resp.cmd.bodylen, resp.globalId.tagId, reqCnt_arbResp);
               deqReqQ.enq(tuple2(0, truncate(resp.cmd.bodylen)));
            end
            else begin
               $display("%m:: deqReq from local note, bodylen = %d, reqId = %d, reqCnt = %d", 0, resp.globalId.tagId, reqCnt_arbResp);
               deqReqQ.enq(tuple2(0, 0));
            end
         end
         else begin

            if ( i == 1) begin
               $display("%m:: deqReq from remote note, with data, bodylen = %d, reqCnt = %d", resp.cmd.bodylen, reqCnt_arbResp);
               deqReqQ.enq(tuple2(1, truncate(resp.cmd.bodylen)));
            end
            else begin
               $display("%m:: deqReq from remote note, without data, bodylen = %d, reqCnt = %d", resp.cmd.bodylen, reqCnt_arbResp);
               deqReqQ.enq(tuple2(1, 0));
            end
            //let ops <- toGet(recvBufDeqTag).get();
            // let v <- toGet(recvBufDeqTag).get();
            // let tag = tpl_1(v);
            // let reserved = tpl_2(v);
            // //if ( isValid(ops) ) begin
            // if ( reserved ) begin
            //    $display("%m:: deqReq from remote note, with data, bodylen = %d, tag = %d, reqCnt = %d", resp.cmd.bodylen, tag, reqCnt_arbResp);
            //    deqReqQ.enq(tuple2(1, truncate(resp.cmd.bodylen)));
            //    //recvBuf.deqReq(fromMaybe(?, ops), truncate(resp.cmd.bodylen));
            //    recvBuf.deqReq(tag, truncate(resp.cmd.bodylen));
            // end
            // else begin
            //    $display("%m:: deqReq from remote note, without data, bodylen = %d, reqCnt = %d", 0, resp.globalId.tagId, reqCnt_arbResp);
            //    deqReqQ.enq(tuple2(1, 0));
            // end
         end
      endrule
   end
   
   Reg#(Bit#(21)) dtaByteCnt <- mkReg(0);
   
   FIFO#(Tuple2#(Bit#(128), Bool)) outDtaQ <- mkFIFO();
   //FIFO#(Tuple2#(Bit#(128), Bool)) outDtaQ <- mkSizedBRAMFIFO(128);
   Reg#(Bit#(32)) reqCnt_doDtaSwitch <- mkReg(0);
   rule doDtaSwitch;
      let v = deqReqQ.first();
      let maxByte = tpl_2(v);
      let src = tpl_1(v);
      if ( dtaByteCnt + 16 >= maxByte ) begin
         deqReqQ.deq();
         dtaByteCnt <= 0;
         reqCnt_doDtaSwitch <= reqCnt_doDtaSwitch + 1;
      end
      else begin
         dtaByteCnt <= dtaByteCnt + 16;
      end
      $display("%m:: do dataswitch, dtaByteCnt = %d, maxByte = %d, fromRemote = %d, reqCnt = %d", dtaByteCnt, maxByte, src, reqCnt_doDtaSwitch);
      if ( maxByte > 0 ) begin
         if ( src == 0 ) begin
            let d <- toGet(localDtaQ).get();
            outDtaQ.enq(d);
         end
         else begin
            let d <- recvBuf.outPipe.get();
            outDtaQ.enq(d);
         end
      end
         
   endrule
   
   interface Put sendReq = toPut(sendReqQ);
   interface Get recvReq = toGet(respQ);
   interface Put dataInQ = toPut(inDtaQ);
   
   interface Get writeRequest = toGet(writeRequestQ);
   interface Get keyOut = toGet(keyOutQ);

   interface Get dataOutQ = toGet(outDtaQ);
   
   method Action setNodeIdx(NodeT nodeId);
      myNodeId <= nodeId;
   endmethod
   interface ReqEndPointClients endpoints;
      interface EndPointClient req_end = toEndPointClient(sendReq_end_send, sendReq_end_recv);
      interface EndPointClient ack_end = toEndPointClient(sendAck_end_send, sendAck_end_recv);
      interface EndPointClient dta_end = toEndPointClient(sendDta_end_send, sendDta_end_recv);
   endinterface

endmodule
