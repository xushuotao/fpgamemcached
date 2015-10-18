import FIFO::*;
import FIFOF::*;
import GetPut::*;
import Cntrs::*;
//import DMAHelper::*;

interface IndicationServer#(type t);
   interface Get#(t) toHost;
   interface Get#(Bit#(32)) getElements;
   interface Put#(t) fromHost;
endinterface

interface HostFIFO#(type t);
   method Bool notFull;
   method Action enq(t x);
   method Bool notEmpty;
   method Action deq;
   method t first;
   method Action clear;
   interface IndicationServer#(t) indicationServer;
endinterface

module mkHostFIFO#(Integer n, Integer lowerThreshold)(HostFIFO#(t))
   provisos(Bits#(t, a__));
   
   FIFO#(t) inputQ <- mkFIFO();
   FIFOF#(t) fpgaFIFO <- mkSizedFIFOF(n);
   FIFO#(t) toHostQ <- mkFIFO();
   FIFO#(t) fromHostQ <- mkFIFO();
   FIFO#(Bit#(32)) getElementsQ <- mkFIFO();
   
   //Reg#(Bit#(32)) hostElemCnt <- mkReg(0);
   //Reg#(Bit#(32)) fpgaElemCnt <- mkReg(0);
   Count#(Bit#(32)) hostElemCnt_0 <- mkCount(0);
   Count#(Bit#(32)) hostElemCnt_1 <- mkCount(0);
   Count#(Bit#(32)) fpgaElemCnt <- mkCount(0);
   
   Bool noRoom = (hostElemCnt_0 == -1);
   (*descending_urgency = "doReqFromHost, doEnqToFPGA, doEnqToHost"*)
   
   rule doEnqToFPGA if ( hostElemCnt_0 == 0 && fpgaFIFO.notFull);
      let d <- toGet(inputQ).get();
      $display("doEnqToFPGA data = %d", d);
      fpgaFIFO.enq(d);
      //fpgaElemCnt <= fpgaElemCnt + 1;
      fpgaElemCnt.incr(1);
   endrule
   
   rule doReqFromHost if ( fpgaElemCnt < fromInteger(lowerThreshold) && hostElemCnt_1 > 0 );
      Bit#(32) emptySlots = fromInteger(n) - fpgaElemCnt;
      Bit#(32) reqSize = ( emptySlots > hostElemCnt_1 ? hostElemCnt_1: emptySlots);
      $display("doReqFromHost fpgaElemCnt = %d, hostElemCnt_1 = %d, reqSize = %d", fpgaElemCnt, hostElemCnt_1, reqSize);
      getElementsQ.enq(reqSize);
      //hostElem <= hostElem - reqSize;
      hostElemCnt_1.decr(reqSize);
      //fpgaElemCnt <= fpgaElemCnt + reqSize;
      fpgaElemCnt.incr(reqSize);
   endrule
   
   rule doEnqToHost if (hostElemCnt_0 > 0 || !fpgaFIFO.notFull);
      let d <- toGet(inputQ).get();
      $display("doEnqToHost data = %d", d);
      toHostQ.enq(d);
      //hostElemCnt <= hostElemCnt + 1;
      hostElemCnt_0.incr(1);
      hostElemCnt_1.incr(1);
   endrule

   
   rule doDeqFromHost;
      hostElemCnt_0.decr(1);
      let d <- toGet(fromHostQ).get();
      fpgaFIFO.enq(d);
   endrule
   
   
   method Bool notFull;
      return !noRoom;
   endmethod
   
   method Action enq(t x) if (!noRoom);
      inputQ.enq(x);
   endmethod
   
   method Bool notEmpty;
      return fpgaFIFO.notEmpty();
   endmethod
   
   method Action deq;
      //fpgaElemCnt <= fpgaElemCnt - 1;
      //$display("Action deq fpgaElemCnt = %d", fpgaElemCnt);
      fpgaElemCnt.decr(1);
      fpgaFIFO.deq();
   endmethod
   
   method t first;
      let d = fpgaFIFO.first();
      return d;
   endmethod
   
   method Action clear;
      
   endmethod
   
   interface IndicationServer indicationServer;
      interface toHost = toGet(toHostQ);
      interface getElements = toGet(getElementsQ);
      interface fromHost = toPut(fromHostQ);
   endinterface
endmodule
