import FIFO::*;
import GetPut::*;
import MemcachedTypes::*;

import Connectable::*;

interface EndPointClient#(type t);
   interface Get#(Tuple2#(t, NodeT)) send;
   interface Put#(Tuple2#(t, NodeT)) recv;
endinterface

interface EndPointServer#(type t);
   interface Put#(Tuple2#(t, NodeT)) send;
   interface Get#(Tuple2#(t, NodeT)) recv;
endinterface

function EndPointClient#(t) toEndPointClient(FIFO#(Tuple2#(t, NodeT)) sendQ, FIFO#(Tuple2#(t, NodeT)) recvQ);
   return (interface EndPointClient#(t);
              interface Get send = toGet(sendQ);
              interface Put recv = toPut(recvQ);
           endinterface);
endfunction

instance Connectable#(EndPointClient#(t), EndPointServer#(t));
   module mkConnection#(EndPointClient#(t) cli, EndPointServer#(t) ser)(Empty);
      mkConnection(cli.send, ser.send);
      mkConnection(cli.recv, ser.recv);
   endmodule
endinstance

instance Connectable#(EndPointServer#(t), EndPointClient#(t));
   module mkConnection#(EndPointServer#(t) ser, EndPointClient#(t) cli)(Empty);
      mkConnection(cli.send, ser.send);
      mkConnection(cli.recv, ser.recv);
   endmodule
endinstance
