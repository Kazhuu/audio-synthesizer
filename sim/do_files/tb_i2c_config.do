make
vsim work.tb_i2c_config

view source
view objects
view variables
view wave -undock

delete wave *
add wave tb_i2c_config/clk
add wave tb_i2c_config/i2c_config_1/param_status_out
add wave tb_i2c_config/i2c_config_1/config_index_r
add wave tb_i2c_config/i2c_config_1/transfer_r
add wave tb_i2c_config/i2c_config_1/bit_index_r
add wave tb_i2c_config/i2c_config_1/sdat_inout
add wave tb_i2c_config/i2c_config_1/sclk_out
add wave tb_i2c_config/succ_trans_counter_r
add wave tb_i2c_config/nack_counter_r
add wave tb_i2c_config/i2c_config_1/sdat_hold_counter_r
add wave tb_i2c_config/i2c_config_1/sdat_counter_r
add wave tb_i2c_config/i2c_config_1/sdat_curr_max_r
add wave tb_i2c_config/i2c_config_1/sclk_counter_r
add wave tb_i2c_config/i2c_config_1/curr_state_r
add wave tb_i2c_config/param_status
add wave tb_i2c_config/curr_state_r
add wave tb_i2c_config/bit_counter_r
add wave tb_i2c_config/byte_counter_r
add wave tb_i2c_config/sdat_old_r
add wave tb_i2c_config/sclk_old_r
add wave tb_i2c_config/sdat_r

run 18000 us
