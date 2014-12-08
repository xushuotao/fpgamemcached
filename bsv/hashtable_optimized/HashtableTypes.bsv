import Time::*;
import Vector::*;


typedef struct{
//   Bit#(8) idle;
   Bit#(8) keylen; // key length
//   Bit#(8) clsid; // slab class id
   Bit#(64) valAddr; // valueStore address
//   Bit#(16) refcount;
//   Time_t exptime; // expiration time
   Time_t currtime;// last accessed time
   Bit#(24) nBytes; // 16MB
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
   Bit#(32) hv;
   Bit#(8) idx;
   PhyAddr hdrAddr;
   Bit#(8) hdrNreq;
   PhyAddr keyAddr;
   Bit#(8) keyNreq;
   Bit#(8) keyLen;
   Bit#(64) nBytes;
   Time_t time_now;
   } HdrRdParas deriving(Bits, Eq);


typedef struct{
   Bit#(32) hv;
   Bit#(8) idx;
   PhyAddr hdrAddr;
   Bit#(8) hdrNreq;
   PhyAddr keyAddr;
   Bit#(8) keyNreq;
   Bit#(8) keyLen;
   Bit#(64) nBytes;
   Time_t time_now;
   Bit#(NumWays) cmpMask;
   Bit#(NumWays) idleMask;
   Vector#(NumWays, ItemHeader) oldHeaders;
   } KeyRdParas deriving(Bits, Eq);

typedef struct{
   Bit#(32) hv;
   Bit#(8) idx;
   PhyAddr hdrAddr;
   Bit#(8) hdrNreq;
   PhyAddr keyAddr;
   Bit#(8) keyNreq;
   Bit#(8) keyLen;
   Bit#(64) nBytes;
   Time_t time_now;
   Bit#(NumWays) cmpMask;
   Bit#(NumWays) idleMask;
   Vector#(NumWays, ItemHeader) oldHeaders;
   } HdrWrParas deriving(Bits, Eq);

typedef struct{
   Bit#(32) hv;
   Bit#(8) idx;
   PhyAddr hdrAddr;
   Bit#(8) hdrNreq;
   PhyAddr keyAddr;
   Bit#(8) keyNreq;
   Bit#(8) keyLen;
   Bit#(64) nBytes;
   Time_t time_now;
   Bit#(NumWays) cmpMask;
   Bit#(NumWays) idleMask;
   } KeyWrParas deriving(Bits, Eq);
