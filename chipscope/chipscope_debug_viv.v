
module chipscope_debug_viv (
	                    input         v_clk0,
	                    input         v_rst0,

                            input [63:0]  v_debug0_0, //addr
	                    input [63:0]  v_debug0_1, //nBytes
	                    input [63:0]  v_debug0_2, //data

                            input [63:0]  v_debug1_0, //addr
	                    input [63:0]  v_debug1_1, //nBytes
	                    input [63:0]  v_debug1_2, //data

                            input [63:0]  v_debug2_0, //addr
                            input [63:0]  v_debug2_1, //writeen
                            input [511:0] v_debug2_2, //data_in
                            input [511:0] v_debug2_3, //data_out

                            input [63:0]  v_debug3_0, //addr
                            input [63:0]  v_debug3_1, //writeen
                            input [511:0] v_debug3_2, //data_in
                            input [511:0] v_debug3_3 //data_out
                            );


   
   //	(* mark_debug = "true", keep = "true" *) wire [15:0] v_test;
   //	assign v_test = v_debug0_0;

   (* mark_debug = "true" *) reg [63:0]  v_debug0_0_reg; //addr
   (* mark_debug = "true" *) reg [63:0]  v_debug0_1_reg; //nBytes
   (* mark_debug = "true" *) reg [63:0]  v_debug0_2_reg; //data
   
   (* mark_debug = "true" *) reg [63:0]  v_debug1_0_reg; //addr
   (* mark_debug = "true" *) reg [63:0]  v_debug1_1_reg; //nBytes
   (* mark_debug = "true" *) reg [63:0]  v_debug1_2_reg; //data
   
   (* mark_debug = "true" *) reg [63:0]  v_debug2_0_reg; //addr
   (* mark_debug = "true" *) reg [63:0]  v_debug2_1_reg; //writeen
   (* mark_debug = "true" *) reg [511:0] v_debug2_2_reg; //data_in
   (* mark_debug = "true" *) reg [511:0] v_debug2_3_reg; //data_out
   
   (* mark_debug = "true" *) reg [63:0]  v_debug3_0_reg; //addr
   (* mark_debug = "true" *) reg [63:0]  v_debug3_1_reg; //writeen
   (* mark_debug = "true" *) reg [511:0] v_debug3_2_reg; //data_in
   (* mark_debug = "true" *) reg [511:0] v_debug3_3_reg; //data_out

   
   always @  (posedge v_clk0)  begin
      v_debug0_0_reg 		<=		v_debug0_0;
      v_debug0_1_reg 		<=		v_debug0_1;
      v_debug0_2_reg 		<=		v_debug0_2;

      v_debug1_0_reg 		<=		v_debug1_0;
      v_debug1_1_reg 		<=		v_debug1_1;
      v_debug1_2_reg 		<=		v_debug1_2;

      v_debug2_0_reg 		<=		v_debug2_0;
      v_debug2_1_reg 		<=		v_debug2_1;
      v_debug2_2_reg 		<=		v_debug2_2;
      v_debug2_3_reg 		<=		v_debug2_3;

      v_debug3_0_reg 		<=		v_debug3_0;
      v_debug3_1_reg 		<=		v_debug3_1;
      v_debug3_2_reg 		<=		v_debug3_2;
      v_debug3_3_reg 		<=		v_debug3_3;
   end



   ila_0 ila0 (
	       .clk(v_clk0),
	       .probe0(v_debug0_0_reg),
	       .probe1(v_debug0_1_reg),
	       .probe2(v_debug0_2_reg),
	       
               .probe3(v_debug1_0_reg),
	       .probe4(v_debug1_1_reg),
	       .probe5(v_debug1_2_reg),
	       
               .probe6(v_debug2_0_reg),
	       .probe7(v_debug2_1_reg),
	       .probe8(v_debug2_2_reg),
	       .probe9(v_debug2_3_reg),
	       
               .probe10(v_debug3_0_reg),
	       .probe11(v_debug3_1_reg),
	       .probe12(v_debug3_2_reg),
	       .probe13(v_debug3_3_reg)
	       );

endmodule
