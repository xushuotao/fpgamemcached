-- Copyright 1986-2014 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2014.1 (lin64) Build 881834 Fri Apr  4 14:00:25 MDT 2014
-- Date        : Wed Sep 24 18:48:04 2014
-- Host        : umma running 64-bit Ubuntu 12.04.5 LTS
-- Command     : write_vhdl -force -mode synth_stub /home/shuotao/workspace/chipscope/ila_0/ila_0_stub.vhdl
-- Design      : ila_0
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7vx485tffg1761-2
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ila_0 is
  Port ( 
    clk : in STD_LOGIC;
    probe0 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe1 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe2 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe3 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe4 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe5 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe6 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe7 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe8 : in STD_LOGIC_VECTOR ( 511 downto 0 );
    probe9 : in STD_LOGIC_VECTOR ( 511 downto 0 );
    probe10 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe11 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe12 : in STD_LOGIC_VECTOR ( 511 downto 0 );
    probe13 : in STD_LOGIC_VECTOR ( 511 downto 0 )
  );

end ila_0;

architecture stub of ila_0 is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk,probe0[63:0],probe1[63:0],probe2[63:0],probe3[63:0],probe4[63:0],probe5[63:0],probe6[63:0],probe7[63:0],probe8[511:0],probe9[511:0],probe10[63:0],probe11[63:0],probe12[511:0],probe13[511:0]";
attribute X_CORE_INFO : string;
attribute X_CORE_INFO of stub : architecture is "ila,Vivado 2014.1";
begin
end;
