package MyArbiter;

import Vector::*;
import BUtils::*;
import Connectable::*;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface ArbiterClient_IFC;
   method Action request();
   method Bool grant();
endinterface


interface Arbiter_IFC#(numeric type count);
   interface Vector#(count, ArbiterClient_IFC) clients;
   method    Bit#(TLog#(count))                grant_id;
endinterface

////////////////////////////////////////////////////////////////////////////////
/// A fair round robin arbiter with changing priorities. If the value of "fixed"
/// is True, the current grant is locked and not updated again until
/// "fixed" goes False;
////////////////////////////////////////////////////////////////////////////////

module mkArbiter#(Bool fixed) (Arbiter_IFC#(count));

   let icount = valueOf(count);

   // Initially, priority is given to client 0
   Vector#(count, Bool) init_value = replicate(False);
   init_value[0] = True;
   Reg#(Vector#(count, Bool)) priority_vector <- mkReg(init_value);


   Vector#(count, Wire#(Bool)) grant_vector   <- replicateM(mkWire);
   Wire#(Bit#(TLog#(count)))   grant_id_wire  <- mkWire;
   Vector#(count, PulseWire) request_vector <- replicateM(mkPulseWire);

   rule every (any(isPulseTrue, request_vector));

      // calculate the grant_vector
      //Vector#(count, Bool) zow = replicate(False);
      Vector#(count, Bool) grant_vector_local = replicate(False);
      Bit#(TLog#(count))   grant_id_local     = 0;

      Bool found = True;
      Bool flag = True;
      //Bool prevFound = False;

      for (Integer x = 0; x < 2*icount; x = x + 1)

	 begin

	    Integer y = (x % icount);

            //prevFound = found;
            
	    if (priority_vector[y] && flag) found = False;

	    let a_request = request_vector[y];
            //$display("(%t)MyArbiter, Request from %d is %d", $time, y, a_request);
	    //zow[y] = a_request;

	    if (!found && a_request)
	       begin
		  grant_vector_local[y] = True;
		  grant_id_local        = fromInteger(y);
		  found = True;
                  flag = False;
	       end
           /* else if (prevFound)
               begin
                  found = True;
               end*/
	 end
      
      // Update the RWire
      for (Integer i = 0; i < icount; i = i + 1) begin
         //if (request_vector[i]) begin
         grant_vector[i]  <= grant_vector_local[i];
         //end
      end
      grant_id_wire <= grant_id_local;
      
      /*
      $display("Priority Vector", fshow(priority_vector));
      $display("Request Vector", fshow(map(isPulseTrue,request_vector)));
      $display("Grant Vector", fshow(grant_vector_local));
      */
      // If a grant was given, update the priority vector so that
      // client now has lowest priority.
      if (any(isTrue,grant_vector_local))
	 begin
	    //$display("(%5d) Updating priorities", $time);
            if (!fixed)
	       priority_vector <= rotateR(grant_vector_local);
            else
               priority_vector <= grant_vector_local;
	 end


//      $display("(%5d)  priority vector: %4b", $time, priority_vector);
//      $display("(%5d)   request vector: %4b", $time, zow);
//      $display("(%5d)     Grant vector: %4b", $time, grant_vector_local);

   endrule

   // Now create the vector of interfaces
   Vector#(count, ArbiterClient_IFC) client_vector = newVector;

   for (Integer x = 0; x < icount; x = x + 1)

      client_vector[x] = (interface ArbiterClient_IFC

                          method Action request();
			     request_vector[x].send();
                          endmethod
         
                          method Bool grant();
                             return grant_vector[x];
                          endmethod

			  endinterface);

   interface clients = client_vector;
   method    grant_id = grant_id_wire;
endmodule

function Bool isTrue(Bool value);
   return value;
endfunction

function Bool isPulseTrue(PulseWire value);
   return value;
endfunction

endpackage
