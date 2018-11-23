make
vsim work.tb_piano

view source
view objects
view variables
view wave -undock

delete wave *
add wave clk
add wave enable
add wave piano_i/counter_r
add wave piano_i/counter_max_c
add wave piano_i/keys_index_r
add wave piano_i/keys_out
add wave keys_r

run 10us
