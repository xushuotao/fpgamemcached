import ClientServer::*;
import Connectable::*;
import ControllerTypes::*;
import GetPut::*;
import DRAMCommon::*;
import AuroraImportFmc1::*;
import ControllerTypes::*;
import FlashServer::*;
import AuroraCommon::*;

import MemcachedTypes::*;
import GetPut::*;
import Connectable::*;

import TagAlloc::*;

typedef 8192 PageSz;

typedef TMul#(NumTags,PageSz) SuperPageSz;
typedef TDiv#(SuperPageSz, PageSz) NumPagesPerSuperPage;

typedef TMul#(NUM_BUSES,TMul#(ChipsPerBus,TMul#(BlocksPerCE,TMul#(PagesPerBlock, PageSz)))) TotalSz;
typedef TDiv#(TotalSz, SuperPageSz) NumSuperPages;

typedef Bit#(TLog#(PageSz)) PageOffsetT;

typedef Bit#(TLog#(NumSuperPages)) SuperPageIndT;

Integer pageSz = valueOf(PageSz);
Integer superPageSz = valueOf(SuperPageSz);

`ifndef WordSz
typedef 128 WordSz;
`endif

typedef Bit#(WordSz) WordT;
typedef TDiv#(WordSz, 8) WordBytes;


/*typedef struct{
   Bit#(32) nBytes;
   Bit#(6) wordOffset;
   } FlashWriteCmdT deriving (Bits, Eq);*/

typedef struct{
   Bit#(32) numBytes;
   Bit#(32) numBursts;
   } BufWriteCmdT deriving (Bits, Eq);

typedef struct{
   Bit#(32) numBursts;
   Bit#(6) offset;
   } ShiftCmdT deriving (Bits, Eq);

typedef struct{
   Bit#(TLog#(BlocksPerCE)) block;   
   Bit#(TLog#(PagesPerBlock)) page;
   ChipT way;
   BusT channel;
   } RawFlashAddrT deriving (Bits, Eq);

typedef struct{
   Bit#(TLog#(BlocksPerCE)) block;   
   Bit#(TLog#(PagesPerBlock)) page;
   ChipT way;
   BusT channel;
   PageOffsetT offset;
   } FlashAddrType deriving (Bits, Eq);

typedef struct{
   FlashAddrType addr;
   ValSizeT numBytes;
   TagT reqId;
   } FlashReadReqT deriving (Bits, Eq);

typedef struct{
   Bit#(1) bufId;
   SuperPageIndT segId;
   } FlushReqT deriving (Bits, Eq);

/*typedef TMul#(WriteBufSz,PagesPerBlock) SegmentSz;
typedef TDiv#(SegmentSz,PageSz) NumPagesPerSegment;

typedef BlocksPerCE NumSegments;
Integer segmentSz = valueOf(SegmentSz);*/
interface FlashWriteServer;
   interface Server#(ValSizeT, FlashAddrType) writeServer;
   interface Put#(Bit#(512)) writeWord;
endinterface

interface FlashWriteClient;
   interface Client#(ValSizeT, FlashAddrType) writeClient;
   interface Get#(Bit#(512)) writeWord;
endinterface


interface FlashReadServer;
   interface Server#(FlashReadReqT, Tuple2#(WordT, TagT)) readServer;
   interface Get#(Tuple2#(ValSizeT, TagT)) burstSz;
endinterface

interface FlashReadClient;
   interface Client#(FlashReadReqT, Tuple2#(WordT, TagT)) readClient;
   interface Put#(Tuple2#(ValSizeT, TagT)) burstSz;
endinterface

interface FlashValueStoreReadServer;
   interface Put#(FlashReadReqT) request;
   interface Get#(Tuple2#(WordT, TagT)) dramResp;
   interface Get#(Tuple2#(WordT, TagT)) flashResp;
   interface Get#(Tuple2#(ValSizeT, TagT)) dramBurstSz;
   interface Get#(Tuple2#(ValSizeT, TagT)) flashBurstSz;
endinterface


interface FlashValueStoreReadClient;
   interface Get#(FlashReadReqT) request;
   interface Put#(Tuple2#(WordT, TagT)) dramResp;
   interface Put#(Tuple2#(WordT, TagT)) flashResp;
   interface Put#(Tuple2#(ValSizeT, TagT)) dramBurstSz;
   interface Put#(Tuple2#(ValSizeT, TagT)) flashBurstSz;
endinterface

/*
interface FlashPins;
   interface Aurora_Pins#(4) aurora_fmc1;
   interface Aurora_Clock_Pins aurora_clk_fmc1;
endinterface
*/

interface FlashValueStoreIfc;
   interface FlashWriteServer writeServer;
   interface FlashValueStoreReadServer readServer;
   interface DRAM_LOCK_Client dramClient;
   interface FlashRawWriteClient flashRawWrClient;
   interface FlashRawReadClient flashRawRdClient;
   interface TagClient tagClient;
   //interface FlashPins flashPins;
endinterface



instance Connectable#(FlashWriteClient, FlashWriteServer);
   module mkConnection#(FlashWriteClient cli, FlashWriteServer ser)(Empty);
      mkConnection(cli.writeClient, ser.writeServer);
      mkConnection(cli.writeWord, ser.writeWord);
   endmodule
endinstance

instance Connectable#(FlashWriteServer, FlashWriteClient);
   module mkConnection#(FlashWriteServer ser, FlashWriteClient cli)(Empty);
      mkConnection(cli.writeClient, ser.writeServer);
      mkConnection(cli.writeWord, ser.writeWord);
   endmodule
endinstance


instance Connectable#(FlashValueStoreReadClient, FlashValueStoreReadServer);
   module mkConnection#(FlashValueStoreReadClient cli, FlashValueStoreReadServer ser)(Empty);
      mkConnection(cli.request, ser.request);
      mkConnection(cli.dramResp, ser.dramResp);
      mkConnection(cli.flashResp, ser.flashResp);
      mkConnection(cli.dramBurstSz, ser.dramBurstSz);
      mkConnection(cli.flashBurstSz, ser.flashBurstSz);
   endmodule
endinstance

instance Connectable#(FlashValueStoreReadServer, FlashValueStoreReadClient);
   module mkConnection#(FlashValueStoreReadServer ser, FlashValueStoreReadClient cli)(Empty);
      mkConnection(cli.request, ser.request);
      mkConnection(cli.dramResp, ser.dramResp);
      mkConnection(cli.flashResp, ser.flashResp);
      mkConnection(cli.dramBurstSz, ser.dramBurstSz);
      mkConnection(cli.flashBurstSz, ser.flashBurstSz);
   endmodule
endinstance

instance Connectable#(FlashReadClient, FlashReadServer);
   module mkConnection#(FlashReadClient cli, FlashReadServer ser)(Empty);
      mkConnection(cli.readClient, ser.readServer);
      mkConnection(cli.burstSz, ser.burstSz);
   endmodule
endinstance

instance Connectable#(FlashReadServer, FlashReadClient);
   module mkConnection#(FlashReadServer ser, FlashReadClient cli)(Empty);
      mkConnection(cli.readClient, ser.readServer);
      mkConnection(cli.burstSz, ser.burstSz);
   endmodule
endinstance

