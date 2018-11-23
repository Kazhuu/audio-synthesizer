make
vsim work.tb_wave_gen

view source
view objects
view variables
view wave -undock

delete wave *
add wave clk
add wave rst_n
add wave sync_clear
add wave output

run 1000us
