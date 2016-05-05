import AuroraEndPointHelper::*;
import AuroraExtEndpoint::*;
import Vector::*;
import MemcachedTypes::*;
import ControllerTypes::*;

import RequestRouter::*;
import ResponseRouter::*;

import GetPut::*;
import ClientServer::*;

function EndPointServer#(t) toEndPointServer(AuroraEndpointIfc#(t) endp) provisos(Bits#(t, a__));
   return (interface EndPointServer#(t);
              interface Put send;
                 method Action put(Tuple2#(t, NodeT) v);
                    //$display("%m endpoint send data to nodeId = %d, data = %h", tpl_2(v), tpl_1(v));
                    endp.user.send(tpl_1(v), tpl_2(v));
                 endmethod
              endinterface
              interface Get recv;
                 method ActionValue#(Tuple2#(t, NodeT)) get;
                    let v <- endp.user.receive;
                    //$display("%m endpoint receive data from nodeId = %d, data = %h", tpl_2(v), tpl_1(v));
                    return v;
                 endmethod
              endinterface
           endinterface);
endfunction

interface InterFPGAEndpoints;
   interface ReqEndPointServers req_ends;
   interface RespEndPointServers resp_ends;
   interface Vector#(6, AuroraEndpointCmdIfc) endpoints;
endinterface

module mkInterFPGAEndpoints(InterFPGAEndpoints);
   AuroraEndpointIfc#(ReqHeaderEndT) req_sendReq_end <- mkAuroraEndpointStatic(64, 8);
   AuroraEndpointIfc#(AckHeaderEndT) req_sendAck_end <- mkAuroraEndpointStatic(64, 8);
   AuroraEndpointIfc#(Tuple2#(Tuple2#(Bit#(128), Bool), TagT)) req_sendDta_end <- mkAuroraEndpointStatic(256, 128);

   AuroraEndpointIfc#(RouterHeaderT) resp_sendReq_end <- mkAuroraEndpointStatic(64, 8);
   AuroraEndpointIfc#(RouterAckT) resp_sendAck_end <- mkAuroraEndpointStatic(64, 8);
   AuroraEndpointIfc#(Tuple2#(Bit#(128), TagT)) resp_sendDta_end <- mkAuroraEndpointStatic(256, 128);
   
   // AuroraEndpointIfc#(ReqHeaderEndT) req_sendReq_end <- mkAuroraEndpointDynamic(64, 8, 128);
   // AuroraEndpointIfc#(AckHeaderEndT) req_sendAck_end <- mkAuroraEndpointDynamic(64, 8, 128);
   // AuroraEndpointIfc#(Tuple2#(Tuple2#(Bit#(128), Bool), TagT)) req_sendDta_end <- mkAuroraEndpointDynamic(256, 256, 768);

   // AuroraEndpointIfc#(RouterHeaderT) resp_sendReq_end <- mkAuroraEndpointDynamic(4, 2, 32);
   // AuroraEndpointIfc#(RouterAckT) resp_sendAck_end <- mkAuroraEndpointDynamic(4, 2, 32);
   // AuroraEndpointIfc#(Tuple2#(Bit#(128), TagT)) resp_sendDta_end <- mkAuroraEndpointDynamic(256, 256, 768);
   
   
   Vector#(6, AuroraEndpointCmdIfc) endpoints_v = newVector();
   endpoints_v[5] = req_sendReq_end.cmd;
   endpoints_v[1] = req_sendAck_end.cmd;
   endpoints_v[2] = req_sendDta_end.cmd;
   
   endpoints_v[3] = resp_sendReq_end.cmd;
   endpoints_v[4] = resp_sendAck_end.cmd;
   endpoints_v[0] = resp_sendDta_end.cmd;
 
   
   interface ReqEndPointServers req_ends;
      interface req_end = toEndPointServer(req_sendReq_end);
      interface ack_end = toEndPointServer(req_sendAck_end);
      interface dta_end = toEndPointServer(req_sendDta_end);
   endinterface
   
   interface RespEndPointServers resp_ends;
      interface req_end = toEndPointServer(resp_sendReq_end);
      interface ack_end = toEndPointServer(resp_sendAck_end);
      interface dta_end = toEndPointServer(resp_sendDta_end);
   endinterface
   
   interface endpoints = endpoints_v;
endmodule
