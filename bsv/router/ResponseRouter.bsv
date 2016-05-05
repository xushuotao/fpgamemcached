import FIFO::*;
import FIFOF::*;
import TagAlloc::*;
import MemcachedTypes::*;
import ProtocolHeader::*;
import Connectable::*;
import GetPut::*;
import ReorderBuffer::*;
import Vector::*;
import BRAM::*;
import MyArbiter::*;
import AuroraEndPointHelper::*;
import ParameterTypes::*;


import ControllerTypes::*;

typedef struct{
   Protocol_Binary_Command opcode; // 8 bit
   Protocol_Binary_Response_Status status; // 16 bit
   Bit#(8) keylen;
   Bit#(21) bodylen;
   TagT reqId;
   TagT srcTag;
   //Bit#(32) opaque;
   } RouterHeaderT deriving (Bits, Eq);

typedef struct{
   Bit#(8) keylen;
   Bit#(21) bodylen;
   TagT srcTag;
   TagT dstTag;
   } RouterAckT deriving (Bits, Eq);


typedef struct{
   Protocol_Binary_Command opcode;
   Protocol_Binary_Response_Status status;
   ReqIdT globalId;
   Bit#(8) keylen;
   Bit#(21) bodylen;
   Bit#(32) opaque;
   NodeT srcId;
   } RouterReqT deriving (Bits, Eq);

typedef struct{
   Protocol_Binary_Response_Header respHeader;
   TagT reqId;
   } RouterRespT deriving (Bits, Eq);

interface RespEndPointClients;
   interface EndPointClient#(RouterHeaderT) req_end;
   interface EndPointClient#(RouterAckT) ack_end;
   interface EndPointClient#(Tuple2#(Bit#(128), TagT)) dta_end;
endinterface


interface RespEndPointServers;
   interface EndPointServer#(RouterHeaderT) req_end;
   interface EndPointServer#(RouterAckT) ack_end;
   interface EndPointServer#(Tuple2#(Bit#(128), TagT)) dta_end;
endinterface


instance Connectable#(RespEndPointClients, RespEndPointServers);
   module mkConnection#(RespEndPointClients cli, RespEndPointServers ser)(Empty);
      mkConnection(cli.req_end, ser.req_end);
      mkConnection(cli.ack_end, ser.ack_end);
      mkConnection(cli.dta_end, ser.dta_end);
   endmodule
endinstance


instance Connectable#(RespEndPointServers, RespEndPointClients);
   module mkConnection#(RespEndPointServers ser, RespEndPointClients cli)(Empty);
      mkConnection(cli.req_end, ser.req_end);
      mkConnection(cli.ack_end, ser.ack_end);
      mkConnection(cli.dta_end, ser.dta_end);
   endmodule
endinstance

interface RespRouterIfc;
   interface Put#(RouterReqT) sendReq;
   interface Get#(TagT) getTag;
   interface Put#(TagT) burstReq;
   interface Put#(Bit#(128)) dataInQ;
   interface Get#(RouterRespT) recvIOReq;
   interface Get#(RouterRespT) recvOOReq;
   interface Get#(Bit#(128)) dataOutQ;
   method Action setNodeIdx(NodeT myId);
   interface RespEndPointClients endpoints;
endinterface

(*synthesize*)
module mkRespRouter(RespRouterIfc);
   FIFO#(RouterReqT) sendReqQ <- mkSizedFIFO(numStages);
   
   Vector#(2,FIFOF#(Tuple2#(RouterHeaderT, NodeT))) sendReq_end_sends <- replicateM(mkFIFOF());   
   FIFO#(Tuple2#(RouterHeaderT, NodeT)) sendReq_end_send_pre <- mkSizedFIFO(numStages);
   FIFO#(Tuple2#(RouterHeaderT, NodeT)) sendReq_end_send <- mkFIFO();


   FIFO#(Tuple2#(RouterHeaderT, NodeT)) sendReq_end_recv <- mkFIFO();
   //AuroraEndpointIfc#(ReqHeaderEndT) sendAck_end <- mkAuroraEndpointStatic(32, 4);
   FIFO#(Tuple2#(RouterAckT, NodeT)) sendAck_end_send <- mkFIFO();
   FIFO#(Tuple2#(RouterAckT, NodeT)) sendAck_end_recv <- mkFIFO();
   //AuroraEndpointIfc#(Tuple2#(Tuple2#(Bit#(128), Bool), TagT)) sendDta_end <- mkAuroraEndpointStatic(128, 64);
   FIFO#(Tuple2#(Tuple2#(Bit#(128), TagT), NodeT)) sendDta_end_send <- mkFIFO();//mkSizedFIFO(10240);
   FIFO#(Tuple2#(Tuple2#(Bit#(128), TagT), NodeT)) sendDta_end_recv <- mkFIFO();//mkSizedFIFO(10240);

   Reg#(NodeT) myNodeId <- mkRegU();
   Reg#(Bool) initialized <- mkReg(False);
      
   //ReorderBuffer sendBuf <- mkReorderBuffer;
   ReorderBurstBuffer sendBuf <- mkReorderBurstBuffer;

   
   FIFOF#(RouterRespT) inOrderlocalRespQ <- mkFIFOF;
   // FIFOF#(RouterRespT) outOrderlocalRespQ <- mkFIFOF;
   // FIFOF#(RouterRespT) remoteRespQ <- mkFIFOF;

   
   Vector#(3, FIFOF#(RouterRespT)) respOOQs <- replicateM(mkSizedFIFOF(numStages));
   FIFOF#(RouterRespT) outOrderlocalRespQ = respOOQs[0];
   FIFOF#(RouterRespT) remoteRespQ_1 = respOOQs[1];
   FIFOF#(RouterRespT) remoteRespQ_2 = respOOQs[2];

   // respOOQs[0] = outOrderlocalRespQ;
   // respOOQs[1] = remoteRespQ;

//   FIFO#(Tuple4#(Bool, Bit#(8), Bit#(21), TagT)) inByteQ <- mkFIFO;
   FIFO#(Tuple2#(Bool, RouterReqT)) inByteQ <- mkSizedFIFO(numStages);
   //FIFO#(Tuple5#(Bool, Bit#(8), Bit#(21), TagT, Bit#(32))) inByteQ <- mkFIFO;
   
   //BRAM2Port#(TagT, Tuple4#(Bool, Bit#(8), Bit#(21), TagT)) cmplTable <- mkBRAM2Server(defaultValue);
   //BRAM2Port#(TagT, Tuple5#(Bool, Bit#(8), Bit#(21), TagT, Bit#(32))) cmplTable <- mkBRAM2Server(defaultValue);
   
   Reg#(Bit#(32)) counter <- mkReg(0);
   rule incrCnt;
      counter <= counter + 1;
   endrule


   
   TagServer tagServer <- mkTagAlloc;
   Reg#(Bit#(32)) reqCnt_doSendReq <- mkReg(0);
   rule doSendReq;
      let req <- toGet(sendReqQ).get();
      //let nodeId = req.globalId.nodeId;
      let nodeId = req.srcId;
      let isLocal = True;
      $display("%m:: got response locally, nodeId = %d, myNodeId = %d, opcode = %h, keylen = %d, bodylen = %d, reqCnt = %d", nodeId, myNodeId, req.opcode, req.keylen, req.bodylen, reqCnt_doSendReq);
      reqCnt_doSendReq <= reqCnt_doSendReq + 1;
      if ( nodeId == myNodeId ) begin
         let respHdr = Protocol_Binary_Response_Header{magic: PROTOCOL_BINARY_RES,
                                                       opcode: req.opcode,
                                                       keylen: extend(req.keylen),
                                                       extlen: 0,
                                                       datatype: 0,
                                                       status: req.status,
                                                       bodylen: extend(req.bodylen),
                                                       opaque: req.opaque,
                                                       cas: 0
                                                       };
         if ( req.opcode != PROTOCOL_BINARY_CMD_GET || req.status != PROTOCOL_BINARY_RESPONSE_SUCCESS ) begin
            inOrderlocalRespQ.enq(RouterRespT{respHeader: respHdr,
                                              reqId: req.globalId.tagId});
         end
      end
      else begin
         if ( req.opcode != PROTOCOL_BINARY_CMD_GET || req.status != PROTOCOL_BINARY_RESPONSE_SUCCESS ) begin
            sendReq_end_sends[1].enq(tuple2(RouterHeaderT{opcode: req.opcode,
                                                          status: req.status,
                                                          keylen: req.keylen,
                                                          bodylen: req.bodylen,
                                                          reqId: req.globalId.tagId,
                                                          srcTag: ?},
                                            nodeId));
            end

                                                   //opaque: req.opaque},
                                     //req.globalId.nodeId));
      
         // if ( req.opcode == PROTOCOL_BINARY_CMD_GET ) begin
         //    sendBuf.reserveServer.request.put(req.bodylen);
         // end
         isLocal = False;
      end
      
      if ( req.bodylen > 0 ) begin
         $display("%m, request for new tag");
         tagServer.reqTag.request.put(1);
         //inByteQ.enq(tuple5(isLocal, req.keylen, req.bodylen, req.globalId.tagId, req.opaque));
      end
      //inByteQ.enq(tuple4(isLocal, req.keylen, req.bodylen, req.globalId.tagId));
      inByteQ.enq(tuple2(isLocal, req));
      
   endrule
   
   //FIFO#(TagT) respTagQ <- mkSizedFIFO(numStages);
   FIFO#(TagT) respTagQ <- mkSizedFIFO(128);
   Reg#(Bit#(32)) reqCnt_writeCmplTable <- mkReg(0);
   BRAM2Port#(TagT, Tuple6#(Protocol_Binary_Command, Protocol_Binary_Response_Status, Bit#(8), Bit#(21), ReqIdT, NodeT)) cmplTable <- mkBRAM2Server(defaultValue);
   rule writeCmplTable;
      let v <- toGet(inByteQ).get();
      let isLocal = tpl_1(v);
      let req = tpl_2(v);
      // let keylen = tpl_2(v);
      // let bodylen = tpl_3(v);
      // let bufTag = tpl_4(v);
      let keylen = req.keylen;
      let bodylen = req.bodylen;
      let bufTag = req.globalId.tagId;
      let nodeId = req.srcId;
      //let localTag = tpl_3(v);
      //let opaque = tpl_5(v);
      $display("%m:: locally got request stage 2 preparing response, isLocal = %d, nodeId = %d, myNodeId = %d, opcode = %h, keylen = %d, bodylen = %d, reqCnt = %d", isLocal, nodeId, myNodeId, req.opcode, req.keylen, req.bodylen, reqCnt_writeCmplTable);
      reqCnt_writeCmplTable <= reqCnt_writeCmplTable + 1;
      // if ( !isLocal ) begin
      //    if ( req.bodylen > 0 ) begin
      //       bufTag <- sendBuf.reserveServer.response.get();
      //    end
      //    sendReq_end_send.enq(tuple2(RouterHeaderT{opcode: req.opcode,
      //                                              status: req.status,
      //                                              keylen: req.keylen,
      //                                              bodylen: req.bodylen,
      //                                              reqId: req.globalId.tagId,
      //                                              srcTag: bufTag},
      //                                nodeId));
      // end
      
      if ( bodylen > 0 ) begin
         $display("%m, got a new tag");
         let reqTag <- tagServer.reqTag.response.get();
         respTagQ.enq(reqTag);
         cmplTable.portA.request.put(BRAMRequest{write: True,
                                                 responseOnWrite: False,
                                                 address: reqTag,
                                                 //datain: tuple4(isLocal, keylen, bodylen, bufTag)});
                                                 datain: tuple6(req.opcode, req.status, req.keylen, req.bodylen, req.globalId, req.srcId)});
                                                 
      end
      //datain: tuple5(isLocal, keylen, bodylen, bufTag, opaque)});
   endrule
   
   FIFO#(TagT) burstReqQ <- mkSizedFIFO(numStages);
   FIFO#(TagT) tagQ_0 <- mkSizedFIFO(numStages);
   rule reqCmplTable;
      let reqTag <- toGet(burstReqQ).get();
      cmplTable.portB.request.put(BRAMRequest{write: False,
                                              responseOnWrite: False,
                                              address: reqTag,
                                              datain: ?});
      //tagServer.retTag.put(reqTag);
      tagQ_0.enq(reqTag);
   endrule
   
   FIFO#(Tuple6#(Protocol_Binary_Command, Protocol_Binary_Response_Status, Bit#(8), Bit#(21), ReqIdT, NodeT)) cmplTableRespQ <- mkSizedFIFO(numStages);
   //mkConnection(toPut(cmplTableRespQ), cmplTable.portB.response);
      
   FIFO#(Bit#(128)) localDtaQ <- mkFIFO();
   
   FIFO#(Bit#(128)) inDtaQ <- mkFIFO();

   FIFO#(TagT) sendBufTagQ <- mkSizedFIFO(numStages);
   rule doOOResp;
      let v <- cmplTable.portB.response.get();
      cmplTableRespQ.enq(v);
      let opcode = tpl_1(v);
      let status = tpl_2(v);
      let keylen = tpl_3(v);
      let bodylen = tpl_4(v);
      let globalId = tpl_5(v);
      let nodeId = tpl_6(v);
      
      let tag <- toGet(tagQ_0).get();
      
      if ( nodeId == myNodeId ) begin
         outOrderlocalRespQ.enq(RouterRespT{respHeader: Protocol_Binary_Response_Header{magic: PROTOCOL_BINARY_RES,
                                                                                        opcode: PROTOCOL_BINARY_CMD_GET,
                                                                                        keylen: extend(keylen),
                                                                                        extlen: 0,
                                                                                        datatype: 0,
                                                                                        status: status,
                                                                                        bodylen: extend(bodylen),
                                                                                        opaque: ?,//opaque,
                                                                                        cas: 0
                                                                                        },
                                            reqId: globalId.tagId});
      end
      else begin
         if ( opcode == PROTOCOL_BINARY_CMD_GET && status == PROTOCOL_BINARY_RESPONSE_SUCCESS ) begin
            //sendBuf.reserveServer.request.put(bodylen);
            sendBuf.enqReq(tag, truncate(bodylen));
            sendReq_end_send_pre.enq(tuple2(RouterHeaderT{opcode: opcode,
                                                      status: status,
                                                      keylen: keylen,
                                                      bodylen: bodylen,
                                                      reqId: globalId.tagId,
                                                      srcTag: tag},
                                        nodeId));

         end
      end
      sendBufTagQ.enq(tag);
   endrule
      
   Reg#(Bit#(21)) byteCnt_enq <- mkReg(0);
   Reg#(Bit#(32)) reqCnt <- mkReg(0);
   
   //FIFO#(TagT) sendBufTagQ <- mkFIFO();
   //mkConnection(toPut(sendBufTagQ), sendBuf.reserveServer.response);

   rule doEnqData;
      let v = cmplTableRespQ.first();
      let opcode = tpl_1(v);
      let status = tpl_2(v);
      let keylen = tpl_3(v);
      let bodylen = tpl_4(v);
      let globalId = tpl_5(v);
      let nodeId = tpl_6(v);
      
      Bool isLocal = (nodeId == myNodeId);
      TagT bufTag = ?;
      //if ( !isLocal) begin
      bufTag = sendBufTagQ.first();
      //end
         //let bufTag <- sendBuf.reserveServer.response.get();

      if ( byteCnt_enq + 16 < bodylen ) begin
         byteCnt_enq <= byteCnt_enq + 16;
      end
      else begin
         byteCnt_enq <= 0;
         cmplTableRespQ.deq();
         tagServer.retTag.put(bufTag);
         //if ( !isLocal) 
         sendBufTagQ.deq();
         reqCnt <= reqCnt + 1;
      end
      
      let d <- toGet(inDtaQ).get();
      $display("%m:: enqData byteCnt_enq = %d, byteMax = %d, isLocal = %d, tag = %d, data = %h, reqCnt = %d", byteCnt_enq, bodylen, isLocal, bufTag, d, reqCnt);
      if ( isLocal) begin
         localDtaQ.enq(d);
      end
      else begin
         //sendBuf.inData(bufTag, tuple2(d,?));
         //sendBuf.inData(bufTag, tuple2(d,?));
         sendBuf.inPipe.put(tuple2(d,?));
      end
      
      if ( byteCnt_enq == 0 ) begin
         if ( !isLocal ) begin
            //
            // sendReq_end_send_pre.enq(tuple2(RouterHeaderT{opcode: opcode,
            //                                           status: status,
            //                                           keylen: keylen,
            //                                           bodylen: bodylen,
            //                                           reqId: globalId.tagId,
            //                                           srcTag: bufTag},
            //                             nodeId));
         end
      end
   endrule
   
   
   rule doRemoteReq;
      let d <- toGet(sendReq_end_send_pre).get();
      let dummy <- sendBuf.enqResp();
      sendReq_end_sends[0].enq(d);
      let req = tpl_1(d);
      let nodeId = tpl_2(d);
      $display("%m: send response remote node, nodeId = %d, myNodeId = %d, srcTag = %d, bodylen = %d", nodeId, myNodeId, req.srcTag, req.bodylen);            
   endrule

   
   Arbiter_IFC#(2) arbiter_req <- mkArbiter(False);
   for ( Integer i = 0; i < 2; i = i + 1) begin
      rule doArbReq_req if ( sendReq_end_sends[i].notEmpty);
         arbiter_req.clients[i].request();
      endrule
      rule doArbResp_req if ( arbiter_req.grant_id == fromInteger(i) ) ;
         let v <- toGet(sendReq_end_sends[i]).get();
         sendReq_end_send.enq(v);
      endrule
   end

   
   FIFO#(Tuple3#(Bit#(21), TagT,  NodeT)) dtaDstQ <- mkFIFO();
   rule recvRemoteAck;
      //let v <- sendAck_end.user.receive;
      let v <- toGet(sendAck_end_recv).get();
      let req = tpl_1(v);
      let src = tpl_2(v);
      $display("%m: receive acknowledgement from remote node, nodeId = %d, srcTag = %d, bodylen = %d", src, req.srcTag, req.bodylen);
      sendBuf.deqReq(req.srcTag, req.bodylen);
      dtaDstQ.enq(tuple3(req.bodylen, req.dstTag, src));
   endrule
   
   Reg#(Bit#(21)) byteCnt_deq <- mkReg(0);
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
      end
      
      let d <- sendBuf.outPipe.get();
      //sendDta_end.user.send(tuple2(d, dstTag), dst);
      //Tuple2#(Bit#(128), Bool) d = tuple2(extend(byteCnt_deq),True);
      $display("%m:: send data to remote node id = %d, byteCnt_deq = %d, byteMax = %d, data = %h", dst, byteCnt_deq, byteMax, tpl_1(d));
      sendDta_end_send.enq(tuple2(tuple2(tpl_1(d), dstTag), dst));
      //sendDta_end_send.enq(tuple2(tuple2(tpl_1(d), dstTag), dst));
   endrule
   
   ReorderBuffer recvBuf <- mkReorderBuffer;
   FIFO#(Tuple3#(RouterHeaderT, NodeT, Bool)) reserve2ack <- mkFIFO();
   
   Reg#(Bit#(32)) reqCnt_recvRMReq <- mkReg(0);
   
   
   rule recvRemoteReq;
      //let v <- sendReq_end.user.receive;
      let v <- toGet(sendReq_end_recv).get();
      let req = tpl_1(v);
      let src = tpl_2(v);
      $display("%m:: got response remotely from nodeId = %d, opcode = %h, status = %d, keylen = %d, bodylen = %d, reqCnt = %d", src, req.opcode, req.status, req.keylen, req.bodylen, reqCnt_recvRMReq);
      reqCnt_recvRMReq <= reqCnt_recvRMReq + 1;
      if ( req.opcode == PROTOCOL_BINARY_CMD_GET && req.status == PROTOCOL_BINARY_RESPONSE_SUCCESS ) begin
         recvBuf.reserveServer.request.put(req.bodylen);
         reserve2ack.enq(tuple3(req, src, True));
      end
      else begin
         reserve2ack.enq(tuple3(req, src, False));
      end
   endrule

   //FIFO#(Maybe#(TagT)) recvBufDeqTag <- mkFIFO;
   FIFO#(Tuple2#(TagT, Bool)) recvBufDeqTag <- mkFIFO;
   //FIFO#(Maybe#(TagT)) recvBufDeqTag <- mkSizedFIFO(128);
   Reg#(Bit#(32)) reqCnt_sendAck <- mkReg(0);
   
   BRAM2Port#(TagT, Tuple3#(Bit#(8), Bit#(21), TagT)) respTable <- mkBRAM2Server(defaultValue);
   rule sendAck;
      let v <- toGet(reserve2ack).get();
      let req = tpl_1(v);
      let src = tpl_2(v);
      let doReserve = tpl_3(v);
      //Maybe#(TagT) deqTag = tagged Invalid;
      TagT deqTag = ?;
      if ( doReserve) begin
         deqTag <- recvBuf.reserveServer.response.get;
         $display("%m:: got recvbuf tag = %d", deqTag);
         //sendAck_end.user.send(AckHeaderEndT{srcTag: req.tag, bodylen: req.bodylen, dstTag: tag}, src);
         sendAck_end_send.enq(tuple2(RouterAckT{srcTag: req.srcTag, bodylen: req.bodylen, dstTag: deqTag}, src));
         //deqTag = tagged Valid tag;

      end
      
      let respHdr = Protocol_Binary_Response_Header{magic: PROTOCOL_BINARY_RES,
                                                    opcode: req.opcode,
                                                    keylen: extend(req.keylen),
                                                    extlen: 0,
                                                    datatype: 0,
                                                    status: req.status,
                                                    bodylen: extend(req.bodylen),
                                                    opaque: ?,//req.opaque,
                                                    cas: 0
                                                    };
      $display("%m: send acknowledgement to remote node, doReserve = %d, deqTag = %d, nodeId = %d, keylen = %d, bodylen = %d, reqCnt = %d", doReserve, deqTag, src, req.keylen, req.bodylen, reqCnt_sendAck);
      reqCnt_sendAck <= reqCnt_sendAck + 1;
      
      if ( doReserve ) begin
         respTable.portA.request.put(BRAMRequest{write: True,
                                                 responseOnWrite: False,
                                                 address: deqTag,
                                                 datain: tuple3(req.keylen, req.bodylen, req.reqId)});
      end
      else begin
         remoteRespQ_2.enq(RouterRespT{respHeader: respHdr,
                                     reqId: req.reqId});
      end
      //tagServe
      // remoteRespQ.enq(RouterRespT{respHeader: respHdr,
      //                             reqId: req.reqId});
      // recvBufDeqTag.enq(tuple2(deqTag, doReserve));
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
      let v <- respTable.portB.response.get();
      let keylen = tpl_1(v);
      let bodylen = tpl_2(v);
      let reqId = tpl_3(v);
   
      let respHdr = Protocol_Binary_Response_Header{magic: PROTOCOL_BINARY_RES,
                                                    opcode: PROTOCOL_BINARY_CMD_GET, 
                                                    keylen: extend(keylen),
                                                    extlen: 0,
                                                    datatype: 0,
                                                    status: PROTOCOL_BINARY_RESPONSE_SUCCESS,
                                                    bodylen: extend(bodylen),
                                                    opaque: ?,//req.opaque,
                                                    cas: 0
                                                    };
      
      remoteRespQ_1.enq(RouterRespT{respHeader: respHdr,
                                  reqId: reqId});
      //recvBufDeqTag.enq(tuple2(deqTag, doReserve));
      
      let deqTag <- toGet(deqTagQ).get();
      recvBuf.deqReq(deqTag, bodylen);            
   endrule
   
      
      

   
   
   Reg#(Bit#(32)) lastcounter <- mkReg(0);
   Reg#(Bool) fuck <- mkReg(False);
   rule recvRemoteDta;
      let v <- toGet(sendDta_end_recv).get();
      let d = tpl_1(v);
      let src = tpl_2(v);
      let data = tpl_1(d);
      let tag = tpl_2(d);
      
      lastcounter <= counter;
      $display("TIMING: %m: receive data from remote node, src = %d, tag = %d, data = %h, counter = %d, exists bubbles = %d", src, tag, data, counter, lastcounter + 1 != counter);
      recvBuf.inData(tag, tuple2(data, ?));
   endrule
   
   Arbiter_IFC#(3) arbiter <- mkArbiter(False);
   FIFO#(RouterRespT) respOOQ <- mkFIFO();
   FIFO#(Tuple2#(Bit#(1), Bit#(21))) deqReqQ <- mkFIFO();
   //FIFO#() dtaDeq <- mkFIFO();
   Reg#(Bit#(32)) reqCnt_arbResp <- mkReg(0);
   for ( Integer i = 0; i < 3; i = i + 1) begin
      rule doArbReq if ( respOOQs[i].notEmpty);
         arbiter.clients[i].request();
      endrule
      
      rule doArbResp if ( arbiter.grant_id == fromInteger(i) ) ;
         let resp <- toGet(respOOQs[i]).get();
         Bit#(21) bodylen = truncate(resp.respHeader.bodylen);
         respOOQ.enq(resp);
         if (i == 0) begin
            $display("%m:: deqReq from local OO respQ, opcode = %h, bodylen = %d, reqCnt = %d", resp.respHeader.opcode, bodylen, reqCnt_arbResp);
            deqReqQ.enq(tuple2(0, bodylen));
            reqCnt_arbResp <= reqCnt_arbResp + 1;
         end
         else begin
            //let ops <- toGet(recvBufDeqTag).get();
            //let v <- toGet(recvBufDeqTag).get();
            //let tag = tpl_1(v);
           // let reserved = tpl_2(v);
            reqCnt_arbResp <= reqCnt_arbResp + 1;
            //if ( isValid(ops) ) begin
            
            deqReqQ.enq(tuple2(1, bodylen));
            if ( i == 1 )
               $display("%m:: deqReq from remote OO respQ, opcode = %h, bodylen = %d, reqCnt = %d", resp.respHeader.opcode, bodylen, reqCnt_arbResp);
            else
               $display("%m:: deqReq from remote OO respQ, no recvbuf, opcode = %h, bodylen = %d, reqCnt = %d", resp.respHeader.opcode, bodylen, reqCnt_arbResp);
            // if ( reserved ) begin
            //    $display("%m:: deqReq from remote OO respQ, opcode = %h, bodylen = %d, tag = %d, reqCnt = %d", resp.respHeader.opcode, bodylen, tag, reqCnt_arbResp);
            //    deqReqQ.enq(tuple2(1, bodylen));
            //    //recvBuf.deqReq(fromMaybe(?, ops), bodylen);
            //    //recvBuf.deqReq(tag, bodylen);
            // end
            // else begin
            //    $display("%m:: deqReq from remote OO respQ, no recvbuf, opcode = %h, bodylen = %d, reqCnt = %d", resp.respHeader.opcode, 0, reqCnt_arbResp);
            //    deqReqQ.enq(tuple2(1, 0));
            // end
         end
      endrule
   end
   
   Reg#(Bit#(21)) dtaByteCnt <- mkReg(0);
   
   FIFO#(Bit#(128)) outDtaQ <- mkFIFO();
   
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
            outDtaQ.enq(tpl_1(d));
         end
      end
         
   endrule
   
   interface Put sendReq = toPut(sendReqQ);
   interface Get getTag = toGet(respTagQ);
   interface Put burstReq = toPut(burstReqQ);
  
   
   interface Get recvOOReq = toGet(respOOQ);
   interface Put dataInQ = toPut(inDtaQ);
   interface Get dataOutQ = toGet(outDtaQ);
   interface Get recvIOReq = toGet(inOrderlocalRespQ);
   
   method Action setNodeIdx(NodeT myId);
      myNodeId <= myId;
   endmethod
   
   interface RespEndPointClients endpoints;
      interface EndPointClient req_end = toEndPointClient(sendReq_end_send, sendReq_end_recv);
      interface EndPointClient ack_end = toEndPointClient(sendAck_end_send, sendAck_end_recv);
      interface EndPointClient dta_end = toEndPointClient(sendDta_end_send, sendDta_end_recv);
   endinterface

endmodule
