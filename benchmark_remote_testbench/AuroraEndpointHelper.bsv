import FIFO::*;
import Vector::*;
import List::*;
import GetPut::*;
import Clocks::*;
import Xilinx::*;
import ProtocolHeader::*;
import AuroraExtArbiter::*;
import AuroraExtImport::*;
import AuroraExtImport117::*;
import AuroraCommon::*;

import StreamingSerDes_Tagged::*;
import Serializer::*;

typedef struct{
   Protocol_Binary_Command opcode;
   Bit#(8) keylen;
   Bit#(21) vallen;
   Bit#(32) hv;
   } MemReqType deriving (Bits,Eq);
               

interface SendPort;
   method Action sendCmd(MemReqType req, Bit#(32) node);
   interface Put#(Bit#(64)) inPipe;
endinterface

interface RecvPort;
   method ActionValue#(Tuple2#(MemReqType, Bit#(32))) recvCmd;
   interface Get#(Bit#(64)) outPipe;
endinterface

interface RemoteEndpointIfc;
   interface SendPort sendPort;
   interface RecvPort recvPort;
endinterface

interface RemoteIfc;
   interface RemoteEndpointIfc requestPort;
   interface RemoteEndpointIfc responsePort;
endinterface

interface RemoteAccessIfc#(numeric type numInstances);
   interface Vector#(numInstances, RemoteIfc) remotePorts;
   method Action setRoutingTable(Bit#(32) node, Bit#(32) portidx, Bit#(32) portsel);
   method Action setNetId(Bit#(32) netid);
   method ActionValue#(Bit#(32)) auroraStatus;
   method Bit#(32) getNetId;
   interface Vector#(AuroraExtCount, Aurora_Pins#(1)) aurora_ext;
   interface Aurora_Clock_Pins aurora_quad119;
   interface Aurora_Clock_Pins aurora_quad117;
endinterface

module mkRemoteAccess#(Clock clk250, Reset rst250)(RemoteAccessIfc#(numInstances));
   `ifndef BSIM
   ClockDividerIfc auroraExtClockDiv5 <- mkDCMClockDivider(5, 4, clocked_by clk250);
   Clock clk50 = auroraExtClockDiv5.slowClock;
   `else
   Clock clk50 <- exposeCurrentClock;
   `endif

   Reg#(Bit#(HeaderFieldSz)) myNetIdx <- mkReg(1);
   

   GtxClockImportIfc gtx_clk_119 <- mkGtxClockImport;
   GtxClockImportIfc gtx_clk_117 <- mkGtxClockImport;
   AuroraExtIfc auroraExt119 <- mkAuroraExt(gtx_clk_119.gtx_clk_p_ifc, gtx_clk_119.gtx_clk_n_ifc, clk50);
   AuroraExtIfc auroraExt117 <- mkAuroraExt117(gtx_clk_117.gtx_clk_p_ifc, gtx_clk_117.gtx_clk_n_ifc, clk50);
   
   Vector#(numInstances, AuroraEndpointIfc#(MemReqType)) cmdEnds_request;
   Vector#(numInstances, AuroraEndpointIfc#(Tuple2#(Bit#(105), Bool))) dtaEnds_request;
   Vector#(numInstances, AuroraEndpointIfc#(MemReqType)) cmdEnds_response;
   Vector#(numInstances, AuroraEndpointIfc#(Tuple2#(Bit#(105), Bool))) dtaEnds_response;
  
   Vector#(TMul#(numInstances,4), AuroraEndpointCmdIfc) alist;
   Integer numIns = valueOf(numInstances);
   for (Integer i = 0; i < numIns; i = i + 1) begin
      cmdEnds_request[i] <- mkAuroraEndpoint(numIns*i, myNetIdx);
      dtaEnds_request[i] <- mkAuroraEndpoint(numIns*i+1, myNetIdx);
      cmdEnds_response[i] <- mkAuroraEndpoint(numIns*i+2, myNetIdx);
      dtaEnds_response[i] <- mkAuroraEndpoint(numIns*i+3, myNetIdx);
      //alist = cons(dtaEnds_response[i].cmd, cons(cmdEnds_response[i].cmd, cons(dtaEnds_request[i].cmd, cons(cmdEnds_request[i].cmd, alist))));
      alist[numIns*i] = cmdEnds_request[i].cmd;
      alist[numIns*i+1] = dtaEnds_request[i].cmd;
      alist[numIns*i+2] = cmdEnds_response[i].cmd;
      alist[numIns*i+3] = dtaEnds_response[i].cmd;
   end
   
   AuroraExtArbiterIfc auroraExtArbiter <- mkAuroraExtArbiter(append(auroraExt119.user, auroraExt117.user),
                                                              alist, myNetIdx);
   
      
   Vector#(numInstances,StreamingSerializerIfc#(Bit#(128), Bit#(105))) ser_request <- replicateM(mkStreamingSerializer);
   Vector#(numInstances,StreamingDeserializerIfc#(Bit#(105), Bit#(128))) des_request <- replicateM(mkStreamingDeserializer);
   Vector#(numInstances,DeserializerTagIfc) des_64_128_request <- replicateM(mkDeserializerTag);
   Vector#(numInstances,SerializerIfc) ser_128_64_request <- replicateM(mkSerializer);
   
   Vector#(numInstances, FIFO#(Tuple2#(Bit#(64), Bit#(32)))) lenQ_snd_request <- replicateM(mkFIFO);
    
   
   for (Integer i = 0; i < numIns; i = i + 1) begin
      rule doSer;
      let v <- des_64_128_request[i].outPipe.get();
         $display("local node put data = %h to ser", tpl_1(v));
         ser_request[i].enq(tpl_1(v), tpl_2(v));
      endrule
      
      Reg#(Bit#(64)) sndCnt <- mkReg(0);
      rule doSnd;
         /*let d = lenQ_snd_request[i].first; //TODO:::
         let lenMax = tpl_1(d);
         let curDtaDst = tpl_2(d);
         if ( sndCnt + 105 >= lenMax ) begin
            lenQ_snd_request[i].deq();
           sndCnt <= 0;
         end
         else begin
           sndCnt <= sndCnt + 105;
         end*/
         let v <- ser_request[i].deq();
         $display("DtaEnd_request[%d] sends data = %h to %d", i, tpl_1(tpl_1(v)), tpl_2(v));
         dtaEnds_request[i].user.send(tpl_1(v), truncate(tpl_2(v)));
      endrule
      
      rule doRcv;
         let v <- dtaEnds_request[i].user.receive;
         let data = tpl_1(v);
         $display("DtaEnd_request[%d] receives data = %h from %d", i, tpl_1(data), tpl_2(v));
         des_request[i].enq(tpl_1(data), tpl_2(data));
      endrule
      
      rule doDer;
         let d <- des_request[i].deq;
         $display("Got data from remote node = %h", d);
         ser_128_64_request[i].inPipe.put(d);
      endrule
   end
   
   Vector#(numInstances,StreamingSerializerIfc#(Bit#(128), Bit#(105))) ser_response <- replicateM(mkStreamingSerializer);
   Vector#(numInstances,StreamingDeserializerIfc#(Bit#(105), Bit#(128))) des_response <- replicateM(mkStreamingDeserializer);
   Vector#(numInstances,DeserializerTagIfc) des_64_128_response <- replicateM(mkDeserializerTag);
   Vector#(numInstances,SerializerIfc) ser_128_64_response <- replicateM(mkSerializer);
   
   Vector#(numInstances, FIFO#(Tuple2#(Bit#(64), Bit#(32)))) lenQ_snd_response <- replicateM(mkFIFO);
    
   
   for (Integer i = 0; i < numIns; i = i + 1) begin
      rule doSer;
         let v <- des_64_128_response[i].outPipe.get();
         ser_response[i].enq(tpl_1(v), tpl_2(v));
      endrule
      
      Reg#(Bit#(64)) sndCnt <- mkReg(0);
      rule doSnd;
         //let d = lenQ_snd_response[i].first; //TODO:::
         let v <- ser_response[i].deq();
         /*let lenMax = tpl_1(d);
         let curDtaDst = tpl_2(d);
         if ( sndCnt + 105 >= lenMax ) begin
            lenQ_snd_response[i].deq();
           sndCnt <= 0;
         end
         else begin
            if (tpl_2(v))
               sndCnt <= sndCnt + 105;
         end
         */
         dtaEnds_response[i].user.send(tpl_1(v), truncate(tpl_2(v)));
      endrule
      
      rule doRcv;
         let v <- dtaEnds_response[i].user.receive;
         let data = tpl_1(v);
         des_response[i].enq(tpl_1(data), tpl_2(data));
      endrule
      
      rule doDer;
         let d <- des_response[i].deq;
         $display("got 128 bit data from remote %h", d);
         ser_128_64_response[i].inPipe.put(d);
      endrule
   end  
         

   Vector#(numInstances, RemoteIfc) rp;
   for (Integer i = 0; i < numIns; i = i + 1)
      rp[i] = (interface RemoteIfc;
                  interface RemoteEndpointIfc requestPort;
                     interface SendPort sendPort;
                        method Action sendCmd(MemReqType req, Bit#(32) node);
                           Bit#(64) len = extend(req.keylen) + extend(req.vallen);
                           Bit#(64) len_bit = (extend(req.keylen) + extend(req.vallen)) << 3;
                           $display("Aurora request port sends cmd to node = %d, len = %d, len_bit = %d", node, len, len_bit);
                           Bit#(64) numTokens;
                           if ( (len & 7) == 0 ) begin
                              numTokens = len >> 3;
                           end
                           else begin
                              numTokens = (len >> 3) + 1;
                           end

                           cmdEnds_request[i].user.send(req, truncate(node));
                           des_64_128_request[i].start(numTokens, node);
                           //lenQ_snd_request[i].enq(tuple2(len_bit, node));
                        endmethod
                        interface Put inPipe = des_64_128_request[i].inPipe;
                     endinterface
         
                     interface RecvPort recvPort;
                        method ActionValue#(Tuple2#(MemReqType, Bit#(32))) recvCmd;
                           let d <- cmdEnds_request[i].user.receive;
                           let req = tpl_1(d);
                           let node = tpl_2(d);
                           $display("Aurora request port receive cmd from node = %d", node);
                           Bit#(64) len = extend(req.keylen) + extend(req.vallen);
                           Bit#(64) numTokens;
                           if ( (len & 7) == 0 ) begin
                              numTokens = len >> 3;
                           end
                           else begin
                              numTokens = (len >> 3) + 1;
                           end
                           ser_128_64_request[i].start(numTokens);
                           return tuple2(req, extend(node));
                        endmethod      
                        interface Get outPipe = ser_128_64_request[i].outPipe;
                     endinterface
                   endinterface
                           
                  interface RemoteEndpointIfc responsePort;
                     interface SendPort sendPort;
                        method Action sendCmd(MemReqType req, Bit#(32) node);
                           cmdEnds_response[i].user.send(req, truncate(node));
                           Bit#(64) len = extend(req.vallen);
                           if ( req.vallen > 0) begin
                              Bit#(64) numTokens;
                              if ( (len & 7) == 0 ) begin
                                 numTokens = len >> 3;
                              end
                              else begin
                                 numTokens = (len >> 3) + 1;
                              end
                              des_64_128_response[i].start(numTokens, node);
                              //lenQ_snd_response[i].enq(tuple2(extend(req.vallen)<<3, node));
                           end
                        endmethod
                        interface Put inPipe = des_64_128_response[i].inPipe;
                     endinterface
                   
                     interface RecvPort recvPort;
                        method ActionValue#(Tuple2#(MemReqType, Bit#(32))) recvCmd;
                           let d <- cmdEnds_response[i].user.receive;
                           let req = tpl_1(d);
                           let node = tpl_2(d);
                           Bit#(64) len = extend(req.vallen);
                           if ( req.vallen > 0 ) begin
                              Bit#(64) numTokens;
                              if ( (len & 7) == 0 ) begin
                                 numTokens = len >> 3;
                              end
                              else begin
                                 numTokens = (len >> 3) + 1;
                              end
                              ser_128_64_response[i].start(numTokens);
                           end
                           return tuple2(req, extend(node));
                        endmethod      
                        interface Get outPipe = ser_128_64_response[i].outPipe;
                     endinterface
                  endinterface
               endinterface);
   
   interface remotePorts = rp;

   method Action setRoutingTable(Bit#(32) node, Bit#(32) portidx, Bit#(32) portsel);
      auroraExtArbiter.setRoutingTable(truncate(node), truncate(portidx), truncate(portsel));
   endmethod
   
   method Action setNetId(Bit#(32) netid);
      myNetIdx <= truncate(netid);
   endmethod
   
   method ActionValue#(Bit#(32)) auroraStatus;
      return {
              0,
              auroraExt117.user[3].channel_up,
              auroraExt117.user[2].channel_up,
              auroraExt117.user[1].channel_up,
              auroraExt117.user[0].channel_up,
         
              auroraExt119.user[3].channel_up,
              auroraExt119.user[2].channel_up,
              auroraExt119.user[1].channel_up,
              auroraExt119.user[0].channel_up
              };
   endmethod
   
   method Bit#(32) getNetId;
      return extend(myNetIdx);
   endmethod
      
   interface Aurora_Pins aurora_ext = append(auroraExt119.aurora, auroraExt117.aurora);
   interface Aurora_Clock_Pins aurora_quad119 = gtx_clk_119.aurora_clk;
   interface Aurora_Clock_Pins aurora_quad117 = gtx_clk_117.aurora_clk;
endmodule
   
