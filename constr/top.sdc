# create input clock which is 12MHz
create_clock -name clk_12 -period 83.333 [get_ports {clk_12}]

# derive PLL clocks
derive_pll_clocks

# derive clock uncertainty
derive_clock_uncertainty

# set false path
set_false_path -from [get_ports {user_btn}]
set_false_path -from * -to [get_ports {led*}]
set_output_delay -clock { U_PLL|altpll_component|auto_generated|pll1|clk[1] } 0.300 [get_ports {ftdi_rx}]