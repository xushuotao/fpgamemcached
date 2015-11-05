package BluecacheIndication;

import FIFO::*;
import FIFOF::*;
import GetPut::*;
import Connectable::*;
import Clocks::*;
import FloatingPoint::*;
import Adapter::*;
import Leds::*;
import Vector::*;
import SpecialFIFOs::*;
import ConnectalMemory::*;
import Portal::*;
import MemPortal::*;
import MemTypes::*;
import Pipe::*;
import Bluecache::*;
import FIFO::*;
import FIFOF::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;
import Arith::*;
import Pipe::*;
import MemTypes::*;
import MemreadEngine::*;
import MemwriteEngine::*;
import HostInterface::*;
import Connectable::*;
import RequestParser::*;
import ProtocolHeader::*;
import DMAHelper::*;
import Proc_128::*;
import HashtableTypes::*;
import Hashtable::*;
import ValFlashCtrlTypes::*;
import ValuestrCommon::*;
import DRAMCommon::*;
import HostFIFO::*;
import AuroraImportFmc1::*;
import ControllerTypes::*;
import AuroraCommon::*;
import TagAlloc::*;
import FlashCtrlVirtex::*;
import FlashCtrlModel::*;
import FlashServer::*;
import SpecialFIFOs::*;
import StmtFSM::*;
import MemServer::*;
import MMU::*;
import CtrlMux::*;
import Portal::*;
import ConnectalMemory::*;
import Leds::*;
import MemServerRequest::*;
import MMURequest::*;
import MemServerIndication::*;
import MMUIndication::*;
import Bluecache::*;
import XilinxVC707DDR3::*;
import DRAMController::*;




typedef struct {
    Bit#(32) dummy;
} InitDone_Message deriving (Bits);

typedef struct {
    Bit#(32) bufId;
} RdDone_Message deriving (Bits);

typedef struct {
    Bit#(32) bufId;
} WrDone_Message deriving (Bits);

typedef struct {
    Bit#(32) v;
} SendData_0_Message deriving (Bits);

typedef struct {
    Bit#(32) v;
} ElementReq_0_Message deriving (Bits);

typedef struct {
    Bit#(32) v;
} SendData_1_Message deriving (Bits);

typedef struct {
    Bit#(32) v;
} ElementReq_1_Message deriving (Bits);

typedef struct {
    Bit#(32) v;
} SendData_2_Message deriving (Bits);

typedef struct {
    Bit#(32) v;
} ElementReq_2_Message deriving (Bits);

// exposed wrapper portal interface
interface BluecacheIndicationWrapperPipes;
    interface PipePortal#(9, 0, 32) portalIfc;
    interface PipeOut#(InitDone_Message) initDone_PipeOut;
    interface PipeOut#(RdDone_Message) rdDone_PipeOut;
    interface PipeOut#(WrDone_Message) wrDone_PipeOut;
    interface PipeOut#(SendData_0_Message) sendData_0_PipeOut;
    interface PipeOut#(ElementReq_0_Message) elementReq_0_PipeOut;
    interface PipeOut#(SendData_1_Message) sendData_1_PipeOut;
    interface PipeOut#(ElementReq_1_Message) elementReq_1_PipeOut;
    interface PipeOut#(SendData_2_Message) sendData_2_PipeOut;
    interface PipeOut#(ElementReq_2_Message) elementReq_2_PipeOut;

endinterface
interface BluecacheIndicationWrapperPortal;
    interface PipePortal#(9, 0, 32) portalIfc;
endinterface
// exposed wrapper MemPortal interface
interface BluecacheIndicationWrapper;
    interface StdPortal portalIfc;
endinterface

instance Connectable#(BluecacheIndicationWrapperPipes,BluecacheIndication);
   module mkConnection#(BluecacheIndicationWrapperPipes pipes, BluecacheIndication ifc)(Empty);

    rule handle_initDone_request;
        let request <- toGet(pipes.initDone_PipeOut).get();
        ifc.initDone(request.dummy);
    endrule

    rule handle_rdDone_request;
        let request <- toGet(pipes.rdDone_PipeOut).get();
        ifc.rdDone(request.bufId);
    endrule

    rule handle_wrDone_request;
        let request <- toGet(pipes.wrDone_PipeOut).get();
        ifc.wrDone(request.bufId);
    endrule

    rule handle_sendData_0_request;
        let request <- toGet(pipes.sendData_0_PipeOut).get();
        ifc.sendData_0(request.v);
    endrule

    rule handle_elementReq_0_request;
        let request <- toGet(pipes.elementReq_0_PipeOut).get();
        ifc.elementReq_0(request.v);
    endrule

    rule handle_sendData_1_request;
        let request <- toGet(pipes.sendData_1_PipeOut).get();
        ifc.sendData_1(request.v);
    endrule

    rule handle_elementReq_1_request;
        let request <- toGet(pipes.elementReq_1_PipeOut).get();
        ifc.elementReq_1(request.v);
    endrule

    rule handle_sendData_2_request;
        let request <- toGet(pipes.sendData_2_PipeOut).get();
        ifc.sendData_2(request.v);
    endrule

    rule handle_elementReq_2_request;
        let request <- toGet(pipes.elementReq_2_PipeOut).get();
        ifc.elementReq_2(request.v);
    endrule

   endmodule
endinstance

// exposed wrapper Portal implementation
(* synthesize *)
module mkBluecacheIndicationWrapperPipes#(Bit#(32) id)(BluecacheIndicationWrapperPipes);
    Vector#(9, PipeIn#(Bit#(32))) requestPipeIn = newVector();

    FromBit#(32,InitDone_Message) initDone_requestFifo <- mkFromBit();
    requestPipeIn[0] = toPipeIn(initDone_requestFifo);

    FromBit#(32,RdDone_Message) rdDone_requestFifo <- mkFromBit();
    requestPipeIn[1] = toPipeIn(rdDone_requestFifo);

    FromBit#(32,WrDone_Message) wrDone_requestFifo <- mkFromBit();
    requestPipeIn[2] = toPipeIn(wrDone_requestFifo);

    FromBit#(32,SendData_0_Message) sendData_0_requestFifo <- mkFromBit();
    requestPipeIn[3] = toPipeIn(sendData_0_requestFifo);

    FromBit#(32,ElementReq_0_Message) elementReq_0_requestFifo <- mkFromBit();
    requestPipeIn[4] = toPipeIn(elementReq_0_requestFifo);

    FromBit#(32,SendData_1_Message) sendData_1_requestFifo <- mkFromBit();
    requestPipeIn[5] = toPipeIn(sendData_1_requestFifo);

    FromBit#(32,ElementReq_1_Message) elementReq_1_requestFifo <- mkFromBit();
    requestPipeIn[6] = toPipeIn(elementReq_1_requestFifo);

    FromBit#(32,SendData_2_Message) sendData_2_requestFifo <- mkFromBit();
    requestPipeIn[7] = toPipeIn(sendData_2_requestFifo);

    FromBit#(32,ElementReq_2_Message) elementReq_2_requestFifo <- mkFromBit();
    requestPipeIn[8] = toPipeIn(elementReq_2_requestFifo);

    interface PipePortal portalIfc;
        method Bit#(16) messageSize(Bit#(16) methodNumber);
            case (methodNumber)
            0: return fromInteger(valueOf(SizeOf#(InitDone_Message)));
            1: return fromInteger(valueOf(SizeOf#(RdDone_Message)));
            2: return fromInteger(valueOf(SizeOf#(WrDone_Message)));
            3: return fromInteger(valueOf(SizeOf#(SendData_0_Message)));
            4: return fromInteger(valueOf(SizeOf#(ElementReq_0_Message)));
            5: return fromInteger(valueOf(SizeOf#(SendData_1_Message)));
            6: return fromInteger(valueOf(SizeOf#(ElementReq_1_Message)));
            7: return fromInteger(valueOf(SizeOf#(SendData_2_Message)));
            8: return fromInteger(valueOf(SizeOf#(ElementReq_2_Message)));
            endcase
        endmethod
        interface Vector requests = requestPipeIn;
        interface Vector indications = nil;
    endinterface
    interface initDone_PipeOut = toPipeOut(initDone_requestFifo);
    interface rdDone_PipeOut = toPipeOut(rdDone_requestFifo);
    interface wrDone_PipeOut = toPipeOut(wrDone_requestFifo);
    interface sendData_0_PipeOut = toPipeOut(sendData_0_requestFifo);
    interface elementReq_0_PipeOut = toPipeOut(elementReq_0_requestFifo);
    interface sendData_1_PipeOut = toPipeOut(sendData_1_requestFifo);
    interface elementReq_1_PipeOut = toPipeOut(elementReq_1_requestFifo);
    interface sendData_2_PipeOut = toPipeOut(sendData_2_requestFifo);
    interface elementReq_2_PipeOut = toPipeOut(elementReq_2_requestFifo);
endmodule

module mkBluecacheIndicationWrapperPortal#(idType id, BluecacheIndication ifc)(BluecacheIndicationWrapperPortal)
    provisos (Bits#(idType, __a),
              Add#(a__, __a, 32));
    let pipes <- mkBluecacheIndicationWrapperPipes(zeroExtend(pack(id)));
    mkConnection(pipes, ifc);
    interface PipePortal portalIfc = pipes.portalIfc;
endmodule

interface BluecacheIndicationWrapperMemPortalPipes;
    interface BluecacheIndicationWrapperPipes pipes;
    interface MemPortal#(16,32) portalIfc;
endinterface

(* synthesize *)
module mkBluecacheIndicationWrapperMemPortalPipes#(Bit#(32) id)(BluecacheIndicationWrapperMemPortalPipes);

  let p <- mkBluecacheIndicationWrapperPipes(zeroExtend(pack(id)));
  let memPortal <- mkMemPortal(id, p.portalIfc);
  interface BluecacheIndicationWrapperPipes pipes = p;
  interface MemPortal portalIfc = memPortal;
endmodule

// exposed wrapper MemPortal implementation
module mkBluecacheIndicationWrapper#(idType id, BluecacheIndication ifc)(BluecacheIndicationWrapper)
   provisos (Bits#(idType, a__),
	     Add#(b__, a__, 32));
  let dut <- mkBluecacheIndicationWrapperMemPortalPipes(zeroExtend(pack(id)));
  mkConnection(dut.pipes, ifc);
  interface MemPortal portalIfc = dut.portalIfc;
endmodule

// exposed proxy interface
interface BluecacheIndicationProxyPortal;
    interface PipePortal#(0, 9, 32) portalIfc;
    interface Bluecache::BluecacheIndication ifc;
endinterface
interface BluecacheIndicationProxy;
    interface StdPortal portalIfc;
    interface Bluecache::BluecacheIndication ifc;
endinterface

(* synthesize *)
module  mkBluecacheIndicationProxyPortalSynth#(Bit#(32) id) (BluecacheIndicationProxyPortal);
    Vector#(9, PipeOut#(Bit#(32))) indicationPipes = newVector();

    ToBit#(32,InitDone_Message) initDone_responseFifo <- mkToBit();
    indicationPipes[0] = toPipeOut(initDone_responseFifo);

    ToBit#(32,RdDone_Message) rdDone_responseFifo <- mkToBit();
    indicationPipes[1] = toPipeOut(rdDone_responseFifo);

    ToBit#(32,WrDone_Message) wrDone_responseFifo <- mkToBit();
    indicationPipes[2] = toPipeOut(wrDone_responseFifo);

    ToBit#(32,SendData_0_Message) sendData_0_responseFifo <- mkToBit();
    indicationPipes[3] = toPipeOut(sendData_0_responseFifo);

    ToBit#(32,ElementReq_0_Message) elementReq_0_responseFifo <- mkToBit();
    indicationPipes[4] = toPipeOut(elementReq_0_responseFifo);

    ToBit#(32,SendData_1_Message) sendData_1_responseFifo <- mkToBit();
    indicationPipes[5] = toPipeOut(sendData_1_responseFifo);

    ToBit#(32,ElementReq_1_Message) elementReq_1_responseFifo <- mkToBit();
    indicationPipes[6] = toPipeOut(elementReq_1_responseFifo);

    ToBit#(32,SendData_2_Message) sendData_2_responseFifo <- mkToBit();
    indicationPipes[7] = toPipeOut(sendData_2_responseFifo);

    ToBit#(32,ElementReq_2_Message) elementReq_2_responseFifo <- mkToBit();
    indicationPipes[8] = toPipeOut(elementReq_2_responseFifo);

    interface Bluecache::BluecacheIndication ifc;

    method Action initDone(Bit#(32) dummy);
        initDone_responseFifo.enq(InitDone_Message {dummy: dummy});
        //$display("indicationMethod 'initDone' invoked");
    endmethod
    method Action rdDone(Bit#(32) bufId);
        rdDone_responseFifo.enq(RdDone_Message {bufId: bufId});
        //$display("indicationMethod 'rdDone' invoked");
    endmethod
    method Action wrDone(Bit#(32) bufId);
        wrDone_responseFifo.enq(WrDone_Message {bufId: bufId});
        //$display("indicationMethod 'wrDone' invoked");
    endmethod
    method Action sendData_0(Bit#(32) v);
        sendData_0_responseFifo.enq(SendData_0_Message {v: v});
        //$display("indicationMethod 'sendData_0' invoked");
    endmethod
    method Action elementReq_0(Bit#(32) v);
        elementReq_0_responseFifo.enq(ElementReq_0_Message {v: v});
        //$display("indicationMethod 'elementReq_0' invoked");
    endmethod
    method Action sendData_1(Bit#(32) v);
        sendData_1_responseFifo.enq(SendData_1_Message {v: v});
        //$display("indicationMethod 'sendData_1' invoked");
    endmethod
    method Action elementReq_1(Bit#(32) v);
        elementReq_1_responseFifo.enq(ElementReq_1_Message {v: v});
        //$display("indicationMethod 'elementReq_1' invoked");
    endmethod
    method Action sendData_2(Bit#(32) v);
        sendData_2_responseFifo.enq(SendData_2_Message {v: v});
        //$display("indicationMethod 'sendData_2' invoked");
    endmethod
    method Action elementReq_2(Bit#(32) v);
        elementReq_2_responseFifo.enq(ElementReq_2_Message {v: v});
        //$display("indicationMethod 'elementReq_2' invoked");
    endmethod
    endinterface
    interface PipePortal portalIfc;
        method Bit#(16) messageSize(Bit#(16) methodNumber);
            case (methodNumber)
            0: return fromInteger(valueOf(SizeOf#(InitDone_Message)));
            1: return fromInteger(valueOf(SizeOf#(RdDone_Message)));
            2: return fromInteger(valueOf(SizeOf#(WrDone_Message)));
            3: return fromInteger(valueOf(SizeOf#(SendData_0_Message)));
            4: return fromInteger(valueOf(SizeOf#(ElementReq_0_Message)));
            5: return fromInteger(valueOf(SizeOf#(SendData_1_Message)));
            6: return fromInteger(valueOf(SizeOf#(ElementReq_1_Message)));
            7: return fromInteger(valueOf(SizeOf#(SendData_2_Message)));
            8: return fromInteger(valueOf(SizeOf#(ElementReq_2_Message)));
            endcase
        endmethod
        interface Vector requests = nil;
        interface Vector indications = indicationPipes;
    endinterface
endmodule

// exposed proxy implementation
module  mkBluecacheIndicationProxyPortal#(idType id) (BluecacheIndicationProxyPortal)
    provisos (Bits#(idType, __a),
              Add#(a__, __a, 32));
    let rv <- mkBluecacheIndicationProxyPortalSynth(extend(pack(id)));
    return rv;
endmodule

// synthesizeable proxy MemPortal
(* synthesize *)
module mkBluecacheIndicationProxySynth#(Bit#(32) id)(BluecacheIndicationProxy);
  let dut <- mkBluecacheIndicationProxyPortal(id);
  let memPortal <- mkMemPortal(id, dut.portalIfc);
  interface MemPortal portalIfc = memPortal;
  interface Bluecache::BluecacheIndication ifc = dut.ifc;
endmodule

// exposed proxy MemPortal
module mkBluecacheIndicationProxy#(idType id)(BluecacheIndicationProxy)
   provisos (Bits#(idType, a__),
	     Add#(b__, a__, 32));
   let rv <- mkBluecacheIndicationProxySynth(extend(pack(id)));
   return rv;
endmodule
endpackage: BluecacheIndication
