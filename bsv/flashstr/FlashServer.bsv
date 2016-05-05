import ControllerTypes::*;
import ClientServer::*;
import ClientServerHelper::*;
import Connectable::*;
import GetPut::*;
import BRAM::*;

import FIFO::*;
import FIFOF::*;
import Vector::*;

import TagAlloc::*;
import RegFile::*;
import LFSR :: * ;
//import TagArbiter::*;

// FlashCapacity is defined in GBs
// `ifndef BSIM
// `ifdef FlashCapacity
// typedef `FlashCapacity FlashCapcity;
// `else
// typedef 256 FlashCapcity;
// `endif
// `else
// typedef 16 FlashCapcity;
// `endif

// typedef TExp#(20) ONEMB;

typedef TMul#(PagesPerBlock, 8192) BlockSize;

//typedef TDiv#(TMul#(FlashCapcity, ONEMB), BlockSize) NumBlocks;
typedef TMul#(NUM_BUSES, TMul#(BlocksPerCE, ChipsPerBus)) NumBlocks;

typedef TMul#(NUM_BUSES, ChipsPerBus) NumChips;

typedef Bit#(TLog#(NumBlocks)) BlockIdxT;
typedef Bit#(TLog#(BlocksPerCE)) BlockT;

//typedef TDiv#(NumBlocks, TMul#(ChipsPerBus, NUM_BUSES)) NumBlocksPerChip;

typedef Server#(FlashCmd, Tuple2#(Bit#(128), TagT)) FlashRawReadServer;

typedef enum {IDLE, ERASECMD, ERASEACK} State deriving (Eq, Bits);

Integer lgBlkOffset = valueOf(TLog#(BlocksPerCE));
Integer lgWayOffset = valueOf(TLog#(ChipsPerBus));
              
interface FlashRawWriteServer;
   interface Server#(Bit#(32), Bool) reserve;
   interface Server#(FlashCmd, TagT) server;
   interface Put#(Tuple2#(Bit#(128), TagT)) wordPipe;
   interface Get#(Tuple2#(TagT, StatusT)) doneAck;
endinterface
// typedef Server#(FlashCmd, Tuple2#(TagT, StatusT)) FlashRawEraseServer;


typedef Client#(FlashCmd, Tuple2#(Bit#(128), TagT)) FlashRawReadClient;
interface FlashRawWriteClient;
   interface Client#(Bit#(32), Bool) reserve;
   interface Client#(FlashCmd, TagT) client;
   interface Get#(Tuple2#(Bit#(128), TagT)) wordPipe;
   interface Put#(Tuple2#(TagT, StatusT)) doneAck;
endinterface
// typedef Client#(FlashCmd, Tuple2#(TagT, StatusT)) FlashRawEraseClient;

interface FlashServer;
   // method Action populateMap(BlockIdxT idx, BlockT data);
   // interface Server#(Bool, Tuple2#(BlockT, Bool)) dumpMap;
   interface FlashRawWriteServer writeServer;
   interface FlashRawReadServer readServer;
//   interface FlashRawEraseServer eraseServer;
   interface TagClient tagClient;
   method Action reset(Bit#(32) randV);
endinterface

module mkFlashServer#(FlashCtrlUser flash)(FlashServer);
   BRAM_Configure cfg = defaultValue;
   BRAM2Port#(BlockIdxT, BlockT) blockMap <- mkBRAM2Server(cfg);
   
   FIFO#(FlashCmd) cmdQ <- mkSizedFIFO(128);
   FIFO#(Tuple2#(FlashCmd, Bool)) rawCmdQ <- mkFIFO();
   
   Vector#(NumChips, Reg#(Bit#(TAdd#(TLog#(BlocksPerCE), 1)))) nextNewBlock <- replicateM(mkReg(0));
   
   `ifdef BSIM
   function BlockIdxT convertVirtualIdx(BusT bus, ChipT chip, Bit#(16) block);
      return  truncate(block) + (extend(chip) << lgBlkOffset) + (extend(bus) << (lgBlkOffset+lgWayOffset));
   endfunction
   `else
   function BlockIdxT convertVirtualIdx(BusT bus, ChipT chip, Bit#(16) block);
      return  extend(block) + (extend(chip) << lgBlkOffset) + (extend(bus) << (lgBlkOffset+lgWayOffset));
   endfunction
   `endif

   Vector#(NumChips, Reg#(Bit#(TLog#(BlocksPerCE)))) nextPhysPtrs <- replicateM(mkReg(0));   
   Vector#(NumChips, Reg#(Bit#(TLog#(BlocksPerCE)))) nextWritePtrs <- replicateM(mkReg(0));
   Vector#(NumChips, Reg#(Bit#(TLog#(BlocksPerCE)))) nextErasePtrs <- replicateM(mkReg(0));
   // Reg#(TagT) eraseCnt <- mkReg(0);
   Vector#(2, FIFO#(Tuple2#(TagT,StatusT))) ackStatusQs <- replicateM(mkSizedFIFO(128));   
   // for (Integer i = 0; i < valueOf(NumChips); i = i + 1) begin
   FIFO#(Bit#(32)) tagReqQ <- mkFIFO();
   FIFO#(TagT) freeTagQ <- mkFIFO();
   FIFO#(TagT) returnTagQ <- mkFIFO();

   Reg#(State) state <- mkReg(IDLE);
   Vector#(NumChips, Reg#(Bool)) eraseStatus <- replicateM(mkRegU());
   Reg#(Bit#(TAdd#(TLog#(NumChips),1))) respMax <- mkReg(0);
   
   Reg#(Bool) resetFlag <- mkReg(False);

   FIFO#(Bool) eraseFinishQ <- mkFIFO();
   Integer numChips = valueOf(NumChips);
   
   rule doEraseIdle if ( state == IDLE && resetFlag);
      //if ( nextWritePtrs[numChips-1] + 1 > nextErasePtrs[numChips-1] ) begin
      if ( nextWritePtrs[0] + 1 > nextErasePtrs[0] ) begin
         state <= ERASECMD;
         tagReqQ.enq(fromInteger(valueOf(NumChips)));
         respMax <= 0;
         for ( Integer i = 0; i < valueOf(NumChips); i = i + 1)
            eraseStatus[i] <= False;
      end
   endrule
      
   Reg#(Bit#(TLog#(NumChips))) chipCnt <- mkReg(0);


   
   RegFile#(TagT, Bit#(TLog#(NumChips))) lut <- mkRegFileFull();

   rule doEraseCmd if ( state == ERASECMD );
      if ( !eraseStatus[chipCnt] ) begin
         let tag <- toGet(freeTagQ).get();
         Bit#(TLog#(NUM_BUSES)) busid = truncate(chipCnt);//fromInteger(i%valueOf(NUM_BUSES));
         Bit#(TLog#(ChipsPerBus)) chipid = truncateLSB(chipCnt);//fromInteger(i/valueOf(NUM_BUSES));
         flash.sendCmd(FlashCmd{tag: tag, op: ERASE_BLOCK, bus: busid, chip: chipid, block: extend(nextPhysPtrs[chipCnt]), page: 0});
         lut.upd(tag, chipCnt);
         respMax <= respMax + 1;
      end
      
      chipCnt <= chipCnt + 1;
      if ( chipCnt + 1 == 0 )
         state <= ERASEACK;
   endrule
   
   
   Reg#(Bit#(TLog#(NumChips))) respCnt <- mkReg(0);
   Reg#(Bit#(TLog#(NumChips))) successCnt <- mkReg(0);
   
   let random <- mkLFSR_32;
      
   rule doEraseAck if ( state == ERASEACK );
      let v <- toGet(ackStatusQs[1]).get();
      let tag = tpl_1(v);
      let status = tpl_2(v);
      let chipId = lut.sub(tag);
      nextPhysPtrs[chipId] <= nextPhysPtrs[chipId] + 1;
      returnTagQ.enq(tag);
      $display("eraseAck:: tag = %d, chipId = %d, status = %d, nextPhysPtrs = %d, nextErasePtrs = %d, respCnt = %d, successCnt = %d, respMax = %d", tag, chipId, status, nextPhysPtrs[chipId], nextErasePtrs[chipId], respCnt, successCnt, respMax);
      Bool success = False;
      `ifdef BSIM_Blah
      random.next();
      if ( random.value() % 8 != 7 ) begin
         `else
      if ( status != ERASE_ERROR ) begin
         `endif
         $display("eraseAckSUCCESSFUL:: tag = %d, chipId = %d, status = %d, nextPhysPtrs = %d, nextErasePtrs = %d, respCnt = %d, successCnt = %d, respMax = %d", tag, chipId, status, nextPhysPtrs[chipId], nextErasePtrs[chipId], respCnt, successCnt, respMax);
         success = True;
         eraseStatus[chipId] <= True;
         successCnt <= successCnt + 1;
         nextErasePtrs[chipId] <= nextErasePtrs[chipId] + 1;
         // bus // chip // block
         BlockIdxT addr = convertVirtualIdx(truncate(chipId), truncateLSB(chipId), extend(nextErasePtrs[chipId]));
         blockMap.portB.request.put(BRAMRequest{write: True,
                                                responseOnWrite: False,
                                                address: addr,
                                                datain: nextPhysPtrs[chipId]
                                                });

      end
      
      if ( extend(respCnt) + 1 == respMax ) begin
         respCnt <= 0;
         if ( successCnt + 1 == 0 && success ) begin
            $display("Going back to IDLE");
            state <= IDLE;
            eraseFinishQ.enq(True);
         end
         else begin
            $display("Going back to ERASECMD");
            if (success)
               tagReqQ.enq(fromInteger(valueOf(NumChips))-extend(successCnt)-1);
            else
               tagReqQ.enq(fromInteger(valueOf(NumChips))-extend(successCnt));               
            respMax <= 0;
            state <= ERASECMD;
         end
      end
      else begin
        respCnt <= respCnt + 1;
      end
      
   endrule

   FIFO#(Bit#(32)) reserveReqQ <- mkFIFO();
   FIFO#(Bool) reserveRespQ <- mkFIFO();
   
   Reg#(Bit#(TLog#(PagesPerBlock))) pageCnt_chips <- mkReg(0);
   Reg#(Bit#(32)) responseCnt <- mkReg(0);
   rule doReserveReq;
      let numPages = reserveReqQ.first();
      let pagesPerChip = numPages/fromInteger(valueOf(NumChips));
      if (  pageCnt_chips == 0 ) begin
         eraseFinishQ.deq();
         reserveReqQ.deq();
         reserveRespQ.enq(True);
         pageCnt_chips <= pageCnt_chips + truncate(pagesPerChip);
         responseCnt <= responseCnt + 1;
         $display("FlashServer response for write segId = %d", responseCnt);
      end
      else begin
         reserveReqQ.deq();
         reserveRespQ.enq(True);
         pageCnt_chips <= pageCnt_chips + truncate(pagesPerChip);
         responseCnt <= responseCnt + 1;
         $display("FlashServer response for write segId = %d", responseCnt);
      end
   endrule
   
   Vector#(NumChips, Reg#(Bit#(TLog#(PagesPerBlock)))) pageCnts <- replicateM(mkReg(0)); 
   rule doReq;

      //$display($fshow(req));
      let req = cmdQ.first;//<- toGet(cmdQ).get();
      Bool bypass = True;
      Bit#(TLog#(NumChips)) chipId = extend(req.chip) + (extend(req.bus) << lgWayOffset);
      //$display("Do request, chipId = %d, nextWritePtrs = %d, nextErasePtr = %d", chipId, nextWritePtrs[chipId], nextErasePtrs[chipId]);
      if ( !(req.op == WRITE_PAGE && nextWritePtrs[chipId] >= nextErasePtrs[chipId])) begin
         cmdQ.deq();
      
         if (req.op != ERASE_BLOCK ) begin
            bypass = False;
            BlockIdxT addr = convertVirtualIdx(req.bus, req.chip, req.block);
            blockMap.portA.request.put(BRAMRequest{write: False,
                                                   responseOnWrite: False,
                                                   address: addr,
                                                   datain: ?
                                                   });
         

            if (req.op == WRITE_PAGE) begin
               pageCnts[chipId]  <= pageCnts[chipId] + 1;
               
               if( pageCnts[chipId] + 1 == 0 )
                  nextWritePtrs[chipId] <= nextWritePtrs[chipId] + 1;
            
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
      end
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
   

   rule distributeAck;
      let v <- flash.ackStatus;
      let tag = tpl_1(v);
      let status = tpl_2(v);
      if ( status == WRITE_DONE )
         ackStatusQs[0].enq(v);
      else
         ackStatusQs[1].enq(v);
   endrule
   
   
   interface FlashRawWriteServer writeServer;
      interface Server reserve = toServer(reserveReqQ, reserveRespQ);
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
   
   
   interface TagClient tagClient;
      interface Client reqTag;
         interface Get request = toGet(tagReqQ);
         interface Put response = toPut(freeTagQ);
      endinterface
      interface Get retTag = toGet(returnTagQ);
   endinterface
   
   method Action reset(Bit#(32) randV);
      for ( Integer i = 0; i < valueOf(NumChips); i = i + 1 ) begin
         nextPhysPtrs[i] <= truncate(randV);
         nextWritePtrs[i] <= 0;
         nextErasePtrs[i] <= 0;
      end
      `ifdef BSIM
      random.seed(1);
      `endif
      resetFlag <= True;
   endmethod

endmodule

module mkFlashServer_dummy#(FlashCtrlUser flash)(FlashServer);
   
   FIFO#(FlashCmd) cmdQ <- mkSizedFIFO(128);
   
   FIFO#(Bit#(32)) reserveReqQ <- mkFIFO();
   FIFO#(Bool) reserveRespQ <- mkFIFO();
   
   Reg#(Bit#(TLog#(PagesPerBlock))) pageCnt_chips <- mkReg(0);
   Reg#(Bit#(32)) responseCnt <- mkReg(0);
   rule doReserveReq;
      let numPages = reserveReqQ.first();
      reserveRespQ.enq(True);
   endrule

      
   rule doCmd;
      let cmd <- toGet(cmdQ).get();
      flash.sendCmd(cmd);
   endrule

   Vector#(2, FIFO#(Tuple2#(TagT,StatusT))) ackStatusQs <- replicateM(mkSizedFIFO(128));      
   rule distributeAck;
      let v <- flash.ackStatus;
      let tag = tpl_1(v);
      let status = tpl_2(v);
      if ( status == WRITE_DONE )
         ackStatusQs[0].enq(v);
      //else
         //ackStatusQs[1].enq(v);
   endrule

   FIFO#(Bit#(32)) tagReqQ <- mkFIFO();
   FIFO#(TagT) freeTagQ <- mkFIFO();
   FIFO#(TagT) returnTagQ <- mkFIFO();
   
   interface FlashRawWriteServer writeServer;
      interface Server reserve = toServer(reserveReqQ, reserveRespQ);
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
   
   
   interface TagClient tagClient;
      interface Client reqTag;
         interface Get request = toGet(tagReqQ);
         interface Put response = toPut(freeTagQ);
      endinterface
      interface Get retTag = toGet(returnTagQ);
   endinterface
   
   method Action reset(Bit#(32) randV);
   endmethod

   
   


endmodule

instance Connectable#(FlashRawWriteClient, FlashRawWriteServer);
   module mkConnection#(FlashRawWriteClient cli, FlashRawWriteServer ser)(Empty);
      mkConnection(cli.reserve, ser.reserve);
      mkConnection(cli.client, ser.server);
      mkConnection(cli.wordPipe, ser.wordPipe);
      mkConnection(cli.doneAck, ser.doneAck);
   endmodule
endinstance

instance Connectable#(FlashRawWriteServer, FlashRawWriteClient);
   module mkConnection#(FlashRawWriteServer ser, FlashRawWriteClient cli)(Empty);
      mkConnection(cli.reserve, ser.reserve);
      mkConnection(cli.client, ser.server);
      mkConnection(cli.wordPipe, ser.wordPipe);
      mkConnection(cli.doneAck, ser.doneAck);
   endmodule
endinstance
