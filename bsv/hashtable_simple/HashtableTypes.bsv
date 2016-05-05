import ParameterTypes::*;
import ClientServer::*;
import DRAMCommon::*;
import GetPut::*;
import Time::*;
import Vector::*;
//import ValDRAMCtrlTypes::*;
import MemcachedTypes::*;
//import HashtableTypes::*;
//import ValuestrCommon::*;
import ProtocolHeader::*;
import ParameterTypes::*;
import ControllerTypes::*;

import ValFlashCtrlTypes::*;


typedef struct{
   Bit#(20) hvKey;
   
   Bit#(8) keylen; // key length
   Time_t currtime;// last accessed time
   ValSizeT nBytes; // 1MB
   ValAddrT valAddr; // valueStore address
   } ItemHeader deriving(Bits, Eq);
//`define HEADER_64_ALIGNED;

/* constants definition */
   
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

typedef enum {SUCCESS, ERR_KEYEXIST, ERR_MISS} RespStatus deriving (Eq, Bits);



typedef struct{
   Protocol_Binary_Response_Status status;
   TagT reqId;
   // ValAddrT value_addr;
   ValSizeT value_size;
   
   FlashStoreCmd value_cmd;
               
   // HashValueT hv;
   // WayIdxT idx;
   
   // Bool doEvict;
  
   // HashValueT old_hv;
   // WayIdxT old_idx;
   // ValSizeT old_nBytes;

   } HashtableRespType deriving (Bits, Eq);


typedef struct{
   HashValueT hv;
   Bit#(20) hvKey;
   Bit#(8) key_size;
   ValSizeT value_size;
   Protocol_Binary_Command opcode;
   TagT reqId;
   } HashtableReqT deriving(Bits, Eq);

typedef struct{
   HashValueT hv;
   Bit#(20) hvKey;
   Bit#(8) key_size;
   ValSizeT value_size;
   Time_t time_now;
   Protocol_Binary_Command opcode;
   TagT reqId;
   } HdrRdReqT deriving(Bits, Eq);


typedef struct{
   HashValueT hv;
   Bit#(20) hvKey;
   Bit#(8) key_size;
   ValSizeT value_size;
   Time_t time_now;
   Protocol_Binary_Command opcode;
   Bit#(NumWays) cmpMask;
   Bit#(NumWays) idleMask;
   Vector#(NumWays, ItemHeader) oldHeaders;
   TagT reqId;
   } HdrWrReqT deriving(Bits, Eq);

typedef struct{
   HashtableRespType retval;
   ItemHeader newhdr;
   Bool newValue;
   Bool doWrite;
   HashValueT hv;
   WayIdxT idx;
   Bit#(20) hvKey;
   Bit#(8) key_size;
   ValSizeT value_size;
   Time_t time_now;
   } HeaderWriterPipeT deriving (Bits, Eq);



function Bit#(TLog#(NumWays)) mask2ind (Bit#(NumWays) mask);
   Bit#(TLog#(NumWays)) retval = ?;
  
   for (Integer i = 0; i < valueOf(NumWays); i = i + 1) begin
      if ((mask >> fromInteger(i))[0] == 1) begin
         retval = fromInteger(i);
      end
   end
   return retval;
endfunction

function Bit#(TLog#(NumWays)) findLRU (Vector#(NumWays, Time_t) timestamps);
   Integer retval = ?;
   Vector#(NumWays, Bit#(NumWays)) maskVec = replicate(1);
   for (Integer i = 0; i < valueOf(NumWays); i = i + 1) begin
      //let time_i = timestamps[i];
      for (Integer j = 0; j < valueOf(NumWays); j = j + 1) begin
         if ( timestamps[i] > timestamps[j] ) begin
            maskVec[i][j] = 0;
         end
      end
   end
   for (Integer k = 0; k < valueOf(NumWays); k = k + 1) begin
      if ( maskVec[k] != 0 ) begin
         retval = k;
      end
   end
   return fromInteger(retval);
endfunction

function Bool eq(element_type v, element_type s) provisos (Eq#(element_type));
   return v == s;
endfunction



