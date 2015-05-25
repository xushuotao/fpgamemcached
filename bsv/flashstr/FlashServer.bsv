import ControllerTypes::*;
import ClientServer::*;
import ClientServerHelper::*;
import Connectable::*;
import GetPut::*;
import BRAM::*;

import FIFO::*;
import FIFOF::*;
import Vector::*;

// FlashCapacity is defined in GBs
`ifndef BSIM
`ifdef FlashCapacity
typedef `FlashCapacity FlashCapcity;
`else
typedef 256 FlashCapcity;
`endif
`else
typedef 16 FlashCapcity;
`endif

typedef TExp#(20) ONEMB;

typedef TMul#(PagesPerBlock, 8192) BlockSize;

typedef TDiv#(TMul#(FlashCapcity, ONEMB), BlockSize) NumBlocks;

typedef TMul#(NUM_BUSES, ChipsPerBus) NumChips;

typedef Bit#(TLog#(NumBlocks)) BlockIdxT;
typedef Bit#(TLog#(BlocksPerCE)) BlockT;

typedef TDiv#(NumBlocks, TMul#(ChipsPerBus, NUM_BUSES)) NumBlocksPerChip;

typedef Server#(FlashCmd, Tuple2#(Bit#(128), TagT)) FlashRawReadServer;

Integer lgBlkOffset = valueOf(TLog#(NumBlocksPerChip));
Integer lgWayOffset = valueOf(TLog#(ChipsPerBus));
              
interface FlashRawWriteServer;
   interface Server#(FlashCmd, TagT) server;
   interface Put#(Tuple2#(Bit#(128), TagT)) wordPipe;
   interface Get#(Tuple2#(TagT, StatusT)) doneAck;
endinterface
typedef Server#(FlashCmd, Tuple2#(TagT, StatusT)) FlashRawEraseServer;


typedef Client#(FlashCmd, Tuple2#(Bit#(128), TagT)) FlashRawReadClient;
interface FlashRawWriteClient;
   interface Client#(FlashCmd, TagT) client;
   interface Get#(Tuple2#(Bit#(128), TagT)) wordPipe;
   interface Put#(Tuple2#(TagT, StatusT)) doneAck;
endinterface
typedef Client#(FlashCmd, Tuple2#(TagT, StatusT)) FlashRawEraseClient;

interface FlashServer;
   method Action populateMap(BlockIdxT idx, BlockT data);
   interface Server#(Bool, Tuple2#(BlockT, Bool)) dumpMap;
   interface FlashRawWriteServer writeServer;
   interface FlashRawReadServer readServer;
   interface FlashRawEraseServer eraseServer;
endinterface

module mkFlashServer#(FlashCtrlUser flash)(FlashServer);
   BRAM_Configure cfg = defaultValue;
   BRAM2Port#(BlockIdxT, BlockT) blockMap <- mkBRAM2Server(cfg);
   
   FIFO#(FlashCmd) cmdQ <- mkSizedFIFO(128);
   FIFO#(Tuple2#(FlashCmd, Bool)) rawCmdQ <- mkFIFO();
   
   Vector#(NumChips, Reg#(Bit#(TAdd#(TLog#(NumBlocksPerChip), 1)))) nextNewBlock <- replicateM(mkReg(0));
   
   function BlockIdxT convertVirtualIdx(BusT bus, ChipT chip, Bit#(16) block);
      return  truncate(block) + (extend(chip) << lgBlkOffset) + (extend(bus) << (lgBlkOffset+lgWayOffset));
   endfunction
   
   Vector#(NumChips, Reg#(Bit#(TLog#(PagesPerBlock)))) pageCnts <- replicateM(mkReg(0)); 
   rule doReq;
      let req <- toGet(cmdQ).get();
      //$display($fshow(req));

      Bool bypass = True;
      if (req.op != ERASE_BLOCK ) begin
         bypass = False;
         BlockIdxT addr = convertVirtualIdx(req.bus, req.chip, req.block);
         blockMap.portA.request.put(BRAMRequest{write: False,
                                                responseOnWrite: False,
                                                address: addr,
                                                datain: ?
                                                });
         if (req.op == WRITE_PAGE) begin
            Bit#(TLog#(NumChips)) chipId = extend(req.chip) + (extend(req.bus) << lgWayOffset);
      
            pageCnts[chipId]  <= pageCnts[chipId] + 1;
            
            if ( pageCnts[chipId] == 0 ) begin
               nextNewBlock[chipId] <= nextNewBlock[chipId] + 1;
               if (  extend(nextNewBlock[chipId]) != req.block ) begin
                  $display("Panic!!!!: client did not write blocks seqentially");
                  $finish();
               end
            end
            else begin
               if (  extend(nextNewBlock[chipId]-1) != req.block ) begin
                  $display("Panic!!!!: client did not write all pages in a block seqentially");
                  $finish();
               end
            end
         end
      end
      rawCmdQ.enq(tuple2(req, bypass));
   endrule
   
   rule issueReq;
      let v <- toGet(rawCmdQ).get();
      let cmd = tpl_1(v);
      let bypass = tpl_2(v);
      
      
      if ( !bypass) begin
         let blkId <- blockMap.portA.response.get();
         cmd.block = extend(blkId);
      end
      //$display(cmd);
      flash.sendCmd(cmd);
   endrule
   
   Vector#(2, FIFO#(Tuple2#(TagT,StatusT))) ackStatusQs <- replicateM(mkFIFO);
   rule distributeAck;
      let v <- flash.ackStatus;
      let tag = tpl_1(v);
      let status = tpl_2(v);
      if ( status == WRITE_DONE )
         ackStatusQs[0].enq(v);
      else
         ackStatusQs[1].enq(v);
   endrule
   
   FIFOF#(Bool) dumpReqQ <- mkFIFOF;
   FIFO#(Tuple2#(BlockT, Bool)) dumpRespQ <- mkFIFO();
   Reg#(BlockIdxT) dumpCnt <- mkReg(0);
   rule doDump if ( dumpReqQ.notEmpty);
      Bit#(TAdd#(TLog#(NumBlocks), 1)) blkMax = fromInteger(valueOf(NumBlocks));
      if ( extend(dumpCnt) + 1 == blkMax) begin
         dumpReqQ.deq();
         dumpCnt <= 0;
      end
      else begin
         dumpCnt <= dumpCnt + 1;
      end
      
      blockMap.portB.request.put(BRAMRequest{write: False,
                                             responseOnWrite: False,
                                             address: dumpCnt,
                                             datain: ?
                                             });
   endrule
   
   Reg#(BlockIdxT) dumpRespCnt <- mkReg(0);
   rule doBumpResp;
      dumpRespCnt <= dumpRespCnt + 1;
      Bit#(TLog#(NumChips)) chipId = truncate(dumpRespCnt >> lgBlkOffset);
      Bit#(TLog#(NumBlocksPerChip)) blkId = truncate(dumpRespCnt);
      let v <- blockMap.portB.response.get();
      if ( blkId >= nextNewBlock[chipId] ) begin
         dumpRespQ.enq(tuple2(v, True));
      end
      else begin
         dumpRespQ.enq(tuple2(v, False));
      end
   endrule
         
   
   method Action populateMap(BlockIdxT idx, BlockT data);
      blockMap.portB.request.put(BRAMRequest{write: True,
                                             responseOnWrite: False,
                                             address: idx,
                                             datain: data
                                             });
         
   endmethod
   interface Server dumpMap;
      interface Put request = toPut(dumpReqQ);
      interface Get response = toGet(dumpRespQ);
   endinterface
   
   interface FlashRawWriteServer writeServer;
      interface Server server;
         interface Put request = toPut(cmdQ);
         interface Get response;
            method ActionValue#(TagT) get();
               let tag <- flash.writeDataReq();
               return tag;
            endmethod
         endinterface
      endinterface
   
      interface Put wordPipe;
         method Action put(Tuple2#(Bit#(128), TagT) v);
            flash.writeWord(v);
         endmethod
      endinterface
   
      interface Get doneAck = toGet(ackStatusQs[0]);
   endinterface
   
   interface FlashRawReadServer readServer;
      interface Put request = toPut(cmdQ);
      interface Get response;
         method ActionValue#(Tuple2#(Bit#(128), TagT)) get();
            let v <- flash.readWord();
            return v;
         endmethod
      endinterface
   endinterface
   
   interface FlashRawEraseServer eraseServer;
      interface Put request = toPut(cmdQ);
      interface Get response = toGet(ackStatusQs[1]);
   endinterface
   

endmodule   

instance Connectable#(FlashRawWriteClient, FlashRawWriteServer);
   module mkConnection#(FlashRawWriteClient cli, FlashRawWriteServer ser)(Empty);
      mkConnection(cli.client, ser.server);
      mkConnection(cli.wordPipe, ser.wordPipe);
      mkConnection(cli.doneAck, ser.doneAck);
   endmodule
endinstance

instance Connectable#(FlashRawWriteServer, FlashRawWriteClient);
   module mkConnection#(FlashRawWriteServer ser, FlashRawWriteClient cli)(Empty);
      mkConnection(cli.client, ser.server);
      mkConnection(cli.wordPipe, ser.wordPipe);
      mkConnection(cli.doneAck, ser.doneAck);
   endmodule
endinstance
