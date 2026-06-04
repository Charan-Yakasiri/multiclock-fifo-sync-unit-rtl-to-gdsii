############################################################
# sync_unit.sdc
############################################################

current_design sync_unit

############################################################
# CLOCKS
############################################################

create_clock \
-name cam1_pclk \
-period 13.333 \
-waveform {0 6.666} \
[get_ports cam1_pclk]

create_clock \
-name cam2_pclk \
-period 10.000 \
-waveform {0 5.000} \
[get_ports cam2_pclk]

create_clock \
-name sys_clk \
-period 10.000 \
-waveform {0 5.000} \
[get_ports sys_clk]

############################################################
# CLOCK ATTRIBUTES
############################################################

set_clock_uncertainty 0.10 [get_clocks cam1_pclk]
set_clock_uncertainty 0.10 [get_clocks cam2_pclk]
set_clock_uncertainty 0.10 [get_clocks sys_clk]

set_clock_transition 0.10 [get_clocks cam1_pclk]
set_clock_transition 0.10 [get_clocks cam2_pclk]
set_clock_transition 0.10 [get_clocks sys_clk]

set_clock_latency 0.20 [get_clocks cam1_pclk]
set_clock_latency 0.20 [get_clocks cam2_pclk]
set_clock_latency 0.20 [get_clocks sys_clk]

############################################################
# ASYNCHRONOUS CLOCK GROUPS
############################################################

set_clock_groups \
-asynchronous \
-group [get_clocks cam1_pclk] \
-group [get_clocks sys_clk]

set_clock_groups \
-asynchronous \
-group [get_clocks cam1_pclk] \
-group [get_clocks cam2_pclk]

############################################################
# RESET
############################################################

set_false_path \
-from [get_ports rst_n]

############################################################
# INPUT DELAYS
############################################################

set_input_delay 1.0 \
-clock cam1_pclk \
[get_ports {cam1_data[*]}]

set_input_delay 1.0 \
-clock cam1_pclk \
[get_ports cam1_write_en]

set_input_delay 1.0 \
-clock cam2_pclk \
[get_ports {cam2_data[*]}]

set_input_delay 1.0 \
-clock cam2_pclk \
[get_ports cam2_write_en]

set_input_delay 1.0 \
-clock sys_clk \
[get_ports out_read_en]

############################################################
# OUTPUT DELAYS
############################################################

set_output_delay 1.0 \
-clock sys_clk \
[get_ports {out_data_cam1[*]}]

set_output_delay 1.0 \
-clock sys_clk \
[get_ports {out_data_cam2[*]}]

set_output_delay 1.0 \
-clock sys_clk \
[get_ports out_empty]

set_output_delay 1.0 \
-clock sys_clk \
[get_ports lock_signal]

set_output_delay 1.0 \
-clock sys_clk \
[get_ports {align_state[*]}]

############################################################
# DESIGN RULE CONSTRAINTS
############################################################

set_max_transition 0.5 [current_design]

set_max_fanout 10 [current_design]

set_max_capacitance 0.1 [current_design]

############################################################
# INPUT DRIVE
############################################################

set_drive 1 [get_ports {cam1_data[*]}]
set_drive 1 [get_ports cam1_write_en]

set_drive 1 [get_ports {cam2_data[*]}]
set_drive 1 [get_ports cam2_write_en]

set_drive 1 [get_ports out_read_en]

############################################################
# OUTPUT LOAD
############################################################

set_load 0.05 [get_ports {out_data_cam1[*]}]
set_load 0.05 [get_ports {out_data_cam2[*]}]

set_load 0.05 [get_ports out_empty]
set_load 0.05 [get_ports lock_signal]
set_load 0.05 [get_ports {align_state[*]}]

############################################################
# CDC SYNCHRONIZER FALSE PATHS
############################################################

set_false_path \
-to [get_cells *wr_rd_ptr_gray_s1*]

set_false_path \
-to [get_cells *rd_wr_ptr_gray_s1*]

############################################################
# END
############################################################
