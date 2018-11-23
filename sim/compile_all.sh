#!/bin/sh
if [ -z $TMP_DIR ]; then
    echo "Please set env variable TMP_DIR which tells where the codes are compiled to."
    echo "Use e.g. /share/tmp/<user_name>/djt or just . (=this directory)"
    echo "Exiting script."
    exit 1
fi

echo "1/4 Removing old vhdl library and create new at "
mkdir -p $TMP_DIR
rm -rf $TMP_DIR/work
vlib $TMP_DIR/work
vmap work $TMP_DIR/work

echo "2/4 Compiling vhdl codes"
vcom -quiet -check_synthesis ../vhd/ripple_carry_adder.vhd
vcom -quiet -check_synthesis ../vhd/adder.vhd
vcom -quiet -check_synthesis ../vhd/multi_port_adder.vhd
vcom -quiet -check_synthesis -87 ../vhd/wave_gen.vhd
vcom -quiet -check_synthesis -87 ../vhd/audio_ctrl.vhd
vcom -quiet -check_synthesis -87 ../vhd/audio_codec_model.vhd
vcom -quiet -check_synthesis -87 ../vhd/piano.vhd
vcom -quiet -check_synthesis -87 ../vhd/synthesizer.vhd
vcom -quiet -check_synthesis -87 -cover sbf ../vhd/i2c_config.vhd

echo "3/4 Compiling vhdl testbenches"
vcom -quiet -check_synthesis ../tb/tb_ripple_carry_adder.vhd
vcom -quiet -check_synthesis ../tb/tb_adder.vhd
vcom -quiet -check_synthesis -93 ../tb/tb_multi_port_adder.vhd
vcom -quiet -check_synthesis ../tb/tb_wave_gen.vhd
vcom -quiet -check_synthesis -87 ../tb/tb_audio_ctrl.vhd
vcom -quiet -check_synthesis -87 ../tb/tb_synthesizer.vhd
vcom -quiet -87 ../tb/tb_piano.vhd
vcom -quiet -87 ../tb/tb_i2c_config.vhd

echo "4/4 Removing and then creating a new makefile"
rm -f makefile
vmake $TMP_DIR/work > makefile

echo "--- Done---"
