
module ila_dma_viv (
	            input         v_clk0,
	            input         v_rst0,

                    input [31:0]  v_debug0_0, //addr
	            input [63:0]  v_debug0_1, //nBytes
	            input [63:0]  v_debug0_2, //data

                    input [31:0]  v_debug1_0, //addr
	            input [63:0]  v_debug1_1, //nBytes
	            input [63:0]  v_debug1_2  //data
                    );


   
   //	(* mark_debug = "true", keep = "true" *) wire [15:0] v_test;
   //	assign v_test = v_debug0_0;

   (* mark_debug = "true" *) reg [31:0]  v_debug0_0_reg; //addr
   (* mark_debug = "true" *) reg [63:0]  v_debug0_1_reg; //nBytes
   (* mark_debug = "true" *) reg [63:0]  v_debug0_2_reg; //data
   
   (* mark_debug = "true" *) reg [31:0]  v_debug1_0_reg; //addr
   (* mark_debug = "true" *) reg [63:0]  v_debug1_1_reg; //nBytes
   (* mark_debug = "true" *) reg [63:0]  v_debug1_2_reg; //data
   
   
   always @  (posedge v_clk0)  begin
      v_debug0_0_reg 		<=		v_debug0_0;
      v_debug0_1_reg 		<=		v_debug0_1;
      v_debug0_2_reg 		<=		v_debug0_2;

      v_debug1_0_reg 		<=		v_debug1_0;
      v_debug1_1_reg 		<=		v_debug1_1;
      v_debug1_2_reg 		<=		v_debug1_2;
   end



   ila_dma iladma (
	           .clk(v_clk0),
	           .probe0(v_debug0_0_reg),
	           .probe1(v_debug0_1_reg),
	           .probe2(v_debug0_2_reg),
      
                   .probe3(v_debug1_0_reg),
	           .probe4(v_debug1_1_reg),
	           .probe5(v_debug1_2_reg)
                   );

endmodule
