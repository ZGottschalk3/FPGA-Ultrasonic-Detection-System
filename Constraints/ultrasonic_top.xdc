## Basys 3 constraints for ultrasonic_top (complete system)

## 100 MHz clock
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Buttons
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports btnC]
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports btnU]

## Switches
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports {sw[0]}]
set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports {sw[1]}]
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS33 } [get_ports {sw[2]}]
set_property -dict { PACKAGE_PIN W17 IOSTANDARD LVCMOS33 } [get_ports {sw[3]}]
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS33 } [get_ports {sw[4]}]
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports {sw[5]}]
set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 } [get_ports {sw[6]}]
set_property -dict { PACKAGE_PIN W13 IOSTANDARD LVCMOS33 } [get_ports {sw[7]}]
set_property -dict { PACKAGE_PIN V2  IOSTANDARD LVCMOS33 } [get_ports {sw[8]}]
set_property -dict { PACKAGE_PIN T3  IOSTANDARD LVCMOS33 } [get_ports {sw[9]}]
set_property -dict { PACKAGE_PIN T2  IOSTANDARD LVCMOS33 } [get_ports {sw[10]}]
set_property -dict { PACKAGE_PIN R3  IOSTANDARD LVCMOS33 } [get_ports {sw[11]}]
set_property -dict { PACKAGE_PIN W2  IOSTANDARD LVCMOS33 } [get_ports {sw[12]}]
set_property -dict { PACKAGE_PIN U1  IOSTANDARD LVCMOS33 } [get_ports {sw[13]}]
set_property -dict { PACKAGE_PIN T1  IOSTANDARD LVCMOS33 } [get_ports {sw[14]}]
set_property -dict { PACKAGE_PIN R2  IOSTANDARD LVCMOS33 } [get_ports {sw[15]}]

## LEDs
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports {led[7]}]
set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports {led[8]}]
set_property -dict { PACKAGE_PIN V3  IOSTANDARD LVCMOS33 } [get_ports {led[9]}]
set_property -dict { PACKAGE_PIN W3  IOSTANDARD LVCMOS33 } [get_ports {led[10]}]
set_property -dict { PACKAGE_PIN U3  IOSTANDARD LVCMOS33 } [get_ports {led[11]}]
set_property -dict { PACKAGE_PIN P3  IOSTANDARD LVCMOS33 } [get_ports {led[12]}]
set_property -dict { PACKAGE_PIN N3  IOSTANDARD LVCMOS33 } [get_ports {led[13]}]
set_property -dict { PACKAGE_PIN P1  IOSTANDARD LVCMOS33 } [get_ports {led[14]}]
set_property -dict { PACKAGE_PIN L1  IOSTANDARD LVCMOS33 } [get_ports {led[15]}]

## Tx outputs on Pmod JB -> PCB Tx drivers
set_property -dict { PACKAGE_PIN A14 IOSTANDARD LVCMOS33 } [get_ports {tx_out[0]}]     ;# JB1
set_property -dict { PACKAGE_PIN A16 IOSTANDARD LVCMOS33 } [get_ports {tx_out[1]}]     ;# JB2
set_property -dict { PACKAGE_PIN B15 IOSTANDARD LVCMOS33 } [get_ports {tx_out[2]}]     ;# JB3
set_property -dict { PACKAGE_PIN B16 IOSTANDARD LVCMOS33 } [get_ports tx_enable_out]   ;# JB4 scope trigger

## LCD on Pmod JA
set_property -dict { PACKAGE_PIN J1 IOSTANDARD LVCMOS33 } [get_ports {lcd_d[0]}]  ;# JA1 D4
set_property -dict { PACKAGE_PIN L2 IOSTANDARD LVCMOS33 } [get_ports {lcd_d[1]}]  ;# JA2 D5
set_property -dict { PACKAGE_PIN J2 IOSTANDARD LVCMOS33 } [get_ports {lcd_d[2]}]  ;# JA3 D6
set_property -dict { PACKAGE_PIN G2 IOSTANDARD LVCMOS33 } [get_ports {lcd_d[3]}]  ;# JA4 D7
set_property -dict { PACKAGE_PIN H1 IOSTANDARD LVCMOS33 } [get_ports lcd_rs]      ;# JA7
set_property -dict { PACKAGE_PIN K2 IOSTANDARD LVCMOS33 } [get_ports lcd_e]       ;# JA8

## Receivers on Pmod JXADC (analog inputs, 0 to 1 V only)
set_property -dict { PACKAGE_PIN J3 IOSTANDARD LVCMOS33 } [get_ports vauxp6]    ;# JXADC1 Rx1 +
set_property -dict { PACKAGE_PIN K3 IOSTANDARD LVCMOS33 } [get_ports vauxn6]    ;# JXADC7 Rx1 -
set_property -dict { PACKAGE_PIN L3 IOSTANDARD LVCMOS33 } [get_ports vauxp14]   ;# JXADC2 Rx2 +
set_property -dict { PACKAGE_PIN M3 IOSTANDARD LVCMOS33 } [get_ports vauxn14]   ;# JXADC8 Rx2 -
set_property -dict { PACKAGE_PIN M2 IOSTANDARD LVCMOS33 } [get_ports vauxp7]    ;# JXADC3 Rx3 +
set_property -dict { PACKAGE_PIN M1 IOSTANDARD LVCMOS33 } [get_ports vauxn7]    ;# JXADC9 Rx3 -

## coordinate_unit holds the distances for 150 clocks before the square root
## samples the result, so the divider paths get 150 cycles instead of 1.
set_multicycle_path -setup 150 -from [get_cells -hier -filter {NAME =~ *u_coord/d*_q_reg*}]
set_multicycle_path -hold  149 -from [get_cells -hier -filter {NAME =~ *u_coord/d*_q_reg*}]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
