package MemServerRequest;

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
import ConnectalMemory::*;
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
import MMURequest::*;
import MemServerIndication::*;
import MMUIndication::*;
import Bluecache::*;
import XilinxVC707DDR3::*;
import DRAMController::*;




typedef struct {
    Bit#(32) sglId;
    Bit#(32) offset;
} AddrTrans_Message deriving (Bits);

typedef struct {
    ChannelType rc;
} StateDbg_Message deriving (Bits);

typedef struct {
    ChannelType rc;
} MemoryTraffic_Message deriving (Bits);

// exposed wrapper portal interface
interface MemServerRequestWrapperPipes;
    interface PipePortal#(3, 0, 32) portalIfc;
    interface PipeOut#(AddrTrans_Message) addrTrans_PipeOut;
    interface PipeOut#(StateDbg_Message) stateDbg_PipeOut;
    interface PipeOut#(MemoryTraffic_Message) memoryTraffic_PipeOut;

endinterface
interface MemServerRequestWrapperPortal;
    interface PipePortal#(3, 0, 32) portalIfc;
endinterface
// exposed wrapper MemPortal interface
interface MemServerRequestWrapper;
    interface StdPortal portalIfc;
endinterface

instance Connectable#(MemServerRequestWrapperPipes,MemServerRequest);
   module mkConnection#(MemServerRequestWrapperPipes pipes, MemServerRequest ifc)(Empty);

    rule handle_addrTrans_request;
        let request <- toGet(pipes.addrTrans_PipeOut).get();
        ifc.addrTrans(request.sglId, request.offset);
    endrule

    rule handle_stateDbg_request;
        let request <- toGet(pipes.stateDbg_PipeOut).get();
        ifc.stateDbg(request.rc);
    endrule

    rule handle_memoryTraffic_request;
        let request <- toGet(pipes.memoryTraffic_PipeOut).get();
        ifc.memoryTraffic(request.rc);
    endrule

   endmodule
endinstance

// exposed wrapper Portal implementation
(* synthesize *)
module mkMemServerRequestWrapperPipes#(Bit#(32) id)(MemServerRequestWrapperPipes);
    Vector#(3, PipeIn#(Bit#(32))) requestPipeIn = newVector();

    FromBit#(32,AddrTrans_Message) addrTrans_requestFifo <- mkFromBit();
    requestPipeIn[0] = toPipeIn(addrTrans_requestFifo);

    FromBit#(32,StateDbg_Message) stateDbg_requestFifo <- mkFromBit();
    requestPipeIn[1] = toPipeIn(stateDbg_requestFifo);

    FromBit#(32,MemoryTraffic_Message) memoryTraffic_requestFifo <- mkFromBit();
    requestPipeIn[2] = toPipeIn(memoryTraffic_requestFifo);

    interface PipePortal portalIfc;
        method Bit#(16) messageSize(Bit#(16) methodNumber);
            case (methodNumber)
            0: return fromInteger(valueOf(SizeOf#(AddrTrans_Message)));
            1: return fromInteger(valueOf(SizeOf#(StateDbg_Message)));
            2: return fromInteger(valueOf(SizeOf#(MemoryTraffic_Message)));
            endcase
        endmethod
        interface Vector requests = requestPipeIn;
        interface Vector indications = nil;
    endinterface
    interface addrTrans_PipeOut = toPipeOut(addrTrans_requestFifo);
    interface stateDbg_PipeOut = toPipeOut(stateDbg_requestFifo);
    interface memoryTraffic_PipeOut = toPipeOut(memoryTraffic_requestFifo);
endmodule

module mkMemServerRequestWrapperPortal#(idType id, MemServerRequest ifc)(MemServerRequestWrapperPortal)
    provisos (Bits#(idType, __a),
              Add#(a__, __a, 32));
    let pipes <- mkMemServerRequestWrapperPipes(zeroExtend(pack(id)));
    mkConnection(pipes, ifc);
    interface PipePortal portalIfc = pipes.portalIfc;
endmodule

interface MemServerRequestWrapperMemPortalPipes;
    interface MemServerRequestWrapperPipes pipes;
    interface MemPortal#(16,32) portalIfc;
endinterface

(* synthesize *)
module mkMemServerRequestWrapperMemPortalPipes#(Bit#(32) id)(MemServerRequestWrapperMemPortalPipes);

  let p <- mkMemServerRequestWrapperPipes(zeroExtend(pack(id)));
  let memPortal <- mkMemPortal(id, p.portalIfc);
  interface MemServerRequestWrapperPipes pipes = p;
  interface MemPortal portalIfc = memPortal;
endmodule

// exposed wrapper MemPortal implementation
module mkMemServerRequestWrapper#(idType id, MemServerRequest ifc)(MemServerRequestWrapper)
   provisos (Bits#(idType, a__),
	     Add#(b__, a__, 32));
  let dut <- mkMemServerRequestWrapperMemPortalPipes(zeroExtend(pack(id)));
  mkConnection(dut.pipes, ifc);
  interface MemPortal portalIfc = dut.portalIfc;
endmodule

// exposed proxy interface
interface MemServerRequestProxyPortal;
    interface PipePortal#(0, 3, 32) portalIfc;
    interface ConnectalMemory::MemServerRequest ifc;
endinterface
interface MemServerRequestProxy;
    interface StdPortal portalIfc;
    interface ConnectalMemory::MemServerRequest ifc;
endinterface

(* synthesize *)
module  mkMemServerRequestProxyPortalSynth#(Bit#(32) id) (MemServerRequestProxyPortal);
    Vector#(3, PipeOut#(Bit#(32))) indicationPipes = newVector();

    ToBit#(32,AddrTrans_Message) addrTrans_responseFifo <- mkToBit();
    indicationPipes[0] = toPipeOut(addrTrans_responseFifo);

    ToBit#(32,StateDbg_Message) stateDbg_responseFifo <- mkToBit();
    indicationPipes[1] = toPipeOut(stateDbg_responseFifo);

    ToBit#(32,MemoryTraffic_Message) memoryTraffic_responseFifo <- mkToBit();
    indicationPipes[2] = toPipeOut(memoryTraffic_responseFifo);

    interface ConnectalMemory::MemServerRequest ifc;

    method Action addrTrans(Bit#(32) sglId, Bit#(32) offset);
        addrTrans_responseFifo.enq(AddrTrans_Message {sglId: sglId, offset: offset});
        //$display("indicationMethod 'addrTrans' invoked");
    endmethod
    method Action stateDbg(ChannelType rc);
        stateDbg_responseFifo.enq(StateDbg_Message {rc: rc});
        //$display("indicationMethod 'stateDbg' invoked");
    endmethod
    method Action memoryTraffic(ChannelType rc);
        memoryTraffic_responseFifo.enq(MemoryTraffic_Message {rc: rc});
        //$display("indicationMethod 'memoryTraffic' invoked");
    endmethod
    endinterface
    interface PipePortal portalIfc;
        method Bit#(16) messageSize(Bit#(16) methodNumber);
            case (methodNumber)
            0: return fromInteger(valueOf(SizeOf#(AddrTrans_Message)));
            1: return fromInteger(valueOf(SizeOf#(StateDbg_Message)));
            2: return fromInteger(valueOf(SizeOf#(MemoryTraffic_Message)));
            endcase
        endmethod
        interface Vector requests = nil;
        interface Vector indications = indicationPipes;
    endinterface
endmodule

// exposed proxy implementation
module  mkMemServerRequestProxyPortal#(idType id) (MemServerRequestProxyPortal)
    provisos (Bits#(idType, __a),
              Add#(a__, __a, 32));
    let rv <- mkMemServerRequestProxyPortalSynth(extend(pack(id)));
    return rv;
endmodule

// synthesizeable proxy MemPortal
(* synthesize *)
module mkMemServerRequestProxySynth#(Bit#(32) id)(MemServerRequestProxy);
  let dut <- mkMemServerRequestProxyPortal(id);
  let memPortal <- mkMemPortal(id, dut.portalIfc);
  interface MemPortal portalIfc = memPortal;
  interface ConnectalMemory::MemServerRequest ifc = dut.ifc;
endmodule

// exposed proxy MemPortal
module mkMemServerRequestProxy#(idType id)(MemServerRequestProxy)
   provisos (Bits#(idType, a__),
	     Add#(b__, a__, 32));
   let rv <- mkMemServerRequestProxySynth(extend(pack(id)));
   return rv;
endmodule
endpackage: MemServerRequest
