import ClientServer::*;
import GetPut::*;
import ClientServerHelper::*;


import FIFOF::*;

typedef Server#(element_type, Maybe#(element_type)) AliasTableServer#(type element_type);
typedef Client#(element_type, Maybe#(element_type)) AliasTableClient#(type element_type);

interface AliasTableIfc#(type element_type, numeric type numEntries);
   interface AliasTableServer#(element_type) lookUpServer;
   method Action upd(Tuple2#(element_type, element_type) v);
   
   method Bool isEmpty;
      return fifo.isEmpty;
   endmethod
   
   method Bool isFull;
      return fifo.isFull;
   endmethod
endinterface

module mkAliasTable(AliasTableServer#(element_type, numEntries))
   provisos(Add#(TExp#(TLog#(numEntries)),0, numEntries));
   FIFO#(element_type) reqRdQ <- mkFIFO;
   FIFO#(Maybe#(element_type)) reqRespQ <- mkFIFO;
   FIFO#(Tuple2#(element_type, element_type)) reqUpdQ <- mkFIFO;
   
   Reg#(TLog#(numEntries)) currId <- mkReg(0);
   Reg#(TLog#(numEntries)) oldestId <- mkReg(0);
   
   //Vector#(numEntries, Reg#(Bool)) valids <- replicateM(mkReg(False));
   Vector#(numEntries, Reg#(element_type)) aliasId <- replicateM(mkRegU());
   Vector#(numEntries, Reg#(element_type)) aliasDta <- replicateM(mkRegU());
   
   rule doSearch;
      let searchId <- toGet(reqRdQ).get();
      Maybe#(element_type) retval = tagged Invalid;
      if ( !fifo.isEmpty ) begin
         Bit#(TAdd#(TLog#(numEntries),1)) largestId = (oldestId - currId);
         if largestId == 0
            laregestId = fromInteger(valueOf(numEntries));
         for ( Integer i = 0; i < valueOf(numEntries); i = i + 1 ) begin
            let idx = currId + fromInteger(i);
            if (aliasId[idx] == searchId && fromInteger(i) < largestId )
               retval = tagged Valid aliasDta[idx];
         end
      end
      reqResqQ.enq(retval);
   endrule
   
   FIFO#(Bit#(0)) fifo <- mkSizedFIFO(valueOf(numEntries));
   
   interface AliasTableServer lookUpServer = toServer(reqRdQ, reqRespQ);
   
   method Action enq(Tuple2#(element_type, element_type) v);
      //fifo.enq(?)
      let id = tpl_1(v);
      let dta = tpl_2(v);
      aliasId[currId] <= id;
      aliasDta[currId] <= dta;
      currId <= currId + 1;
   
   endmethod
   
   method Action deq(Tuple2#(element_type. element_type) v);
      /* push out the oldest val */
      oldestId <= oldestId + 1;
      //valids[oldestId] <= False;
      //fifo.deq();
   endmethod
   
   method Bool isEmpty;
      return fifo.isEmpty;
   endmethod
   
   method Bool isFull;
      return fifo.isFull;
   endmethod

   
endmodule
   
   
