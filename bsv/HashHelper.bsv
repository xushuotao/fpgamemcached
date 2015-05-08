package HashHelper;

import FIFO::*;
import GetPut::*;
import Vector::*:
import Connectable::*;

import JenkinsHash::*; 
import RequestSplit::*;

interface HashHelperIfc#(numeric type numEngines);
   Vector#(numEngines, Put#(MemcachedReqType)) reqInPipes
   Vector#(numEngines, Put#(Bit#(64))) inPipes;
   interface Get#(MemcacheReqType) reqOutPipes
   interface Get#(Bit#(32)) hashVal;
   interface Get#(Bit#(64)) keyPipe;
endinterface

module mkHashHelper#(Vector#(numEngines, DMAReadIfc) rdIfcs, Vector#(numEngines, RecvPort) recvPorts)(HashHelperIfc#(numEngines));
   Vector#(numEngines, JenkinsHashIfc) hashEngines <- replicateM(mkJenkinsHash);
   Vector#(numEngines, SplitIfc) reqSplitters = newVector();// <- replicateM(mkReqSplit);
   Vector#(numEngines, FIFO#(Bit#(64))) keyBufs <- replicateM(mkSizedFIFO(32));
   
   for (Integer i = 0; i < valueOf(numEngines); i = i + 1) begin
      reqSplitters[i] <- mkReqSplit#(rdIfcs[i], recvPorts[i]);
      //mkConnection(reqSplitters[i]
   end
   
   for (Integer i = 0; i < valueOf(numEngines); i = i + 1) begin
      rule doHash;
         //let v <- toGet(cmd2hash).get();
         let v <- r.nextRequest.get();
         let cmd = v.header;//tpl_1(v);
         let keylen = cmd.keylen;
         $display("hash calculation is bypassed = %b", isValid(v.nodeId));
         if ( !isValid(v.nodeId)) begin
            hash.start(extend(keylen));
         end
         hash2table.enq(v);
      endrule
      
      rule key2Hash;
         //let v <- toGet(keyFifo).get();
         let v <- splitter.nextKey.get();
         $display("Memcached Get key: %h, byPass hash %b", tpl_1(v), tpl_2(v));
         if (tpl_2(v))
            hash.putKey(tpl_1(v));
         keyBuf.enq(tpl_1(v));
      endrule
   end
      
      
   
      
   
   interface Get hashVal;
   interface Get keyPipe;
endmodule
endpackage: HashHelper
