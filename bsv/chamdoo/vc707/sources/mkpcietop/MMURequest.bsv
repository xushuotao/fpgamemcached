package MMURequest;

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
import MemServerIndication::*;
import MMUIndication::*;
import Bluecache::*;
import XilinxVC707DDR3::*;
import DRAMController::*;




typedef struct {
    Bit#(32) sglId;
    Bit#(32) sglIndex;
    Bit#(64) addr;
    Bit#(32) len;
} Sglist_Message deriving (Bits);

typedef struct {
    Bit#(32) sglId;
    Bit#(64) barr8;
    Bit#(32) index8;
    Bit#(64) barr4;
    Bit#(32) index4;
    Bit#(64) barr0;
    Bit#(32) index0;
} Region_Message deriving (Bits);

typedef struct {
    SpecialTypeForSendingFd fd;
} IdRequest_Message deriving (Bits);

typedef struct {
    Bit#(32) sglId;
} IdReturn_Message deriving (Bits);

typedef struct {
    Bit#(32) interfaceId;
    Bit#(32) sglId;
} SetInterface_Message deriving (Bits);

// exposed wrapper portal interface
interface MMURequestWrapperPipes;
    interface PipePortal#(5, 0, 32) portalIfc;
    interface PipeOut#(Sglist_Message) sglist_PipeOut;
    interface PipeOut#(Region_Message) region_PipeOut;
    interface PipeOut#(IdRequest_Message) idRequest_PipeOut;
    interface PipeOut#(IdReturn_Message) idReturn_PipeOut;
    interface PipeOut#(SetInterface_Message) setInterface_PipeOut;

endinterface
interface MMURequestWrapperPortal;
    interface PipePortal#(5, 0, 32) portalIfc;
endinterface
// exposed wrapper MemPortal interface
interface MMURequestWrapper;
    interface StdPortal portalIfc;
endinterface

instance Connectable#(MMURequestWrapperPipes,MMURequest);
   module mkConnection#(MMURequestWrapperPipes pipes, MMURequest ifc)(Empty);

    rule handle_sglist_request;
        let request <- toGet(pipes.sglist_PipeOut).get();
        ifc.sglist(request.sglId, request.sglIndex, request.addr, request.len);
    endrule

    rule handle_region_request;
        let request <- toGet(pipes.region_PipeOut).get();
        ifc.region(request.sglId, request.barr8, request.index8, request.barr4, request.index4, request.barr0, request.index0);
    endrule

    rule handle_idRequest_request;
        let request <- toGet(pipes.idRequest_PipeOut).get();
        ifc.idRequest(request.fd);
    endrule

    rule handle_idReturn_request;
        let request <- toGet(pipes.idReturn_PipeOut).get();
        ifc.idReturn(request.sglId);
    endrule

    rule handle_setInterface_request;
        let request <- toGet(pipes.setInterface_PipeOut).get();
        ifc.setInterface(request.interfaceId, request.sglId);
    endrule

   endmodule
endinstance

// exposed wrapper Portal implementation
(* synthesize *)
module mkMMURequestWrapperPipes#(Bit#(32) id)(MMURequestWrapperPipes);
    Vector#(5, PipeIn#(Bit#(32))) requestPipeIn = newVector();

    FromBit#(32,Sglist_Message) sglist_requestFifo <- mkFromBit();
    requestPipeIn[0] = toPipeIn(sglist_requestFifo);

    FromBit#(32,Region_Message) region_requestFifo <- mkFromBit();
    requestPipeIn[1] = toPipeIn(region_requestFifo);

    FromBit#(32,IdRequest_Message) idRequest_requestFifo <- mkFromBit();
    requestPipeIn[2] = toPipeIn(idRequest_requestFifo);

    FromBit#(32,IdReturn_Message) idReturn_requestFifo <- mkFromBit();
    requestPipeIn[3] = toPipeIn(idReturn_requestFifo);

    FromBit#(32,SetInterface_Message) setInterface_requestFifo <- mkFromBit();
    requestPipeIn[4] = toPipeIn(setInterface_requestFifo);

    interface PipePortal portalIfc;
        method Bit#(16) messageSize(Bit#(16) methodNumber);
            case (methodNumber)
            0: return fromInteger(valueOf(SizeOf#(Sglist_Message)));
            1: return fromInteger(valueOf(SizeOf#(Region_Message)));
            2: return fromInteger(valueOf(SizeOf#(IdRequest_Message)));
            3: return fromInteger(valueOf(SizeOf#(IdReturn_Message)));
            4: return fromInteger(valueOf(SizeOf#(SetInterface_Message)));
            endcase
        endmethod
        interface Vector requests = requestPipeIn;
        interface Vector indications = nil;
    endinterface
    interface sglist_PipeOut = toPipeOut(sglist_requestFifo);
    interface region_PipeOut = toPipeOut(region_requestFifo);
    interface idRequest_PipeOut = toPipeOut(idRequest_requestFifo);
    interface idReturn_PipeOut = toPipeOut(idReturn_requestFifo);
    interface setInterface_PipeOut = toPipeOut(setInterface_requestFifo);
endmodule

module mkMMURequestWrapperPortal#(idType id, MMURequest ifc)(MMURequestWrapperPortal)
    provisos (Bits#(idType, __a),
              Add#(a__, __a, 32));
    let pipes <- mkMMURequestWrapperPipes(zeroExtend(pack(id)));
    mkConnection(pipes, ifc);
    interface PipePortal portalIfc = pipes.portalIfc;
endmodule

interface MMURequestWrapperMemPortalPipes;
    interface MMURequestWrapperPipes pipes;
    interface MemPortal#(16,32) portalIfc;
endinterface

(* synthesize *)
module mkMMURequestWrapperMemPortalPipes#(Bit#(32) id)(MMURequestWrapperMemPortalPipes);

  let p <- mkMMURequestWrapperPipes(zeroExtend(pack(id)));
  let memPortal <- mkMemPortal(id, p.portalIfc);
  interface MMURequestWrapperPipes pipes = p;
  interface MemPortal portalIfc = memPortal;
endmodule

// exposed wrapper MemPortal implementation
module mkMMURequestWrapper#(idType id, MMURequest ifc)(MMURequestWrapper)
   provisos (Bits#(idType, a__),
	     Add#(b__, a__, 32));
  let dut <- mkMMURequestWrapperMemPortalPipes(zeroExtend(pack(id)));
  mkConnection(dut.pipes, ifc);
  interface MemPortal portalIfc = dut.portalIfc;
endmodule

// exposed proxy interface
interface MMURequestProxyPortal;
    interface PipePortal#(0, 5, 32) portalIfc;
    interface ConnectalMemory::MMURequest ifc;
endinterface
interface MMURequestProxy;
    interface StdPortal portalIfc;
    interface ConnectalMemory::MMURequest ifc;
endinterface

(* synthesize *)
module  mkMMURequestProxyPortalSynth#(Bit#(32) id) (MMURequestProxyPortal);
    Vector#(5, PipeOut#(Bit#(32))) indicationPipes = newVector();

    ToBit#(32,Sglist_Message) sglist_responseFifo <- mkToBit();
    indicationPipes[0] = toPipeOut(sglist_responseFifo);

    ToBit#(32,Region_Message) region_responseFifo <- mkToBit();
    indicationPipes[1] = toPipeOut(region_responseFifo);

    ToBit#(32,IdRequest_Message) idRequest_responseFifo <- mkToBit();
    indicationPipes[2] = toPipeOut(idRequest_responseFifo);

    ToBit#(32,IdReturn_Message) idReturn_responseFifo <- mkToBit();
    indicationPipes[3] = toPipeOut(idReturn_responseFifo);

    ToBit#(32,SetInterface_Message) setInterface_responseFifo <- mkToBit();
    indicationPipes[4] = toPipeOut(setInterface_responseFifo);

    interface ConnectalMemory::MMURequest ifc;

    method Action sglist(Bit#(32) sglId, Bit#(32) sglIndex, Bit#(64) addr, Bit#(32) len);
        sglist_responseFifo.enq(Sglist_Message {sglId: sglId, sglIndex: sglIndex, addr: addr, len: len});
        //$display("indicationMethod 'sglist' invoked");
    endmethod
    method Action region(Bit#(32) sglId, Bit#(64) barr8, Bit#(32) index8, Bit#(64) barr4, Bit#(32) index4, Bit#(64) barr0, Bit#(32) index0);
        region_responseFifo.enq(Region_Message {sglId: sglId, barr8: barr8, index8: index8, barr4: barr4, index4: index4, barr0: barr0, index0: index0});
        //$display("indicationMethod 'region' invoked");
    endmethod
    method Action idRequest(SpecialTypeForSendingFd fd);
        idRequest_responseFifo.enq(IdRequest_Message {fd: fd});
        //$display("indicationMethod 'idRequest' invoked");
    endmethod
    method Action idReturn(Bit#(32) sglId);
        idReturn_responseFifo.enq(IdReturn_Message {sglId: sglId});
        //$display("indicationMethod 'idReturn' invoked");
    endmethod
    method Action setInterface(Bit#(32) interfaceId, Bit#(32) sglId);
        setInterface_responseFifo.enq(SetInterface_Message {interfaceId: interfaceId, sglId: sglId});
        //$display("indicationMethod 'setInterface' invoked");
    endmethod
    endinterface
    interface PipePortal portalIfc;
        method Bit#(16) messageSize(Bit#(16) methodNumber);
            case (methodNumber)
            0: return fromInteger(valueOf(SizeOf#(Sglist_Message)));
            1: return fromInteger(valueOf(SizeOf#(Region_Message)));
            2: return fromInteger(valueOf(SizeOf#(IdRequest_Message)));
            3: return fromInteger(valueOf(SizeOf#(IdReturn_Message)));
            4: return fromInteger(valueOf(SizeOf#(SetInterface_Message)));
            endcase
        endmethod
        interface Vector requests = nil;
        interface Vector indications = indicationPipes;
    endinterface
endmodule

// exposed proxy implementation
module  mkMMURequestProxyPortal#(idType id) (MMURequestProxyPortal)
    provisos (Bits#(idType, __a),
              Add#(a__, __a, 32));
    let rv <- mkMMURequestProxyPortalSynth(extend(pack(id)));
    return rv;
endmodule

// synthesizeable proxy MemPortal
(* synthesize *)
module mkMMURequestProxySynth#(Bit#(32) id)(MMURequestProxy);
  let dut <- mkMMURequestProxyPortal(id);
  let memPortal <- mkMemPortal(id, dut.portalIfc);
  interface MemPortal portalIfc = memPortal;
  interface ConnectalMemory::MMURequest ifc = dut.ifc;
endmodule

// exposed proxy MemPortal
module mkMMURequestProxy#(idType id)(MMURequestProxy)
   provisos (Bits#(idType, a__),
	     Add#(b__, a__, 32));
   let rv <- mkMMURequestProxySynth(extend(pack(id)));
   return rv;
endmodule
endpackage: MMURequest
