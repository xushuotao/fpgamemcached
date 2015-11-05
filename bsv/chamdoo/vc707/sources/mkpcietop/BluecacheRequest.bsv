package BluecacheRequest;

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
import BluecacheIndication::*;
import MemServerIndication::*;
import MMUIndication::*;
import Bluecache::*;
import XilinxVC707DDR3::*;
import DRAMController::*;




typedef struct {
    Bit#(32) bus;
    Bit#(32) chip;
    Bit#(32) block;
    Bit#(32) tag;
} EraseBlock_Message deriving (Bits);

typedef struct {
    Bit#(32) idx;
    Bit#(32) data;
} PopulateMap_Message deriving (Bits);

typedef struct {
    Bit#(32) dummy;
} DumpMap_Message deriving (Bits);

typedef struct {
    Bit#(32) rp;
    Bit#(32) wp;
} InitDMARefs_Message deriving (Bits);

typedef struct {
    Bit#(32) rp;
    Bit#(32) numBytes;
} StartRead_Message deriving (Bits);

typedef struct {
    Bit#(32) wp;
} FreeWriteBufId_Message deriving (Bits);

typedef struct {
    Bit#(32) bufSz;
} InitDMABufSz_Message deriving (Bits);

typedef struct {
    Bit#(64) lgOffset;
} InitTable_Message deriving (Bits);

typedef struct {
    Bit#(32) randMax1;
    Bit#(32) randMax2;
    Bit#(32) randMax3;
    Bit#(32) lgSz1;
    Bit#(32) lgSz2;
    Bit#(32) lgSz3;
} InitValDelimit_Message deriving (Bits);

typedef struct {
    Bit#(32) offset1;
    Bit#(32) offset2;
    Bit#(32) offset3;
} InitAddrDelimit_Message deriving (Bits);

typedef struct {
    Bit#(32) randNum;
} Reset_Message deriving (Bits);

typedef struct {
    Bit#(32) v;
} RecvData_0_Message deriving (Bits);

typedef struct {
    Bit#(32) v;
} RecvData_1_Message deriving (Bits);

typedef struct {
    Bit#(32) v;
} RecvData_2_Message deriving (Bits);

// exposed wrapper portal interface
interface BluecacheRequestWrapperPipes;
    interface PipePortal#(14, 0, 32) portalIfc;
    interface PipeOut#(EraseBlock_Message) eraseBlock_PipeOut;
    interface PipeOut#(PopulateMap_Message) populateMap_PipeOut;
    interface PipeOut#(DumpMap_Message) dumpMap_PipeOut;
    interface PipeOut#(InitDMARefs_Message) initDMARefs_PipeOut;
    interface PipeOut#(StartRead_Message) startRead_PipeOut;
    interface PipeOut#(FreeWriteBufId_Message) freeWriteBufId_PipeOut;
    interface PipeOut#(InitDMABufSz_Message) initDMABufSz_PipeOut;
    interface PipeOut#(InitTable_Message) initTable_PipeOut;
    interface PipeOut#(InitValDelimit_Message) initValDelimit_PipeOut;
    interface PipeOut#(InitAddrDelimit_Message) initAddrDelimit_PipeOut;
    interface PipeOut#(Reset_Message) reset_PipeOut;
    interface PipeOut#(RecvData_0_Message) recvData_0_PipeOut;
    interface PipeOut#(RecvData_1_Message) recvData_1_PipeOut;
    interface PipeOut#(RecvData_2_Message) recvData_2_PipeOut;

endinterface
interface BluecacheRequestWrapperPortal;
    interface PipePortal#(14, 0, 32) portalIfc;
endinterface
// exposed wrapper MemPortal interface
interface BluecacheRequestWrapper;
    interface StdPortal portalIfc;
endinterface

instance Connectable#(BluecacheRequestWrapperPipes,BluecacheRequest);
   module mkConnection#(BluecacheRequestWrapperPipes pipes, BluecacheRequest ifc)(Empty);

    rule handle_eraseBlock_request;
        let request <- toGet(pipes.eraseBlock_PipeOut).get();
        ifc.eraseBlock(request.bus, request.chip, request.block, request.tag);
    endrule

    rule handle_populateMap_request;
        let request <- toGet(pipes.populateMap_PipeOut).get();
        ifc.populateMap(request.idx, request.data);
    endrule

    rule handle_dumpMap_request;
        let request <- toGet(pipes.dumpMap_PipeOut).get();
        ifc.dumpMap(request.dummy);
    endrule

    rule handle_initDMARefs_request;
        let request <- toGet(pipes.initDMARefs_PipeOut).get();
        ifc.initDMARefs(request.rp, request.wp);
    endrule

    rule handle_startRead_request;
        let request <- toGet(pipes.startRead_PipeOut).get();
        ifc.startRead(request.rp, request.numBytes);
    endrule

    rule handle_freeWriteBufId_request;
        let request <- toGet(pipes.freeWriteBufId_PipeOut).get();
        ifc.freeWriteBufId(request.wp);
    endrule

    rule handle_initDMABufSz_request;
        let request <- toGet(pipes.initDMABufSz_PipeOut).get();
        ifc.initDMABufSz(request.bufSz);
    endrule

    rule handle_initTable_request;
        let request <- toGet(pipes.initTable_PipeOut).get();
        ifc.initTable(request.lgOffset);
    endrule

    rule handle_initValDelimit_request;
        let request <- toGet(pipes.initValDelimit_PipeOut).get();
        ifc.initValDelimit(request.randMax1, request.randMax2, request.randMax3, request.lgSz1, request.lgSz2, request.lgSz3);
    endrule

    rule handle_initAddrDelimit_request;
        let request <- toGet(pipes.initAddrDelimit_PipeOut).get();
        ifc.initAddrDelimit(request.offset1, request.offset2, request.offset3);
    endrule

    rule handle_reset_request;
        let request <- toGet(pipes.reset_PipeOut).get();
        ifc.reset(request.randNum);
    endrule

    rule handle_recvData_0_request;
        let request <- toGet(pipes.recvData_0_PipeOut).get();
        ifc.recvData_0(request.v);
    endrule

    rule handle_recvData_1_request;
        let request <- toGet(pipes.recvData_1_PipeOut).get();
        ifc.recvData_1(request.v);
    endrule

    rule handle_recvData_2_request;
        let request <- toGet(pipes.recvData_2_PipeOut).get();
        ifc.recvData_2(request.v);
    endrule

   endmodule
endinstance

// exposed wrapper Portal implementation
(* synthesize *)
module mkBluecacheRequestWrapperPipes#(Bit#(32) id)(BluecacheRequestWrapperPipes);
    Vector#(14, PipeIn#(Bit#(32))) requestPipeIn = newVector();

    FromBit#(32,EraseBlock_Message) eraseBlock_requestFifo <- mkFromBit();
    requestPipeIn[0] = toPipeIn(eraseBlock_requestFifo);

    FromBit#(32,PopulateMap_Message) populateMap_requestFifo <- mkFromBit();
    requestPipeIn[1] = toPipeIn(populateMap_requestFifo);

    FromBit#(32,DumpMap_Message) dumpMap_requestFifo <- mkFromBit();
    requestPipeIn[2] = toPipeIn(dumpMap_requestFifo);

    FromBit#(32,InitDMARefs_Message) initDMARefs_requestFifo <- mkFromBit();
    requestPipeIn[3] = toPipeIn(initDMARefs_requestFifo);

    FromBit#(32,StartRead_Message) startRead_requestFifo <- mkFromBit();
    requestPipeIn[4] = toPipeIn(startRead_requestFifo);

    FromBit#(32,FreeWriteBufId_Message) freeWriteBufId_requestFifo <- mkFromBit();
    requestPipeIn[5] = toPipeIn(freeWriteBufId_requestFifo);

    FromBit#(32,InitDMABufSz_Message) initDMABufSz_requestFifo <- mkFromBit();
    requestPipeIn[6] = toPipeIn(initDMABufSz_requestFifo);

    FromBit#(32,InitTable_Message) initTable_requestFifo <- mkFromBit();
    requestPipeIn[7] = toPipeIn(initTable_requestFifo);

    FromBit#(32,InitValDelimit_Message) initValDelimit_requestFifo <- mkFromBit();
    requestPipeIn[8] = toPipeIn(initValDelimit_requestFifo);

    FromBit#(32,InitAddrDelimit_Message) initAddrDelimit_requestFifo <- mkFromBit();
    requestPipeIn[9] = toPipeIn(initAddrDelimit_requestFifo);

    FromBit#(32,Reset_Message) reset_requestFifo <- mkFromBit();
    requestPipeIn[10] = toPipeIn(reset_requestFifo);

    FromBit#(32,RecvData_0_Message) recvData_0_requestFifo <- mkFromBit();
    requestPipeIn[11] = toPipeIn(recvData_0_requestFifo);

    FromBit#(32,RecvData_1_Message) recvData_1_requestFifo <- mkFromBit();
    requestPipeIn[12] = toPipeIn(recvData_1_requestFifo);

    FromBit#(32,RecvData_2_Message) recvData_2_requestFifo <- mkFromBit();
    requestPipeIn[13] = toPipeIn(recvData_2_requestFifo);

    interface PipePortal portalIfc;
        method Bit#(16) messageSize(Bit#(16) methodNumber);
            case (methodNumber)
            0: return fromInteger(valueOf(SizeOf#(EraseBlock_Message)));
            1: return fromInteger(valueOf(SizeOf#(PopulateMap_Message)));
            2: return fromInteger(valueOf(SizeOf#(DumpMap_Message)));
            3: return fromInteger(valueOf(SizeOf#(InitDMARefs_Message)));
            4: return fromInteger(valueOf(SizeOf#(StartRead_Message)));
            5: return fromInteger(valueOf(SizeOf#(FreeWriteBufId_Message)));
            6: return fromInteger(valueOf(SizeOf#(InitDMABufSz_Message)));
            7: return fromInteger(valueOf(SizeOf#(InitTable_Message)));
            8: return fromInteger(valueOf(SizeOf#(InitValDelimit_Message)));
            9: return fromInteger(valueOf(SizeOf#(InitAddrDelimit_Message)));
            10: return fromInteger(valueOf(SizeOf#(Reset_Message)));
            11: return fromInteger(valueOf(SizeOf#(RecvData_0_Message)));
            12: return fromInteger(valueOf(SizeOf#(RecvData_1_Message)));
            13: return fromInteger(valueOf(SizeOf#(RecvData_2_Message)));
            endcase
        endmethod
        interface Vector requests = requestPipeIn;
        interface Vector indications = nil;
    endinterface
    interface eraseBlock_PipeOut = toPipeOut(eraseBlock_requestFifo);
    interface populateMap_PipeOut = toPipeOut(populateMap_requestFifo);
    interface dumpMap_PipeOut = toPipeOut(dumpMap_requestFifo);
    interface initDMARefs_PipeOut = toPipeOut(initDMARefs_requestFifo);
    interface startRead_PipeOut = toPipeOut(startRead_requestFifo);
    interface freeWriteBufId_PipeOut = toPipeOut(freeWriteBufId_requestFifo);
    interface initDMABufSz_PipeOut = toPipeOut(initDMABufSz_requestFifo);
    interface initTable_PipeOut = toPipeOut(initTable_requestFifo);
    interface initValDelimit_PipeOut = toPipeOut(initValDelimit_requestFifo);
    interface initAddrDelimit_PipeOut = toPipeOut(initAddrDelimit_requestFifo);
    interface reset_PipeOut = toPipeOut(reset_requestFifo);
    interface recvData_0_PipeOut = toPipeOut(recvData_0_requestFifo);
    interface recvData_1_PipeOut = toPipeOut(recvData_1_requestFifo);
    interface recvData_2_PipeOut = toPipeOut(recvData_2_requestFifo);
endmodule

module mkBluecacheRequestWrapperPortal#(idType id, BluecacheRequest ifc)(BluecacheRequestWrapperPortal)
    provisos (Bits#(idType, __a),
              Add#(a__, __a, 32));
    let pipes <- mkBluecacheRequestWrapperPipes(zeroExtend(pack(id)));
    mkConnection(pipes, ifc);
    interface PipePortal portalIfc = pipes.portalIfc;
endmodule

interface BluecacheRequestWrapperMemPortalPipes;
    interface BluecacheRequestWrapperPipes pipes;
    interface MemPortal#(16,32) portalIfc;
endinterface

(* synthesize *)
module mkBluecacheRequestWrapperMemPortalPipes#(Bit#(32) id)(BluecacheRequestWrapperMemPortalPipes);

  let p <- mkBluecacheRequestWrapperPipes(zeroExtend(pack(id)));
  let memPortal <- mkMemPortal(id, p.portalIfc);
  interface BluecacheRequestWrapperPipes pipes = p;
  interface MemPortal portalIfc = memPortal;
endmodule

// exposed wrapper MemPortal implementation
module mkBluecacheRequestWrapper#(idType id, BluecacheRequest ifc)(BluecacheRequestWrapper)
   provisos (Bits#(idType, a__),
	     Add#(b__, a__, 32));
  let dut <- mkBluecacheRequestWrapperMemPortalPipes(zeroExtend(pack(id)));
  mkConnection(dut.pipes, ifc);
  interface MemPortal portalIfc = dut.portalIfc;
endmodule

// exposed proxy interface
interface BluecacheRequestProxyPortal;
    interface PipePortal#(0, 14, 32) portalIfc;
    interface Bluecache::BluecacheRequest ifc;
endinterface
interface BluecacheRequestProxy;
    interface StdPortal portalIfc;
    interface Bluecache::BluecacheRequest ifc;
endinterface

(* synthesize *)
module  mkBluecacheRequestProxyPortalSynth#(Bit#(32) id) (BluecacheRequestProxyPortal);
    Vector#(14, PipeOut#(Bit#(32))) indicationPipes = newVector();

    ToBit#(32,EraseBlock_Message) eraseBlock_responseFifo <- mkToBit();
    indicationPipes[0] = toPipeOut(eraseBlock_responseFifo);

    ToBit#(32,PopulateMap_Message) populateMap_responseFifo <- mkToBit();
    indicationPipes[1] = toPipeOut(populateMap_responseFifo);

    ToBit#(32,DumpMap_Message) dumpMap_responseFifo <- mkToBit();
    indicationPipes[2] = toPipeOut(dumpMap_responseFifo);

    ToBit#(32,InitDMARefs_Message) initDMARefs_responseFifo <- mkToBit();
    indicationPipes[3] = toPipeOut(initDMARefs_responseFifo);

    ToBit#(32,StartRead_Message) startRead_responseFifo <- mkToBit();
    indicationPipes[4] = toPipeOut(startRead_responseFifo);

    ToBit#(32,FreeWriteBufId_Message) freeWriteBufId_responseFifo <- mkToBit();
    indicationPipes[5] = toPipeOut(freeWriteBufId_responseFifo);

    ToBit#(32,InitDMABufSz_Message) initDMABufSz_responseFifo <- mkToBit();
    indicationPipes[6] = toPipeOut(initDMABufSz_responseFifo);

    ToBit#(32,InitTable_Message) initTable_responseFifo <- mkToBit();
    indicationPipes[7] = toPipeOut(initTable_responseFifo);

    ToBit#(32,InitValDelimit_Message) initValDelimit_responseFifo <- mkToBit();
    indicationPipes[8] = toPipeOut(initValDelimit_responseFifo);

    ToBit#(32,InitAddrDelimit_Message) initAddrDelimit_responseFifo <- mkToBit();
    indicationPipes[9] = toPipeOut(initAddrDelimit_responseFifo);

    ToBit#(32,Reset_Message) reset_responseFifo <- mkToBit();
    indicationPipes[10] = toPipeOut(reset_responseFifo);

    ToBit#(32,RecvData_0_Message) recvData_0_responseFifo <- mkToBit();
    indicationPipes[11] = toPipeOut(recvData_0_responseFifo);

    ToBit#(32,RecvData_1_Message) recvData_1_responseFifo <- mkToBit();
    indicationPipes[12] = toPipeOut(recvData_1_responseFifo);

    ToBit#(32,RecvData_2_Message) recvData_2_responseFifo <- mkToBit();
    indicationPipes[13] = toPipeOut(recvData_2_responseFifo);

    interface Bluecache::BluecacheRequest ifc;

    method Action eraseBlock(Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) tag);
        eraseBlock_responseFifo.enq(EraseBlock_Message {bus: bus, chip: chip, block: block, tag: tag});
        //$display("indicationMethod 'eraseBlock' invoked");
    endmethod
    method Action populateMap(Bit#(32) idx, Bit#(32) data);
        populateMap_responseFifo.enq(PopulateMap_Message {idx: idx, data: data});
        //$display("indicationMethod 'populateMap' invoked");
    endmethod
    method Action dumpMap(Bit#(32) dummy);
        dumpMap_responseFifo.enq(DumpMap_Message {dummy: dummy});
        //$display("indicationMethod 'dumpMap' invoked");
    endmethod
    method Action initDMARefs(Bit#(32) rp, Bit#(32) wp);
        initDMARefs_responseFifo.enq(InitDMARefs_Message {rp: rp, wp: wp});
        //$display("indicationMethod 'initDMARefs' invoked");
    endmethod
    method Action startRead(Bit#(32) rp, Bit#(32) numBytes);
        startRead_responseFifo.enq(StartRead_Message {rp: rp, numBytes: numBytes});
        //$display("indicationMethod 'startRead' invoked");
    endmethod
    method Action freeWriteBufId(Bit#(32) wp);
        freeWriteBufId_responseFifo.enq(FreeWriteBufId_Message {wp: wp});
        //$display("indicationMethod 'freeWriteBufId' invoked");
    endmethod
    method Action initDMABufSz(Bit#(32) bufSz);
        initDMABufSz_responseFifo.enq(InitDMABufSz_Message {bufSz: bufSz});
        //$display("indicationMethod 'initDMABufSz' invoked");
    endmethod
    method Action initTable(Bit#(64) lgOffset);
        initTable_responseFifo.enq(InitTable_Message {lgOffset: lgOffset});
        //$display("indicationMethod 'initTable' invoked");
    endmethod
    method Action initValDelimit(Bit#(32) randMax1, Bit#(32) randMax2, Bit#(32) randMax3, Bit#(32) lgSz1, Bit#(32) lgSz2, Bit#(32) lgSz3);
        initValDelimit_responseFifo.enq(InitValDelimit_Message {randMax1: randMax1, randMax2: randMax2, randMax3: randMax3, lgSz1: lgSz1, lgSz2: lgSz2, lgSz3: lgSz3});
        //$display("indicationMethod 'initValDelimit' invoked");
    endmethod
    method Action initAddrDelimit(Bit#(32) offset1, Bit#(32) offset2, Bit#(32) offset3);
        initAddrDelimit_responseFifo.enq(InitAddrDelimit_Message {offset1: offset1, offset2: offset2, offset3: offset3});
        //$display("indicationMethod 'initAddrDelimit' invoked");
    endmethod
    method Action reset(Bit#(32) randNum);
        reset_responseFifo.enq(Reset_Message {randNum: randNum});
        //$display("indicationMethod 'reset' invoked");
    endmethod
    method Action recvData_0(Bit#(32) v);
        recvData_0_responseFifo.enq(RecvData_0_Message {v: v});
        //$display("indicationMethod 'recvData_0' invoked");
    endmethod
    method Action recvData_1(Bit#(32) v);
        recvData_1_responseFifo.enq(RecvData_1_Message {v: v});
        //$display("indicationMethod 'recvData_1' invoked");
    endmethod
    method Action recvData_2(Bit#(32) v);
        recvData_2_responseFifo.enq(RecvData_2_Message {v: v});
        //$display("indicationMethod 'recvData_2' invoked");
    endmethod
    endinterface
    interface PipePortal portalIfc;
        method Bit#(16) messageSize(Bit#(16) methodNumber);
            case (methodNumber)
            0: return fromInteger(valueOf(SizeOf#(EraseBlock_Message)));
            1: return fromInteger(valueOf(SizeOf#(PopulateMap_Message)));
            2: return fromInteger(valueOf(SizeOf#(DumpMap_Message)));
            3: return fromInteger(valueOf(SizeOf#(InitDMARefs_Message)));
            4: return fromInteger(valueOf(SizeOf#(StartRead_Message)));
            5: return fromInteger(valueOf(SizeOf#(FreeWriteBufId_Message)));
            6: return fromInteger(valueOf(SizeOf#(InitDMABufSz_Message)));
            7: return fromInteger(valueOf(SizeOf#(InitTable_Message)));
            8: return fromInteger(valueOf(SizeOf#(InitValDelimit_Message)));
            9: return fromInteger(valueOf(SizeOf#(InitAddrDelimit_Message)));
            10: return fromInteger(valueOf(SizeOf#(Reset_Message)));
            11: return fromInteger(valueOf(SizeOf#(RecvData_0_Message)));
            12: return fromInteger(valueOf(SizeOf#(RecvData_1_Message)));
            13: return fromInteger(valueOf(SizeOf#(RecvData_2_Message)));
            endcase
        endmethod
        interface Vector requests = nil;
        interface Vector indications = indicationPipes;
    endinterface
endmodule

// exposed proxy implementation
module  mkBluecacheRequestProxyPortal#(idType id) (BluecacheRequestProxyPortal)
    provisos (Bits#(idType, __a),
              Add#(a__, __a, 32));
    let rv <- mkBluecacheRequestProxyPortalSynth(extend(pack(id)));
    return rv;
endmodule

// synthesizeable proxy MemPortal
(* synthesize *)
module mkBluecacheRequestProxySynth#(Bit#(32) id)(BluecacheRequestProxy);
  let dut <- mkBluecacheRequestProxyPortal(id);
  let memPortal <- mkMemPortal(id, dut.portalIfc);
  interface MemPortal portalIfc = memPortal;
  interface Bluecache::BluecacheRequest ifc = dut.ifc;
endmodule

// exposed proxy MemPortal
module mkBluecacheRequestProxy#(idType id)(BluecacheRequestProxy)
   provisos (Bits#(idType, a__),
	     Add#(b__, a__, 32));
   let rv <- mkBluecacheRequestProxySynth(extend(pack(id)));
   return rv;
endmodule
endpackage: BluecacheRequest
