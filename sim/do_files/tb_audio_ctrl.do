make
vsim work.tb_audio_ctrl

view source
view objects
view variables
view wave -undock

delete wave *
add wave tb_audio_ctrl/clk
add wave tb_audio_ctrl/rst_n
add wave tb_audio_ctrl/sync_clear
add wave tb_audio_ctrl/i_audio_ctrl/lrclk_counter_r
add wave tb_audio_ctrl/i_audio_ctrl/bclk_counter_r
add wave tb_audio_ctrl/i_audio_ctrl/left_data_r
add wave tb_audio_ctrl/i_audio_ctrl/right_data_r
add wave tb_audio_ctrl/lrclk_actrl_acmodel
add wave tb_audio_ctrl/bclk_actrl_acmodel
add wave tb_audio_ctrl/i_audio_ctrl/bit_counter_r
add wave tb_audio_ctrl/data_actrl_acmodel
add wave tb_audio_ctrl/tb_left_data_codec
add wave tb_audio_ctrl/tb_right_data_codec
add wave tb_audio_ctrl/l_data_wg_actrl
add wave tb_audio_ctrl/r_data_wg_actrl

run 15 ms
