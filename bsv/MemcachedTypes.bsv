typedef TDiv#(SizeOf#(t),8) BytesOf#(type t);

typedef TExp#(20) MaxValSz;
typedef Bit#(TLog#(MaxValSz)) ValSizeT;

typedef Bit#(30) HashValueT;
typedef Bit#(2) WayIdxT;


typedef struct{
   Bool onFlash;
   Bit#(47) valAddr;
   } ValAddrT deriving (Bits, Eq);

