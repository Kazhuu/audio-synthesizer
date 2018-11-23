make
vsim work.tb_synthesizer

view source
view objects
view variables
view wave -undock

delete wave *
add wave tb_synthesizer/clk
add wave tb_synthesizer/rst_n
add wave tb_synthesizer/enable
add wave tb_synthesizer/i_duv_synth/keys_wg 
add wave tb_synthesizer/keys_tb_synth
add wave tb_synthesizer/i_duv_synth/data_wg1_4_mpa
add wave tb_synthesizer/i_duv_synth/sum
add wave tb_synthesizer/i_duv_synth/audio_data_actrl
add wave tb_synthesizer/aud_lrclk_synth_model
add wave tb_synthesizer/aud_bclk_synth_model
add wave tb_synthesizer/aud_data_synth_model
add wave tb_synthesizer/value_left_model_tb
add wave tb_synthesizer/value_right_model_tb
add wave tb_synthesizer/i_duv_synth/i_multi_port_adder/overflow_out

run 100 ms
