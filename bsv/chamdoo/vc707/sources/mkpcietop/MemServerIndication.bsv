package MemServerIndication;

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
import MMUIndication::*;
import Bluecache::*;
import XilinxVC707DDR3::*;
import DRAMController::*;




typedef struct {
    Bit#(64) physAddr;
} AddrResponse_Message deriving (Bits);

typedef struct {
    DmaDbgRec rec;
} ReportStateDbg_Message deriving (Bits);

typedef struct {
    Bit#(64) words;
} ReportMemoryTraffic_Message deriving (Bits);

typedef struct {
    Bit#(32) code;
    Bit#(32) sglId;
    Bit#(64) offset;
    Bit#(64) extra;
} Error_Message deriving (Bits);

// exposed wrapper portal interface
interface MemServerIndicationWrapperPipes;
    interface PipePortal#(4, 0, 32) portalIfc;
    interface PipeOut#(AddrResponse_Message) addrResponse_PipeOut;
    interface PipeOut#(ReportStateDbg_Message) reportStateDbg_PipeOut;
    interface PipeOut#(ReportMemoryTraffic_Message) reportMemoryTraffic_PipeOut;
    interface PipeOut#(Error_Message) error_PipeOut;

endinterface
interface MemServerIndicationWrapperPortal;
    interface PipePortal#(4, 0, 32) portalIfc;
endinterface
// exposed wrapper MemPortal interface
interface MemServerIndicationWrapper;
    interface StdPortal portalIfc;
endinterface

instance Connectable#(MemServerIndicationWrapperPipes,MemServerIndication);
   module mkConnection#(MemServerIndicationWrapperPipes pipes, MemServerIndication ifc)(Empty);

    rule handle_addrResponse_request;
        let request <- toGet(pipes.addrResponse_PipeOut).get();
        ifc.addrResponse(request.physAddr);
    endrule

    rule handle_reportStateDbg_request;
        let request <- toGet(pipes.reportStateDbg_PipeOut).get();
        ifc.reportStateDbg(request.rec);
    endrule

    rule handle_reportMemoryTraffic_request;
        let request <- toGet(pipes.reportMemoryTraffic_PipeOut).get();
        ifc.reportMemoryTraffic(request.words);
    endrule

    rule handle_error_request;
        let request <- toGet(pipes.error_PipeOut).get();
        ifc.error(request.code, request.sglId, request.offset, request.extra);
    endrule

   endmodule
endinstance

// exposed wrapper Portal implementation
(* synthesize *)
module mkMemServerIndicationWrapperPipes#(Bit#(32) id)(MemServerIndicationWrapperPipes);
    Vector#(4, PipeIn#(Bit#(32))) requestPipeIn = newVector();

    FromBit#(32,AddrResponse_Message) addrResponse_requestFifo <- mkFromBit();
    requestPipeIn[0] = toPipeIn(addrResponse_requestFifo);

    FromBit#(32,ReportStateDbg_Message) reportStateDbg_requestFifo <- mkFromBit();
    requestPipeIn[1] = toPipeIn(reportStateDbg_requestFifo);

    FromBit#(32,ReportMemoryTraffic_Message) reportMemoryTraffic_requestFifo <- mkFromBit();
    requestPipeIn[2] = toPipeIn(reportMemoryTraffic_requestFifo);

    FromBit#(32,Error_Message) error_requestFifo <- mkFromBit();
    requestPipeIn[3] = toPipeIn(error_requestFifo);

    interface PipePortal portalIfc;
        method Bit#(16) messageSize(Bit#(16) methodNumber);
            case (methodNumber)
            0: return fromInteger(valueOf(SizeOf#(AddrResponse_Message)));
            1: return fromInteger(valueOf(SizeOf#(ReportStateDbg_Message)));
            2: return fromInteger(valueOf(SizeOf#(ReportMemoryTraffic_Message)));
            3: return fromInteger(valueOf(SizeOf#(Error_Message)));
            endcase
        endmethod
        interface Vector requests = requestPipeIn;
        interface Vector indications = nil;
    endinterface
    interface addrResponse_PipeOut = toPipeOut(addrResponse_requestFifo);
    interface reportStateDbg_PipeOut = toPipeOut(reportStateDbg_requestFifo);
    interface reportMemoryTraffic_PipeOut = toPipeOut(reportMemoryTraffic_requestFifo);
    interface error_PipeOut = toPipeOut(error_requestFifo);
endmodule

module mkMemServerIndicationWrapperPortal#(idType id, MemServerIndication ifc)(MemServerIndicationWrapperPortal)
    provisos (Bits#(idType, __a),
              Add#(a__, __a, 32));
    let pipes <- mkMemServerIndicationWrapperPipes(zeroExtend(pack(id)));
    mkConnection(pipes, ifc);
    interface PipePortal portalIfc = pipes.portalIfc;
endmodule

interface MemServerIndicationWrapperMemPortalPipes;
    interface MemServerIndicationWrapperPipes pipes;
    interface MemPortal#(16,32) portalIfc;
endinterface

(* synthesize *)
module mkMemServerIndicationWrapperMemPortalPipes#(Bit#(32) id)(MemServerIndicationWrapperMemPortalPipes);

  let p <- mkMemServerIndicationWrapperPipes(zeroExtend(pack(id)));
  let memPortal <- mkMemPortal(id, p.portalIfc);
  interface MemServerIndicationWrapperPipes pipes = p;
  interface MemPortal portalIfc = memPortal;
endmodule

// exposed wrapper MemPortal implementation
module mkMemServerIndicationWrapper#(idType id, MemServerIndication ifc)(MemServerIndicationWrapper)
   provisos (Bits#(idType, a__),
	     Add#(b__, a__, 32));
  let dut <- mkMemServerIndicationWrapperMemPortalPipes(zeroExtend(pack(id)));
  mkConnection(dut.pipes, ifc);
  interface MemPortal portalIfc = dut.portalIfc;
endmodule

// exposed proxy interface
interface MemServerIndicationProxyPortal;
    interface PipePortal#(0, 4, 32) portalIfc;
    interface ConnectalMemory::MemServerIndication ifc;
endinterface
interface MemServerIndicationProxy;
    interface StdPortal portalIfc;
    interface ConnectalMemory::MemServerIndication ifc;
endinterface

(* synthesize *)
module  mkMemServerIndicationProxyPortalSynth#(Bit#(32) id) (MemServerIndicationProxyPortal);
    Vector#(4, PipeOut#(Bit#(32))) indicationPipes = newVector();

    ToBit#(32,AddrResponse_Message) addrResponse_responseFifo <- mkToBit();
    indicationPipes[0] = toPipeOut(addrResponse_responseFifo);

    ToBit#(32,ReportStateDbg_Message) reportStateDbg_responseFifo <- mkToBit();
    indicationPipes[1] = toPipeOut(reportStateDbg_responseFifo);

    ToBit#(32,ReportMemoryTraffic_Message) reportMemoryTraffic_responseFifo <- mkToBit();
    indicationPipes[2] = toPipeOut(reportMemoryTraffic_responseFifo);

    ToBit#(32,Error_Message) error_responseFifo <- mkToBit();
    indicationPipes[3] = toPipeOut(error_responseFifo);

    interface ConnectalMemory::MemServerIndication ifc;

    method Action addrResponse(Bit#(64) physAddr);
        addrResponse_responseFifo.enq(AddrResponse_Message {physAddr: physAddr});
        //$display("indicationMethod 'addrResponse' invoked");
    endmethod
    method Action reportStateDbg(DmaDbgRec rec);
        reportStateDbg_responseFifo.enq(ReportStateDbg_Message {rec: rec});
        //$display("indicationMethod 'reportStateDbg' invoked");
    endmethod
    method Action reportMemoryTraffic(Bit#(64) words);
        reportMemoryTraffic_responseFifo.enq(ReportMemoryTraffic_Message {words: words});
        //$display("indicationMethod 'reportMemoryTraffic' invoked");
    endmethod
    method Action error(Bit#(32) code, Bit#(32) sglId, Bit#(64) offset, Bit#(64) extra);
        error_responseFifo.enq(Error_Message {code: code, sglId: sglId, offset: offset, extra: extra});
        //$display("indicationMethod 'error' invoked");
    endmethod
    endinterface
    interface PipePortal portalIfc;
        method Bit#(16) messageSize(Bit#(16) methodNumber);
            case (methodNumber)
            0: return fromInteger(valueOf(SizeOf#(AddrResponse_Message)));
            1: return fromInteger(valueOf(SizeOf#(ReportStateDbg_Message)));
            2: return fromInteger(valueOf(SizeOf#(ReportMemoryTraffic_Message)));
            3: return fromInteger(valueOf(SizeOf#(Error_Message)));
            endcase
        endmethod
        interface Vector requests = nil;
        interface Vector indications = indicationPipes;
    endinterface
endmodule

// exposed proxy implementation
module  mkMemServerIndicationProxyPortal#(idType id) (MemServerIndicationProxyPortal)
    provisos (Bits#(idType, __a),
              Add#(a__, __a, 32));
    let rv <- mkMemServerIndicationProxyPortalSynth(extend(pack(id)));
    return rv;
endmodule

// synthesizeable proxy MemPortal
(* synthesize *)
module mkMemServerIndicationProxySynth#(Bit#(32) id)(MemServerIndicationProxy);
  let dut <- mkMemServerIndicationProxyPortal(id);
  let memPortal <- mkMemPortal(id, dut.portalIfc);
  interface MemPortal portalIfc = memPortal;
  interface ConnectalMemory::MemServerIndication ifc = dut.ifc;
endmodule

// exposed proxy MemPortal
module mkMemServerIndicationProxy#(idType id)(MemServerIndicationProxy)
   provisos (Bits#(idType, a__),
	     Add#(b__, a__, 32));
   let rv <- mkMemServerIndicationProxySynth(extend(pack(id)));
   return rv;
endmodule
endpackage: MemServerIndication
