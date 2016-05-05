import ProtocolHeader::*;

typedef enum{Idle, ProcKeys, ProcVals} State_Input deriving (Eq, Bits);
typedef enum{Idle, ProcVals} State_Output deriving (Eq, Bits); 
//typedef Server#(Bit#(64), Bit#(64)) MemServer;
typedef enum{Idle, DoVal, DoRemote} State_Val deriving (Eq, Bits);

typedef struct{
   Protocol_Binary_Request_Header header;
   Bit#(32) rp;
   Bit#(32) wp;
   Bit#(64) nBytes;
   Bit#(32) reqId;
   Bit#(32) hv;
   Maybe#(Bit#(32)) nodeId;
   } MemcacheReqType deriving (Eq, Bits);

typedef struct{
   Protocol_Binary_Response_Header header;
   Bit#(32) reqId;
   Maybe#(Bit#(32)) nodeId;
   Bool fromRemote;
   } MemcacheRespType deriving (Eq, Bits);
