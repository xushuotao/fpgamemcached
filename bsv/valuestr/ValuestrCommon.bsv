import ClientServer::*;
import Connectable::*;
import ControllerTypes::*;
import GetPut::*;
import Time::*;
import DRAMCommon::*;
import FlashServer::*;
import AuroraImportFmc1::*;
import ControllerTypes::*;
import AuroraCommon::*;
import Vector::*;

import HostFIFO::*;

import TagAlloc::*;

import MemcachedTypes::*;
import HashtableTypes::*;
import ValFlashCtrlTypes::*;

/* constants definitions */

typedef struct{
   Bit#(30) hv;
   Bit#(2) idx;
   Bit#(32) nBytes;
   Time_t timestamp;
   } ValHeader deriving (Bits, Eq);


typedef SizeOf#(ValHeader) ValHeaderSz;

typedef TDiv#(ValHeaderSz,8) ValHeaderBytes; 

typedef TDiv#(ValHeaderSz, 512) HeaderBurstSz;


typedef struct {
   Bool rnw;
   ValAddrT addr;
   ValSizeT nBytes;
   TagT reqId;
   Bit#(30) hv;
   Bit#(2) idx;
   Bool doEvict;
   Bit#(30) old_hv;
   Bit#(2) old_idx;
   ValSizeT old_nBytes;
   } ValstrCmdType deriving (Eq, Bits);


typedef struct {
   ValAddrT addr;
   ValSizeT nBytes;
   TagT reqId;
   } ValstrReadReqT deriving (Bits, Eq);



typedef struct {
   Bit#(64) addr;
   ValSizeT nBytes;
   TagT reqId;
   HashValueT hv;
   WayIdxT idx;
   Bool doEvict;
   HashValueT old_hv;
   WayIdxT old_idx;
   ValSizeT old_nBytes;
   } ValstrWriteReqT deriving (Bits, Eq);



typedef struct {
   Bit#(32) nBytes;
   Bit#(32) oldAddr;
   Bit#(32) oldNBytes;
   //Bool trade_in;
   Bool rtn_old;
   Bool req_new;
   } ValAllocReqT deriving (Bits, Eq);

typedef struct {
   Bit#(32) newAddr;
   Bool doEvict;
   Bit#(32) oldNBytes;
   Bit#(30) hv;
   Bit#(2) idx;
   } ValAllocRespT deriving (Bits, Eq);


typedef struct{
   HashValueT hv;
   WayIdxT idx;
   FlashAddrType flashAddr;
   } HeaderUpdateReqT deriving(Bits, Eq);


interface ValManageInitIFC;
   method Action initValDelimit(Bit#(32) randMax1, Bit#(32) randMax2, Bit#(32) randMax3, Bit#(32) lgSz1, Bit#(32) lgSz2, Bit#(32) lgSz3);
   method Action initAddrDelimit(Bit#(32) offset1, Bit#(32) offset2, Bit#(32) offset3);
endinterface

interface ValuestrInitIfc;
   interface ValManageInitIFC manage_init;
   method Action totalSize(Bit#(64) v);
endinterface



typedef Client#(ValstrReadReqT, Tuple2#(Bit#(128), TagT)) ValuestrReadClient;
typedef Server#(ValstrReadReqT, Tuple2#(Bit#(128), TagT)) ValuestrReadServer;

typedef Server#(ValAllocReqT, ValAllocRespT) ValAllocServer;
typedef Client#(ValAllocReqT, ValAllocRespT) ValAllocClient;


interface ValuestrWriteServer;
   interface Server#(ValstrWriteReqT, HeaderUpdateReqT) writeServer;
   interface Put#(Bit#(128)) writeWord;
endinterface

interface ValuestrWriteClient;
   interface Client#(ValstrWriteReqT, HeaderUpdateReqT) writeClient;
   interface Get#(Bit#(128)) writeWord;
endinterface



interface ValuestrIFC;
   interface ValuestrWriteServer writeUser;
   interface ValuestrReadServer readUser;
   interface Get#(Tuple2#(ValSizeT, TagT)) nextRespId;
   
   interface ValAllocServer valAllocServer;
   
   interface ValuestrInitIfc valInit;
   interface Vector#(3, IndicationServer#(Bit#(32))) indicationServers;

   interface DRAMClient dramClient;
      //interface FlashPins flashPins;
   interface FlashRawWriteClient flashRawWrClient;
   interface FlashRawReadClient flashRawRdClient;
   interface TagClient tagClient;
   method Action reset();
endinterface


instance Connectable#(ValuestrWriteClient, ValuestrWriteServer);
   module mkConnection#(ValuestrWriteClient cli, ValuestrWriteServer ser)(Empty);
      mkConnection(cli.writeClient, ser.writeServer);
      mkConnection(cli.writeWord, ser.writeWord);
   endmodule
endinstance

instance Connectable#(ValuestrWriteServer, ValuestrWriteClient);
   module mkConnection#(ValuestrWriteServer ser, ValuestrWriteClient cli)(Empty);
      mkConnection(cli.writeClient, ser.writeServer);
      mkConnection(cli.writeWord, ser.writeWord);
   endmodule
endinstance

