//`include "ProtocolHeader.bsv"
import ProtocolHeader::*;

import GetPut::*;
//import ClientServer::*;
import Connectable::*;

import PortalMemory::*;
import MemTypes::*;
import MemreadEngine::*;
import MemwriteEngine::*;
import Pipe::*;

import DMAHelper::*;

import DRAMController::*;
import Proc::*;
import Hashtable::*;
import Valuestr::*;

import IlaWrapper::*;

typedef struct {
   Bit#(8) magic;
   Bit#(8) opcode;
   Bit#(16) keylen;
   Bit#(8)  extlen;
   Bit#(8) datatype;
   Bit#(16) reserved;
   Bit#(32) bodylen;
   Bit#(32) opaque;
   Bit#(64) cas;
   } Request_Header deriving (Eq, Bits);

typedef struct {
   Bit#(8) magic;
   Bit#(8) opcode;
   Bit#(16) keylen;
   Bit#(8) extlen;
   Bit#(8) datatype;
   Bit#(16) status;
   Bit#(32) bodylen;
   Bit#(32) opaque;
   Bit#(64) cas;
   }Response_Header deriving (Eq, Bits);


interface ServerIndication;
   //method Action releaseSrcBuffer(Bit#(32) id);
   method Action done(Response_Header resp, Bit#(32) id);
   //method Action hexdump(Bit#(32) v);
endinterface

interface ServerRequest;
   /*** initialize ****/
   method Action initValDelimit(Bit#(64) lgSz1, Bit#(64) lgSz2, Bit#(64) lgSz3);
   method Action initAddrDelimit(Bit#(64) lgOffset1, Bit#(64) lgOffset2, Bit#(64) lgOffset3);
   
   /*** cmd key dta request ***/
   method Action start(Request_Header cmd, Bit#(32) rp, Bit#(32) wp, Bit#(64) nBytes, Bit#(32) id);
endinterface


interface Server;
   interface ServerRequest request;
   interface ObjectReadClient#(64) dmaReadClient;
   interface ObjectWriteClient#(64) dmaWriteClient;
endinterface


module mkServerRequest#(ServerIndication indication, DRAMControllerIfc dram)(Server);
   MemreadEngine#(64,1)  re <- mkMemreadEngine;
   MemwriteEngine#(64,1) we <- mkMemwriteEngine;
   
  // `ifndef BSIM
   let ila <- mkChipscopeDebug();
   //`else
   //let ila <- mkChipscopeEmpty();
   //`endif
   
   let dmaReader <- mkDMAReader(re.readServers[0], re.dataPipes[0], ila.ila_dma_0);
   let dmaWriter <- mkDMAWriter(we.writeServers[0], we.dataPipes[0], ila.ila_dma_1);
   
   Reg#(Bit#(32)) id_reg <- mkRegU();
   Reg#(Bit#(32)) wp_reg <- mkRegU();
   
   let memcached <- mkMemCached(dram, dmaReader, dmaWriter);
  
   
   
   mkConnection(dmaReader.response, memcached.server.request);
  
   mkConnection(memcached.server.response, dmaWriter.request);
   
   rule process_done;
      //dmaWriter.done();
      let v <- memcached.done();
      //Protocol_Binary_Response_Header v = unpack(d);
      let header = tpl_1(v);
      let id = tpl_2(v);
      $display("Memcached sends back indication: opcode = %d", header.opcode);
     
      indication.done(unpack(pack(header)), id);
   endrule
   
   interface ServerRequest request;
      method Action start(Request_Header cmd, Bit#(32) rp, Bit#(32) wp, Bit#(64) nBytes, Bit#(32) id);
         $display("Server start processing rp = %d, wp = %d, nBytes = %d, id = %d", rp, wp, nBytes, id);
         memcached.start(unpack(pack(cmd)), rp, wp, nBytes, id);
         //dmaReader.readReq(rp, nBytes);
         //wp_reg <= wp;
         //id_reg <= id;
      endmethod
      
      method Action initValDelimit(Bit#(64) lgSz1, Bit#(64) lgSz2, Bit#(64) lgSz3);
         $display("Server initializing val store size delimiter");
         memcached.valInit.initValDelimit(lgSz1, lgSz2, lgSz3);
      endmethod
  
      method Action initAddrDelimit(Bit#(64) lgOffset1, Bit#(64) lgOffset2, Bit#(64) lgOffset3);
         $display("Server initializing val store addr delimiter");
         memcached.valInit.initAddrDelimit(lgOffset1, lgOffset2, lgOffset3);
         memcached.htableInit.initTable(lgOffset1);
      endmethod
   endinterface
   
   interface ObjectReadClient dmaReadClient = re.dmaClient;
   interface ObjectWriteClient dmaWriteClient = we.dmaClient;
   
endmodule
