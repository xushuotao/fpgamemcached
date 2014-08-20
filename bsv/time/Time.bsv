package Time;

typedef struct {
   Bit#(6) tm_year; //years [0,9]
   Bit#(9) tm_day; //days [0, 364]
   Bit#(5) tm_hour; //hour [0,23]
   Bit#(6) tm_min; //minutes [0,59]
   Bit#(6) tm_sec; //seconds [0,59]
   } Time_t deriving (Bits, Eq); // size of Time_t is 32 bits

interface Clk_ifc;
   method Time_t get_time();
endinterface

typedef 120 Fpga_freq; // FPGA Clock Frequency, default: 200MHz
/*
typeclass Literal #(type data_t);
   function data_t fromInteger(Integer x);
   function Bool inLiteralRange(data_t target, Integer x);
endtypeclass
*/

instance Ord#(Time_t);
   function Bool \< (Time_t x, Time_t y);
      return pack(x) < pack(y);
   endfunction
   
   function Bool \<= (Time_t x, Time_t y);
      return pack(x) <= pack(y);
   endfunction
   
   function Bool \> (Time_t x, Time_t y);
      return pack(x) > pack(y);
   endfunction
   
   function Bool \>= (Time_t x, Time_t y);
      return pack(x) >= pack(y);
   endfunction
endinstance

instance Literal#(Time_t);
   function Time_t fromInteger(Integer x);
      return unpack(0);
   endfunction
   function Bool inLiteralRange(Time_t target, Integer x);
      return x==0;
   endfunction
endinstance

(*synthesize*)
module mkLogicClock(Clk_ifc);
   
   Reg#(Bit#(8)) reg_cnt <- mkReg(0); // fpga clock counter
   Reg#(Bit#(6)) reg_sec <- mkReg(0); //seconds [0,59]
   Reg#(Bit#(6)) reg_min <- mkReg(0); //minutes [0,59]
   Reg#(Bit#(5)) reg_hour <- mkReg(0); //hour [0,23]
   Reg#(Bit#(9)) reg_day <- mkReg(1); //days [1, 365]
   Reg#(Bit#(6)) reg_year <- mkReg(1); //years [1,10]
      
   
   rule update_time;
      if (reg_cnt == fromInteger(valueOf(TSub#(Fpga_freq,1)))) begin
         reg_cnt <= 0;
         if (reg_sec == 59) begin
            reg_sec <= 0;
            if (reg_min == 59) begin
               reg_min <= 0;
               if (reg_hour == 23) begin
                  reg_hour <= 0;
                  if(reg_day == 364) begin
                     reg_day <= 0;
                     if (reg_year == 9) begin
                        reg_year <= 0;
                     end
                     else begin
                        reg_year <= reg_year + 1;
                     end
                  end
                  else begin
                     reg_day <= reg_day;
                  end
               end
               else begin
                  reg_hour <= reg_hour + 1;
               end
            end
            else begin
               reg_min <= reg_min + 1;
            end
         end
         else begin
            reg_sec <= reg_sec + 1;
         end
      end
      else begin
         reg_cnt <= reg_cnt + 1;
      end
   endrule
   
   method Time_t get_time();
      Time_t retval;
      retval.tm_sec = reg_sec;
      retval.tm_min = reg_min;
      retval.tm_hour = reg_hour;
      retval.tm_day = reg_day;
      retval.tm_year = reg_year;
      return retval;
   endmethod
endmodule
  
endpackage: Time
