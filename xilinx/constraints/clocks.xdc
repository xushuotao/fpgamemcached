create_clock -name bscan_refclk -period 20 [get_pins host_pciehost_bscan_bscan/TCK]

create_clock -name pci_refclk -period 10 [get_pins *pci_clk_100mhz_buf/O]
create_clock -name pci_extclk -period 10 [get_pins *ep7/pcie_ep/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtx_channel.gtxe2_channel_i/TXOUTCLK]

create_generated_clock -name clk_250mhz -source [get_pins *ep7/pcie_ep/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtx_channel.gtxe2_channel_i/TXOUTCLK] -multiply_by 10 -divide_by 4 [get_pins host_ep7/clockGen_pll/CLKOUT2]

#create_generated_clock -name clk_125mhz -source [get_pins host_ep7/clockGen_pll/CLKOUT2] -multiply_by 1 -divide_by 2 [get_pins host_ep7/CLK_epClock125]

create_generated_clock -name clk_125mhz -source [get_pins host_ep7/clockGen_pll/CLKOUT2] -multiply_by 1 -divide_by 2 [get_pins host_ep7/clkgen_pll/CLKOUT0]

#set_clock_groups -name ___clk_groups_generated_0_1_0_0_0 -physically_exclusive -group [get_clocks clk_125mhz] -group [get_clocks clk_250mhz]
set_max_delay -from [get_clocks clk_125mhz] -to [get_clocks clk_250mhz] 4.000 -datapath_only
set_max_delay -from [get_clocks clk_250mhz] -to [get_clocks clk_125mhz] 4.000 -datapath_only

#Bscan ref clk to 125mhz clk
set_false_path -from [get_clocks clk_125mhz] -to [get_clocks bscan_refclk]
set_false_path -from [get_clocks bscan_refclk] -to [get_clocks clk_125mhz]

