import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import GetPut::*;
import Vector::*;
import ClientServer::*;
import ClientServerHelper::*;

import MemcachedTypes::*;
import ParameterTypes::*;
import DRAMCommon::*;
import HashtableTypes::*;
import ValFlashCtrlTypes::*;
import Time::*;
import ValuestrCommon::*;

import ProtocolHeader::*;

import Fifo::*;
import CAM::*;

import LFSR :: * ;

interface HeaderWriterIfc;
   interface Put#(HdrWrReqT) request;
   interface Get#(HashtableRespType) response;
   interface Get#(DRAMReq) dramClient;
   interface Client#(FlashStoreCmd, FlashAddrType) flashClient;
   `ifdef BSIM
   method Action reset();
   `endif
endinterface


(*synthesize*)
module mkHeaderWriter(HeaderWriterIfc);
   FIFO#(HashtableRespType) respQ <- mkSizedFIFO(numStages);
   FIFO#(ItemHeader) newHeaderQ <- mkFIFO;
   
   FIFO#(ValAllocReqT) valReqQ <- mkFIFO();
   FIFO#(ValAllocRespT) valRespQ <- mkFIFO();

   
   FIFO#(HeaderWriterPipeT) stageQ_0 <- mkSizedFIFO(numStages);
   FIFO#(Bit#(32)) hv_idxQ <- mkSizedFIFO(numStages);
   FIFO#(HeaderWriterPipeT) stageQ_1 <- mkFIFO;
   FIFO#(HeaderWriterPipeT) immediateQ <- mkFIFO;
   
   //FIFO#(HeaderUpdateReqT) hdrUpdQ <- mkFIFO();
 
   FIFO#(Tuple3#(Bit#(64), Bit#(2), FlashAddrType)) flashReqQ <- mkFIFO;
   
   Vector#(2, FIFO#(DRAMReq)) dramReqQs <- replicateM(mkFIFO());
   FIFO#(Bool) dramRespQ <- mkFIFO();
   
   Reg#(Bit#(TLog#(NUM_STAGES))) evictCnt <- mkReg(0);
   
   //FIFO#(FlashStoreCmd) flashStoreQ <- mkFIFO();
   FIFO#(FlashAddrType) flashWrAddrQ <- mkFIFO();
   let random <- mkLFSR_32;     
   rule writeHeader;
      $display("HeaderWriter:: Get ValAlloc Resp");
      let v <- toGet(stageQ_0).get();

      let newValue = v.newValue;
              
      if ( newValue ) begin
         // handle write req
         let resp <- toGet(flashWrAddrQ).get();
         let valAddr = ValAddrT{onFlash:True, valAddr: zeroExtend(pack(resp))};
         v.newhdr.valAddr = valAddr;
      end

      
      let wrVal = pack(v.newhdr);
      
      Bit#(64) wrAddr = (extend(v.hv) << 6) + (extend(v.idx) << fromInteger(valueOf(LgLineBytes)));
      
      if ( v.doWrite ) begin
         Bit#(7) numOfBytes = fromInteger(valueOf(LineBytes));
         $display("HeaderWriter wrAddr = %d, wrVal = %h, bytes = %d", wrAddr, wrVal, numOfBytes);
         dramReqQs[0].enq(DRAMReq{rnw: False, addr:wrAddr, data:zeroExtend(wrVal), numBytes:numOfBytes});
      end
      else begin
         dramReqQs[0].enq(DRAMReq{rnw: False, addr:?, data:?, numBytes:0});
      end
      
      //respQ.enq(v.retval);
      
   endrule
   

   Reg#(Bit#(16)) reqCnt <- mkReg(0);
   
   interface Put request;
      method Action put(HdrWrReqT args);
        
         let old_header = args.oldHeaders;
         let cmpMask = args.cmpMask;
         let idleMask = args.idleMask;
   
         $display("(%t) HeaderWriter: cmpMask = %b, idleMask = %b, doWrite = %b, numBytes = %d, reqCnt = %d",$time,  cmpMask, idleMask, args.opcode, args.value_size, reqCnt);
   

         Bit#(TLog#(NumWays)) ind = mask2ind(cmpMask);
 
         Bool doWrite = True;
      
         HashtableRespType retval = ?;
         retval.reqId = args.reqId;
         retval.value_size = old_header[ind].nBytes;
         ItemHeader newhdr = ItemHeader{hvKey: args.hvKey,
                                        keylen: args.key_size,
                                        currtime : args.time_now,
                                        valAddr: ?, 
                                        nBytes : args.value_size
                                        };
         Bool newVal = False;
   
         ValAddrT rdAddr = old_header[ind].valAddr;
         ValSizeT rdBytes = extend(old_header[ind].nBytes) + extend(old_header[ind].keylen);
         ValSizeT wrBytes = extend(args.key_size) + extend(args.value_size);
         
         `ifdef BSIM
         if ( args.opcode ==  PROTOCOL_BINARY_CMD_GET && cmpMask != 0) begin
            if ( random.value() % 8 == 7 ) begin
               cmpMask = 0;
            end
            random.next();
         end
         `endif

   
         reqCnt <= reqCnt + 1;
         if ( cmpMask != 0 ) begin
            // update the timestamp in the header;

            old_header[ind].currtime = args.time_now;
                     
            newhdr = old_header[ind];
            
            if ( args.opcode == PROTOCOL_BINARY_CMD_GET ) begin
               $display("Read Success");
               retval.status = PROTOCOL_BINARY_RESPONSE_SUCCESS;
               //flashStoreQ.enq(FlashStoreCmd{rnw: True, addr: unpack(truncate(rdAddr.valAddr)), numBytes: rdBytes, reqId: args.reqId});
               retval.value_cmd = FlashStoreCmd{rnw: True, addr: unpack(truncate(rdAddr.valAddr)), numBytes: rdBytes, reqId: args.reqId};
            end
            else if ( args.opcode == PROTOCOL_BINARY_CMD_SET) begin
               $display("Write Overwrite");
               retval.status = PROTOCOL_BINARY_RESPONSE_SUCCESS;
               //retval.status = PROTOCOL_BINARY_RESPONSE_KEY_EEXISTS;
               //doWrite = False;
               retval.value_cmd = FlashStoreCmd{rnw: False, addr: ?, numBytes:wrBytes, reqId: args.reqId}; 
               newVal = True;
            end
            else if ( args.opcode == PROTOCOL_BINARY_CMD_DELETE ) begin
               $display("Delete Success");
               retval.status = PROTOCOL_BINARY_RESPONSE_SUCCESS;
               newhdr.keylen = 0;
            end
         end
         else begin
            if ( args.opcode == PROTOCOL_BINARY_CMD_GET ) begin
               $display("Read fail");
               retval.status = PROTOCOL_BINARY_RESPONSE_NOT_STORED;
               doWrite = False;
            end
            else if ( args.opcode == PROTOCOL_BINARY_CMD_SET ) begin
               retval.status = PROTOCOL_BINARY_RESPONSE_SUCCESS;
               Bool trade_in = False;
               
               if ( idleMask != 0 ) begin
                  $display("HeaderWriter Bucket[%d]:: Insert into a empty slot", args.hv);
                  ind = mask2ind(idleMask);
               end
               else begin
                  $display("HeaderWriter Bucket[%d]::  Evict and insert into the smallest time stamp", args.hv);
                  Vector#(NumWays, Time_t) timestamps;
                  for (Integer i = 0; i < valueOf(NumWays); i = i + 1) begin
                     timestamps[i] = old_header[i].currtime;
                  end
                  ind = findLRU(timestamps);
                  if ( !old_header[ind].valAddr.onFlash )
                     trade_in = True;
               end
               //flashStoreQ.enq(FlashStoreCmd{rnw: False, addr: ?, numBytes:wrBytes, reqId: args.reqId});
               retval.value_cmd = FlashStoreCmd{rnw: False, addr: ?, numBytes:wrBytes, reqId: args.reqId}; 
               newVal = True;
            end
            else if ( args.opcode == PROTOCOL_BINARY_CMD_DELETE ) begin
               $display("Deletion fail");
               retval.status = PROTOCOL_BINARY_RESPONSE_NOT_STORED;
               doWrite = False;
            end    
         end
      
         respQ.enq(retval);

         stageQ_0.enq(HeaderWriterPipeT{retval:?,// retval,
                                        newhdr: newhdr,
                                        newValue: newVal,
                                        doWrite: doWrite,
                                        hv: args.hv,
                                        idx: ind,
                                        hvKey: args.hvKey,
                                        key_size: args.key_size,
                                        value_size: args.value_size,
                                        time_now: args.time_now
                                        });
      endmethod
   endinterface
   
   interface Get response = toGet(respQ);
   
   interface Get dramClient = toGet(dramReqQs[0]);
   
   //interface Client flashClient = toClient(flashStoreQ, flashWrAddrQ);
   interface Client flashClient;// = toClient(flashStoreQ, flashWrAddrQ);
      interface Get request = ?;
      interface Put response = toPut(flashWrAddrQ);
   endinterface
   
   
      `ifdef BSIM
   method Action reset();
      random.seed(1);
   endmethod
      `endif

   
endmodule
