// Copyright 1986-2014 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2014.1 (lin64) Build 881834 Fri Apr  4 14:00:25 MDT 2014
// Date        : Wed Sep 24 18:48:04 2014
// Host        : umma running 64-bit Ubuntu 12.04.5 LTS
// Command     : write_verilog -force -mode synth_stub /home/shuotao/workspace/chipscope/ila_0/ila_0_stub.v
// Design      : ila_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7vx485tffg1761-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "ila,Vivado 2014.1" *)
module ila_0(clk, probe0, probe1, probe2, probe3, probe4, probe5, probe6, probe7, probe8, probe9, probe10, probe11, probe12, probe13)
/* synthesis syn_black_box black_box_pad_pin="clk,probe0[63:0],probe1[63:0],probe2[63:0],probe3[63:0],probe4[63:0],probe5[63:0],probe6[63:0],probe7[63:0],probe8[511:0],probe9[511:0],probe10[63:0],probe11[63:0],probe12[511:0],probe13[511:0]" */;
  input clk;
  input [63:0]probe0;
  input [63:0]probe1;
  input [63:0]probe2;
  input [63:0]probe3;
  input [63:0]probe4;
  input [63:0]probe5;
  input [63:0]probe6;
  input [63:0]probe7;
  input [511:0]probe8;
  input [511:0]probe9;
  input [63:0]probe10;
  input [63:0]probe11;
  input [511:0]probe12;
  input [511:0]probe13;
endmodule
