import Time::*;
import Vector::*;
import ValDRAMCtrlType::*;

typedef struct{
   Bool onFlash;
   Bit#(47) valAddr;
   } ValAddrT deriving (Bits, Eq);


typedef struct{
//   Bit#(8) idle;
   Bit#(20) hvKey;
   
   Bit#(8) keylen; // key length
//   Bit#(8) clsid; // slab class id

//   Bit#(16) refcount;
//   Time_t exptime; // expiration time
   Time_t currtime;// last accessed time
   ValSizeT nBytes; // 1MB
   
   
   ValAddrT ; // valueStore address
   } ItemHeader deriving(Bits, Eq);
//`define HEADER_64_ALIGNED;

/* constants definition */
//typedef enum {Idle, ProcHeader, ProcData, PrepWrite_0, PrepWrite_1, WriteHeader, WriteKeys} State deriving (Bits, Eq);
   
typedef Bit#(64) PhyAddr;

typedef SizeOf#(ItemHeader) HeaderSz;
   
typedef 128 LineWidth; // LineWidth 64/128/256/512

typedef TDiv#(LineWidth, 8) LineBytes;

typedef TLog#(LineBytes) LgLineBytes;

typedef TDiv#(HeaderSz, LineWidth) HeaderTokens;

//typedef TSub#(HeaderSz,TMul#(LineWidth,TSub#(TDiv#(HeaderSz, LineWidth),1))) HeaderRemainderSz;
typedef 0 HeaderRemainderSz;

typedef TDiv#(HeaderRemainderSz, 8) HeaderRemainderBytes;

typedef TLog#(LineWidth) LogLnWidth;

typedef TDiv#(512, LineWidth) NumWays;

typedef TMul#(256,8) MaxKeyLen;

typedef TAdd#(HeaderSz,MaxKeyLen) MaxItemSize;

typedef TDiv#(MaxItemSize, LineWidth) ItemOffset;

typedef TSub#(LineWidth, HeaderRemainderSz) HeaderResidualSz;
typedef TDiv#(HeaderResidualSz,8) HeaderResidualBytes;
/*
`ifndef HEADER_64_ALIGNED
typedef TSub#(HeaderResidualSz, TMul#(64,TSub#(TDiv#(HeaderResidualSz,64),1))) DtaShiftSz;
`else
typedef 0 DtaShfitSz;
`endif

typedef TSub#(64, DtaShiftSz) KeyShiftSz;
*/



typedef struct{
   ValAddrT addr;
   ValSizeT nBytes;
   ValSizeT oldNbytes;
   Bool hit;
   Bool doEvict;
   Bit#(30) hv;
   Bit#(2) idx;
   } HtRespType deriving (Bits, Eq);

typedef struct{
   Bit#(32) hv;
   Bit#(8) idx;
   PhyAddr hdrAddr;
   Bit#(8) hdrNreq;
   PhyAddr keyAddr;
   Bit#(8) keyNreq;
   Bit#(8) keyLen;
   ValSizeT nBytes;
   Time_t time_now;
   Bool rnw;
   } HdrRdParas deriving(Bits, Eq);


typedef struct{
   Bit#(32) hv;
   Bit#(8) idx;
   PhyAddr hdrAddr;
   Bit#(8) hdrNreq;
   PhyAddr keyAddr;
   Bit#(8) keyNreq;
   Bit#(8) keyLen;
   ValSizeT nBytes;
   Time_t time_now;
   Bit#(NumWays) cmpMask;
   Bit#(NumWays) idleMask;
   Vector#(NumWays, ItemHeader) oldHeaders;
   Bool rnw;
   } KeyRdParas deriving(Bits, Eq);

typedef struct{
   Bit#(32) hv;
   Bit#(8) idx;
   PhyAddr hdrAddr;
   Bit#(8) hdrNreq;
   PhyAddr keyAddr;
   Bit#(8) keyNreq;
   Bit#(8) keyLen;
   ValSizeT nBytes;
   Time_t time_now;
   Bit#(NumWays) cmpMask;
   Bit#(NumWays) idleMask;
   Vector#(NumWays, ItemHeader) oldHeaders;
   Bool rnw;
   } HdrWrParas deriving(Bits, Eq);

typedef struct{
   Bit#(32) hv;
   Bit#(8) idx;
   PhyAddr hdrAddr;
   Bit#(8) hdrNreq;
   PhyAddr keyAddr;
   Bit#(8) keyNreq;
   Bit#(8) keyLen;
   ValSizeT nBytes;
   Time_t time_now;
   Bit#(NumWays) cmpMask;
   Bit#(NumWays) idleMask;
   Bool byPass;
   } KeyWrParas deriving(Bits, Eq);


typedef struct{
   Bit#(32) hv;
   Bit#(2) idx;
   FlashAddrType flashAddr;
   } HeaderUpdateReqT deriving(Bits, Eq);
