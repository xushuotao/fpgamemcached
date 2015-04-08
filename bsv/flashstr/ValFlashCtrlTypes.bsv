import ControllerTypes::*;
import ValDRAMCtrlTypes::*;

typedef 8192 PageSz;

typedef TMul#(NumTags,PageSz) SuperPageSz;
typedef TDiv#(SuperPageSz, PageSz) NumPagesPerSuperPage;

typedef TMul#(NUM_BUSES,TMul#(ChipsPerBus,TMul#(BlocksPerCE,TMul#(PagesPerBlock, PageSz)))) TotalSz;
typedef TDiv#(TotalSz, SuperPageSz) NumSuperPages;

typedef Bit#(TLog#(PageSz)) PageOffsetT;

Integer pageSz = valueOf(PageSz);
Integer superPageSz = valueOf(SuperPageSz);


typedef struct{
   Bit#(32) nBytes;
   Bit#(6) wordOffset;
   } FlashWriteCmdT deriving (Bits, Eq);

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
   Bit#(32) segId;
   } FlushReqT deriving (Bits, Eq);

/*typedef TMul#(WriteBufSz,PagesPerBlock) SegmentSz;
typedef TDiv#(SegmentSz,PageSz) NumPagesPerSegment;

typedef BlocksPerCE NumSegments;
Integer segmentSz = valueOf(SegmentSz);*/
