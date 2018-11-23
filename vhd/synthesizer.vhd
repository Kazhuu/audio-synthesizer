-------------------------------------------------------------------------------
-- File       : synthesizer.vhd
-- Created    : 27.01.2018
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description:
-- Module instantiates n_keys_g wave_gen modules, one multi_port_adder and
-- one audio_ctrl. wave_gen modules sync_clear is controlled with active high
-- keys_in input. Generated waveforms are added together with multi_port_adder
-- and then fed to audio_ctrl which in turn provides aud_* outputs.
--
-- Module also checks for multi_port_adder overflow signal and saturates audio
-- data line going to audio_ctrl aud_data_in input. Maximum or minimum value
-- is assigned instead.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.all;


entity synthesizer is
  generic (
    clk_freq_g         : integer := 18_432_000;  -- 18.432 MHz
    sample_rate_g      : integer := 48_000;      -- 48 KHz
    tone_change_freq_g : real    := 2.0;         -- 0.5 s/tone
    data_width_g       : integer := 16;
    n_keys_g           : integer := 4
    );
  port (
    rst_n         : in  std_logic;
    clk           : in  std_logic;
    enable_piano  : in  std_logic;
    keys_in       : in  std_logic_vector(n_keys_g - 1 downto 0);
    aud_bclk_out  : out std_logic;
    aud_data_out  : out std_logic;
    aud_lrclk_out : out std_logic
    );
end synthesizer;

architecture structural of synthesizer is

  -- Declare wave_gen.
  component wave_gen
    generic (
      width_g : positive;
      step_g : positive
      );
    port (
      rst_n         : in  std_logic;
      clk           : in  std_logic;
      sync_clear_in : in  std_logic;
      value_out     : out std_logic_vector(width_g - 1 downto 0)
      );
  end component;

  -- Declare multi_port_adder.
  component multi_port_adder
    generic (
      operand_width_g   : integer;
      num_of_operands_g : integer
      );
    port (
      rst_n        : in  std_logic;
      clk          : in  std_logic;
      operands_in  : in  std_logic_vector(
        (operand_width_g * num_of_operands_g) - 1 downto 0);
      sum_out      : out std_logic_vector(operand_width_g - 1 downto 0);
      overflow_out : out std_logic
      );
  end component;

  -- Declare audio_ctrl.
  component audio_ctrl
    generic (
      ref_clk_freq_g : integer;
      sample_rate_g  : integer;
      data_width_g   : integer
      );
    port (
      rst_n         : in  std_logic;
      clk           : in  std_logic;
      left_data_in  : in  std_logic_vector(data_width_g - 1 downto 0);
      right_data_in : in  std_logic_vector(data_width_g - 1 downto 0);
      aud_bclk_out  : out std_logic;    -- audio bit clock output
      aud_data_out  : out std_logic;    -- data output
      aud_lrclk_out : out std_logic     -- left-right clock output
      );
  end component;

  -- Declare piano.
  component piano
    generic (
      clk_freq_g         : positive;
      tone_change_freq_g : real;
      n_keys_g           : positive
      );
    port (
      clk       : in  std_logic;
      rst_n     : in  std_logic;
      enable_in : in  std_logic;
      keys_out  : out std_logic_vector(n_keys_g - 1 downto 0)
      );
  end component;

  -- Constant to multiply wave_gen modules step_g generic value.
  -- Affects generated wave frequency.
  constant n_multiply_c    : integer := 300;
  -- Length of data line from wave_gen to multi_port_adder.
  constant wg_mpa_length_c : integer := (data_width_g * n_keys_g) - 1;
  -- Data signal from wave_gen 1-4 to multi_port_adder.
  signal data_wg1_4_mpa    : std_logic_vector(wg_mpa_length_c downto 0);

  -- Register to hold overflow logic from multi_port_adder.
  signal overflow_r : std_logic;

  -- Sum out from the multi_port_adder.
  signal sum              : std_logic_vector(data_width_g - 1 downto 0);
  -- Register to hold last value of the multi_port_adder sum.
  signal last_sum_r       : std_logic_vector(data_width_g - 1 downto 0);
  -- Overflow saturated data to audio_ctrl left and right inputs.
  signal audio_data_actrl : std_logic_vector(data_width_g - 1 downto 0);
  -- keys_in signal fed into to wave_gen blocks.
  signal keys_wg          : std_logic_vector(n_keys_g - 1 downto 0);
  -- Keys signal coming from piano block.
  signal keys_piano       : std_logic_vector(n_keys_g - 1 downto 0);


begin

  -- Generate n_keys_g amount of wave_gen instances.
  -- Step values are calculated using 2^i.
  g_wave_gens : for i in 0 to n_keys_g - 1 generate
    i_wave_gen : wave_gen
      generic map (
        width_g => data_width_g,
        step_g => (n_keys_g + 1) * n_multiply_c
        )
      port map (
        rst_n         => rst_n,
        clk           => clk,
        sync_clear_in => keys_wg(n_keys_g - i - 1),
        value_out
        => data_wg1_4_mpa(wg_mpa_length_c - (data_width_g * i)
                          downto data_width_g * (n_keys_g - i - 1))
        );
  end generate;

  -- Instantiate multi_port_adder.
  i_multi_port_adder : multi_port_adder
    generic map (
      operand_width_g   => data_width_g,
      num_of_operands_g => n_keys_g
      )
    port map (
      rst_n        => rst_n,
      clk          => clk,
      operands_in  => data_wg1_4_mpa,
      sum_out      => sum,
      overflow_out => overflow_r
      );

  -- Instantiate audio_ctrl.
  i_audio_ctrl : audio_ctrl
    generic map (
      ref_clk_freq_g => clk_freq_g,
      sample_rate_g  => sample_rate_g,
      data_width_g   => data_width_g
      )
    port map (
      rst_n         => rst_n,
      clk           => clk,
      left_data_in  => audio_data_actrl,
      right_data_in => audio_data_actrl,
      aud_bclk_out  => aud_bclk_out,
      aud_data_out  => aud_data_out,
      aud_lrclk_out => aud_lrclk_out
      );

  -- Instantiate piano.
  piano_i : piano
    generic map (
      clk_freq_g         => clk_freq_g,
      tone_change_freq_g => tone_change_freq_g,
      n_keys_g           => n_keys_g
      )
    port map (
      clk       => clk,
      rst_n     => rst_n,
      enable_in => enable_piano,
      keys_out  => keys_piano
      );

  control_overflow : process(clk, rst_n)
  begin
    if rst_n = '0' then                 -- asynchronous reset, active low.
      last_sum_r       <= (others => '0');
      audio_data_actrl <= (others => '0');

    elsif clk'event and clk = '1' then  -- rising edge of the clock.

      if overflow_r = '0' then
        -- Sample last sum value when overflow is low.
        last_sum_r       <= sum;
        audio_data_actrl <= sum;
      else
        if to_integer(unsigned(last_sum_r)) < to_integer(unsigned(sum)) then
          -- Rising signal, assign maximum value.
          audio_data_actrl <= std_logic_vector(
            to_signed(2**(data_width_g - 1) - 1, data_width_g)
            );
        else
          -- Falling signal, assign minimum value.
          audio_data_actrl <= std_logic_vector(
            to_signed(-(2**(data_width_g - 1)), data_width_g)
            );
        end if;
      end if;

    end if;
  end process control_overflow;

  -- Select piano output instead of buttons when enable_piano is high.
  with enable_piano select keys_wg <=
    not keys_piano when '1',
    keys_in        when others;


end structural;
