typedef enum {
   PROTOCOL_BINARY_REQ = 8'h80,
   PROTOCOL_BINARY_RES = 8'h81
   } Protocol_Binary_Magic deriving (Eq,Bits);

/**
* Definition of the valid response status numbers.
* See section 3.2 Response Status
*/
typedef enum {
   PROTOCOL_BINARY_RESPONSE_SUCCESS = 16'h0000,
   PROTOCOL_BINARY_RESPONSE_KEY_ENOENT = 16'h0001,
   PROTOCOL_BINARY_RESPONSE_KEY_EEXISTS = 16'h0002,
   PROTOCOL_BINARY_RESPONSE_E2BIG = 16'h0003,
   PROTOCOL_BINARY_RESPONSE_EINVAL = 16'h0004,
   PROTOCOL_BINARY_RESPONSE_NOT_STORED = 16'h0005,
   PROTOCOL_BINARY_RESPONSE_DELTA_BADVAL = 16'h0006,
   PROTOCOL_BINARY_RESPONSE_AUTH_ERROR = 16'h0020,
   PROTOCOL_BINARY_RESPONSE_AUTH_CONTINUE = 16'h0021,
   PROTOCOL_BINARY_RESPONSE_UNKNOWN_COMMAND = 16'h0081,
   PROTOCOL_BINARY_RESPONSE_ENOMEM = 16'h0082,
   PROTOCOL_BINARY_RESPONSE_NULL = 16'hffff
   } Protocol_Binary_Response_Status deriving (Eq,Bits);


typedef enum {
   PROTOCOL_BINARY_CMD_GET = 8'h00,
   PROTOCOL_BINARY_CMD_SET = 8'h01,
   PROTOCOL_BINARY_CMD_ADD = 8'h02,
   PROTOCOL_BINARY_CMD_REPLACE = 8'h03,
   PROTOCOL_BINARY_CMD_DELETE = 8'h04,
   PROTOCOL_BINARY_CMD_INCREMENT = 8'h05,
   PROTOCOL_BINARY_CMD_DECREMENT = 8'h06,
   PROTOCOL_BINARY_CMD_QUIT = 8'h07,
   PROTOCOL_BINARY_CMD_FLUSH = 8'h08,
   PROTOCOL_BINARY_CMD_GETQ = 8'h09,
   PROTOCOL_BINARY_CMD_NOOP = 8'h0a,
   PROTOCOL_BINARY_CMD_VERSION = 8'h0b,
   PROTOCOL_BINARY_CMD_GETK = 8'h0c,
   PROTOCOL_BINARY_CMD_GETKQ = 8'h0d,
   PROTOCOL_BINARY_CMD_APPEND = 8'h0e,
   PROTOCOL_BINARY_CMD_PREPEND = 8'h0f,
   PROTOCOL_BINARY_CMD_STAT = 8'h10,
   PROTOCOL_BINARY_CMD_SETQ = 8'h11,
   PROTOCOL_BINARY_CMD_ADDQ = 8'h12,
   PROTOCOL_BINARY_CMD_REPLACEQ = 8'h13,
   PROTOCOL_BINARY_CMD_DELETEQ = 8'h14,
   PROTOCOL_BINARY_CMD_INCREMENTQ = 8'h15,
   PROTOCOL_BINARY_CMD_DECREMENTQ = 8'h16,
   PROTOCOL_BINARY_CMD_QUITQ = 8'h17,
   PROTOCOL_BINARY_CMD_FLUSHQ = 8'h18,
   PROTOCOL_BINARY_CMD_APPENDQ = 8'h19,
   PROTOCOL_BINARY_CMD_PREPENDQ = 8'h1a,
   PROTOCOL_BINARY_CMD_TOUCH = 8'h1c,
   PROTOCOL_BINARY_CMD_GAT = 8'h1d,
   PROTOCOL_BINARY_CMD_GATQ = 8'h1e,
   PROTOCOL_BINARY_CMD_GATK = 8'h23,
   PROTOCOL_BINARY_CMD_GATKQ = 8'h24,

   PROTOCOL_BINARY_CMD_SASL_LIST_MECHS = 8'h20,
   PROTOCOL_BINARY_CMD_SASL_AUTH = 8'h21,
   PROTOCOL_BINARY_CMD_SASL_STEP = 8'h22,

   //  /* These commands are used for range operations and exist within
   //   * this header for use in other projects.  Range operations are
   //   * not expected to be implemented in the memcached server itself.
   //   */
   PROTOCOL_BINARY_CMD_RGET      = 8'h30,
   PROTOCOL_BINARY_CMD_RSET      = 8'h31,
   PROTOCOL_BINARY_CMD_RSETQ     = 8'h32,
   PROTOCOL_BINARY_CMD_RAPPEND   = 8'h33,
   PROTOCOL_BINARY_CMD_RAPPENDQ  = 8'h34,
   PROTOCOL_BINARY_CMD_RPREPEND  = 8'h35,
   PROTOCOL_BINARY_CMD_RPREPENDQ = 8'h36,
   PROTOCOL_BINARY_CMD_RDELETE   = 8'h37,
   PROTOCOL_BINARY_CMD_RDELETEQ  = 8'h38,
   PROTOCOL_BINARY_CMD_RINCR     = 8'h39,
   PROTOCOL_BINARY_CMD_RINCRQ    = 8'h3a,
   PROTOCOL_BINARY_CMD_RDECR     = 8'h3b,
   PROTOCOL_BINARY_CMD_RDECRQ    = 8'h3c,
   //   /* End Range operations */

   PROTOCOL_BINARY_CMD_EOM = 8'hff
   } Protocol_Binary_Command deriving (Eq,Bits);

typedef struct {
   Bit#(64) cas;
   Bit#(32) opaque;
   Bit#(32) bodylen;
   Bit#(16) reserved;
   Bit#(8) datatype;
   Bit#(8)  extlen;
   Bit#(16) keylen;
   Protocol_Binary_Command opcode;
   Protocol_Binary_Magic magic;
   } Protocol_Binary_Request_Header deriving (Eq, Bits);


typedef struct {
   Bit#(64) cas;
   Bit#(32) opaque;
   Bit#(32) bodylen;
   Protocol_Binary_Response_Status status;
   Bit#(8) datatype;
   Bit#(8) extlen;
   Bit#(16) keylen;
   Protocol_Binary_Command opcode;
   Protocol_Binary_Magic magic;
   }Protocol_Binary_Response_Header deriving (Eq, Bits);


typedef SizeOf#(Protocol_Binary_Magic) MagicSz;
typedef SizeOf#(Protocol_Binary_Command) OpcodeSz;
typedef SizeOf#(Protocol_Binary_Request_Header) ReqHeaderSz;
typedef SizeOf#(Protocol_Binary_Response_Header) RespHeaderSz;
