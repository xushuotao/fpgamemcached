package MMUIndication;

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
import Bluecache::*;
import XilinxVC707DDR3::*;
import DRAMController::*;




typedef struct {
    Bit#(32) sglId;
} IdResponse_Message deriving (Bits);

typedef struct {
    Bit#(32) sglId;
} ConfigResp_Message deriving (Bits);

typedef struct {
    Bit#(32) code;
    Bit#(32) sglId;
    Bit#(64) offset;
    Bit#(64) extra;
} Error_Message deriving (Bits);

// exposed wrapper portal interface
interface MMUIndicationWrapperPipes;
    interface PipePortal#(3, 0, 32) portalIfc;
    interface PipeOut#(IdResponse_Message) idResponse_PipeOut;
    interface PipeOut#(ConfigResp_Message) configResp_PipeOut;
    interface PipeOut#(Error_Message) error_PipeOut;

endinterface
interface MMUIndicationWrapperPortal;
    interface PipePortal#(3, 0, 32) portalIfc;
endinterface
// exposed wrapper MemPortal interface
interface MMUIndicationWrapper;
    interface StdPortal portalIfc;
endinterface

instance Connectable#(MMUIndicationWrapperPipes,MMUIndication);
   module mkConnection#(MMUIndicationWrapperPipes pipes, MMUIndication ifc)(Empty);

    rule handle_idResponse_request;
        let request <- toGet(pipes.idResponse_PipeOut).get();
        ifc.idResponse(request.sglId);
    endrule

    rule handle_configResp_request;
        let request <- toGet(pipes.configResp_PipeOut).get();
        ifc.configResp(request.sglId);
    endrule

    rule handle_error_request;
        let request <- toGet(pipes.error_PipeOut).get();
        ifc.error(request.code, request.sglId, request.offset, request.extra);
    endrule

   endmodule
endinstance

// exposed wrapper Portal implementation
(* synthesize *)
module mkMMUIndicationWrapperPipes#(Bit#(32) id)(MMUIndicationWrapperPipes);
    Vector#(3, PipeIn#(Bit#(32))) requestPipeIn = newVector();

    FromBit#(32,IdResponse_Message) idResponse_requestFifo <- mkFromBit();
    requestPipeIn[0] = toPipeIn(idResponse_requestFifo);

    FromBit#(32,ConfigResp_Message) configResp_requestFifo <- mkFromBit();
    requestPipeIn[1] = toPipeIn(configResp_requestFifo);

    FromBit#(32,Error_Message) error_requestFifo <- mkFromBit();
    requestPipeIn[2] = toPipeIn(error_requestFifo);

    interface PipePortal portalIfc;
        method Bit#(16) messageSize(Bit#(16) methodNumber);
            case (methodNumber)
            0: return fromInteger(valueOf(SizeOf#(IdResponse_Message)));
            1: return fromInteger(valueOf(SizeOf#(ConfigResp_Message)));
            2: return fromInteger(valueOf(SizeOf#(Error_Message)));
            endcase
        endmethod
        interface Vector requests = requestPipeIn;
        interface Vector indications = nil;
    endinterface
    interface idResponse_PipeOut = toPipeOut(idResponse_requestFifo);
    interface configResp_PipeOut = toPipeOut(configResp_requestFifo);
    interface error_PipeOut = toPipeOut(error_requestFifo);
endmodule

module mkMMUIndicationWrapperPortal#(idType id, MMUIndication ifc)(MMUIndicationWrapperPortal)
    provisos (Bits#(idType, __a),
              Add#(a__, __a, 32));
    let pipes <- mkMMUIndicationWrapperPipes(zeroExtend(pack(id)));
    mkConnection(pipes, ifc);
    interface PipePortal portalIfc = pipes.portalIfc;
endmodule

interface MMUIndicationWrapperMemPortalPipes;
    interface MMUIndicationWrapperPipes pipes;
    interface MemPortal#(16,32) portalIfc;
endinterface

(* synthesize *)
module mkMMUIndicationWrapperMemPortalPipes#(Bit#(32) id)(MMUIndicationWrapperMemPortalPipes);

  let p <- mkMMUIndicationWrapperPipes(zeroExtend(pack(id)));
  let memPortal <- mkMemPortal(id, p.portalIfc);
  interface MMUIndicationWrapperPipes pipes = p;
  interface MemPortal portalIfc = memPortal;
endmodule

// exposed wrapper MemPortal implementation
module mkMMUIndicationWrapper#(idType id, MMUIndication ifc)(MMUIndicationWrapper)
   provisos (Bits#(idType, a__),
	     Add#(b__, a__, 32));
  let dut <- mkMMUIndicationWrapperMemPortalPipes(zeroExtend(pack(id)));
  mkConnection(dut.pipes, ifc);
  interface MemPortal portalIfc = dut.portalIfc;
endmodule

// exposed proxy interface
interface MMUIndicationProxyPortal;
    interface PipePortal#(0, 3, 32) portalIfc;
    interface ConnectalMemory::MMUIndication ifc;
endinterface
interface MMUIndicationProxy;
    interface StdPortal portalIfc;
    interface ConnectalMemory::MMUIndication ifc;
endinterface

(* synthesize *)
module  mkMMUIndicationProxyPortalSynth#(Bit#(32) id) (MMUIndicationProxyPortal);
    Vector#(3, PipeOut#(Bit#(32))) indicationPipes = newVector();

    ToBit#(32,IdResponse_Message) idResponse_responseFifo <- mkToBit();
    indicationPipes[0] = toPipeOut(idResponse_responseFifo);

    ToBit#(32,ConfigResp_Message) configResp_responseFifo <- mkToBit();
    indicationPipes[1] = toPipeOut(configResp_responseFifo);

    ToBit#(32,Error_Message) error_responseFifo <- mkToBit();
    indicationPipes[2] = toPipeOut(error_responseFifo);

    interface ConnectalMemory::MMUIndication ifc;

    method Action idResponse(Bit#(32) sglId);
        idResponse_responseFifo.enq(IdResponse_Message {sglId: sglId});
        //$display("indicationMethod 'idResponse' invoked");
    endmethod
    method Action configResp(Bit#(32) sglId);
        configResp_responseFifo.enq(ConfigResp_Message {sglId: sglId});
        //$display("indicationMethod 'configResp' invoked");
    endmethod
    method Action error(Bit#(32) code, Bit#(32) sglId, Bit#(64) offset, Bit#(64) extra);
        error_responseFifo.enq(Error_Message {code: code, sglId: sglId, offset: offset, extra: extra});
        //$display("indicationMethod 'error' invoked");
    endmethod
    endinterface
    interface PipePortal portalIfc;
        method Bit#(16) messageSize(Bit#(16) methodNumber);
            case (methodNumber)
            0: return fromInteger(valueOf(SizeOf#(IdResponse_Message)));
            1: return fromInteger(valueOf(SizeOf#(ConfigResp_Message)));
            2: return fromInteger(valueOf(SizeOf#(Error_Message)));
            endcase
        endmethod
        interface Vector requests = nil;
        interface Vector indications = indicationPipes;
    endinterface
endmodule

// exposed proxy implementation
module  mkMMUIndicationProxyPortal#(idType id) (MMUIndicationProxyPortal)
    provisos (Bits#(idType, __a),
              Add#(a__, __a, 32));
    let rv <- mkMMUIndicationProxyPortalSynth(extend(pack(id)));
    return rv;
endmodule

// synthesizeable proxy MemPortal
(* synthesize *)
module mkMMUIndicationProxySynth#(Bit#(32) id)(MMUIndicationProxy);
  let dut <- mkMMUIndicationProxyPortal(id);
  let memPortal <- mkMemPortal(id, dut.portalIfc);
  interface MemPortal portalIfc = memPortal;
  interface ConnectalMemory::MMUIndication ifc = dut.ifc;
endmodule

// exposed proxy MemPortal
module mkMMUIndicationProxy#(idType id)(MMUIndicationProxy)
   provisos (Bits#(idType, a__),
	     Add#(b__, a__, 32));
   let rv <- mkMMUIndicationProxySynth(extend(pack(id)));
   return rv;
endmodule
endpackage: MMUIndication
