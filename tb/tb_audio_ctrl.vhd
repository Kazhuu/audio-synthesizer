-------------------------------------------------------------------------------
-- File       : tb_audio_ctrl.vhd
-- Created    : 13.01.2018
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description:
-- Testbench for the audio_ctrl entity. Tb instantiates two wave_gen modules
-- to generate signals for the audio_ctrl module. External audio_codec_model
-- module is used to model Wolfson WM8731 audio codec.
-- Testbench samples wave_gen module input fed to audio_ctrl module and asserts
-- that audio_codec_model both outputs match the input data. This guarantees
-- that audio_ctrl is working as intended.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.all;


entity tb_audio_ctrl is
  generic (
    data_width_g    : integer := 16;
    wave_gen_l_n_g  : integer := 100;
    wave_gen_r_n_g  : integer := 200;
    clk_period_ns_g : integer := 50;    -- 20 Mhz
    sample_rate_g   : integer := 48_000
    );
end tb_audio_ctrl;

architecture testbench of tb_audio_ctrl is

  -- Declare wave_gen module.
  component wave_gen
    generic (
      width_g : positive;
      step_g  : positive
      );
    port (
      rst_n         : in  std_logic;
      clk           : in  std_logic;
      sync_clear_in : in  std_logic;
      value_out     : out std_logic_vector(width_g - 1 downto 0)
      );
  end component;

  -- Declare audio_ctrl module.
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

  -- Declare audio_codec_model module.
  component audio_codec_model
    generic (
      data_width_g : integer
      );
    port (
      rst_n           : in  std_logic;
      aud_data_in     : in  std_logic;
      aud_bclk_in     : in  std_logic;
      aud_lrclk_in    : in  std_logic;
      value_left_out  : out std_logic_vector(data_width_g - 1 downto 0);
      value_right_out : out std_logic_vector(data_width_g - 1 downto 0)
      );
  end component;

  -- Generated clock period in time unit.
  constant clk_period_time_c : time := clk_period_ns_g * 1 ns;
  -- Calculate master clock frequency.
  constant clk_frequency_c   : integer
    := integer(1.0 / (real(clk_period_ns_g) * 10.0**(-9)));

  -- Internal clock signal.
  signal clk        : std_logic := '0';
  -- Internal reset signal.
  signal rst_n      : std_logic := '0';
  -- Internal signal to clear to wave_gen modules during test.
  signal sync_clear : std_logic := '0';

  -- Data signals coming from wave_gen module outputs.
  signal l_data_wg_actrl : std_logic_vector(data_width_g - 1 downto 0);
  signal r_data_wg_actrl : std_logic_vector(data_width_g - 1 downto 0);

  -- Data signals between audio_ctrl and audio_codec_model.
  signal bclk_actrl_acmodel  : std_logic;
  signal data_actrl_acmodel  : std_logic;
  signal lrclk_actrl_acmodel : std_logic;

  -- Signals coming out from the audio_codec_model.
  signal tb_left_data_codec  : std_logic_vector(data_width_g -1 downto 0);
  signal tb_right_data_codec : std_logic_vector(data_width_g -1 downto 0);

  -- Registers for sample testing.
  signal last_lrclk_r            : std_logic;
  signal last_bclk_r             : std_logic;
  signal left_wg_sample_r        : std_logic_vector(data_width_g - 1 downto 0);
  signal right_wg_sample_r       : std_logic_vector(data_width_g - 1 downto 0);
  signal lrclk_l_wg_sample_r     : std_logic_vector(data_width_g - 1 downto 0);
  -- Right sampling needs two old values because new right value is sampled
  -- by the audio_ctrl before audio_codec_model outputs the transmitted
  -- right channel value.
  signal lrclk_r_wg_sample_r     : std_logic_vector(data_width_g - 1 downto 0);
  signal lrclk_r_wg_old_sample_r : std_logic_vector(data_width_g - 1 downto 0);

  -- Registers for clock edge testing.
  signal last_bclk_value_r  : std_logic;
  signal last_lrclk_value_r : std_logic;

begin

  -- Process to generate master clock.
  clk_gen : process(clk)
  begin  -- process clk_gen
    clk <= not clk after clk_period_time_c / 2;
  end process clk_gen;

  -- Synchronous reset at start after four clock periods.
  rst_n <= '1' after clk_period_time_c * 4;

  -- Generate sync_clear so that wave_gen modules are zeroed.
  sync_clear <= '0',
                '1' after 10 ms,
                '0' after 11 ms;


  -- Instantiate wave_gen module to generate the right channel data.
  i_wave_gen_r : wave_gen
    generic map (
      width_g => data_width_g,
      step_g  => wave_gen_l_n_g
      )
    port map (
      rst_n         => rst_n,
      clk           => clk,
      sync_clear_in => sync_clear,
      value_out     => r_data_wg_actrl
      );
  -- Instantiate wave_gen module to generate the left channel data.
  i_wave_gen_l : wave_gen
    generic map (
      width_g => data_width_g,
      step_g  => wave_gen_r_n_g
      )
    port map (
      rst_n         => rst_n,
      clk           => clk,
      sync_clear_in => sync_clear,
      value_out     => l_data_wg_actrl
      );
  -- Instantiate audio_ctrl module.
  i_audio_ctrl : audio_ctrl
    generic map (
      ref_clk_freq_g => clk_frequency_c,
      sample_rate_g  => sample_rate_g,
      data_width_g   => data_width_g
      )
    port map (
      rst_n         => rst_n,
      clk           => clk,
      left_data_in  => l_data_wg_actrl,
      right_data_in => r_data_wg_actrl,
      aud_bclk_out  => bclk_actrl_acmodel,
      aud_data_out  => data_actrl_acmodel,
      aud_lrclk_out => lrclk_actrl_acmodel
      );
  -- Instantiate audio_codec_model module.
  i_audio_codec_model : audio_codec_model
    generic map (
      data_width_g => data_width_g
      )
    port map (
      rst_n           => rst_n,
      aud_bclk_in     => bclk_actrl_acmodel,
      aud_data_in     => data_actrl_acmodel,
      aud_lrclk_in    => lrclk_actrl_acmodel,
      value_left_out  => tb_left_data_codec,
      value_right_out => tb_right_data_codec
      );

  -- Process to sample wave_gen outputs.
  test_output : process(clk, rst_n)
  begin
    if rst_n = '0' then                 -- asynchronous reset, active low.
      last_lrclk_r            <= '0';
      last_bclk_r             <= '0';
      left_wg_sample_r        <= (others => '0');
      right_wg_sample_r       <= (others => '0');
      lrclk_l_wg_sample_r     <= (others => '0');
      lrclk_r_wg_sample_r     <= (others => '0');
      lrclk_r_wg_old_sample_r <= (others => '0');

    elsif clk'event and clk = '1' then  -- rising edge of the clock.
      -- Sample clock rising edge values.
      left_wg_sample_r  <= l_data_wg_actrl;
      right_wg_sample_r <= r_data_wg_actrl;
      -- Last value of lrclk.
      last_lrclk_r      <= lrclk_actrl_acmodel;
      -- When data has come out from the audio_codec_model, copy last
      -- sample values.
      if last_lrclk_r = '0' and lrclk_actrl_acmodel = '1' then
        lrclk_l_wg_sample_r     <= left_wg_sample_r;
        -- Right channel needs two old sample values because of the output
        -- delay from audio_codec_model.
        lrclk_r_wg_sample_r     <= right_wg_sample_r;
        lrclk_r_wg_old_sample_r <= lrclk_r_wg_sample_r;
      end if;

    end if;
  end process test_output;

  -- Combinational process to assert left data output.
  test_left : process(tb_left_data_codec)
  begin
    assert lrclk_l_wg_sample_r = tb_left_data_codec
      report "left data input signal does not match the output"
      severity failure;
  end process test_left;

  -- Combinational process to assert right data output.
  test_right : process(tb_right_data_codec)
  begin
    assert lrclk_r_wg_old_sample_r = tb_right_data_codec
      report "right data input signal does not match the output"
      severity failure;
  end process;

  -- Test that lrclk and bclk is changing on the same edge of the clock.
  test_clock_edges : process(clk, rst_n)
  begin
    if rst_n = '0' then                 -- asynchronous reset, active low.
      last_bclk_value_r  <= '0';
      last_lrclk_value_r <= '0';

    elsif clk'event and clk = '1' then  -- rising edge of the clock.
      -- Sample clock values.
      last_bclk_value_r  <= bclk_actrl_acmodel;
      last_lrclk_value_r <= lrclk_actrl_acmodel;
      -- Test that lrclk change from high to low on bclk high to low transition.
      if last_lrclk_value_r = '1' and lrclk_actrl_acmodel = '0' then
        assert last_bclk_value_r = '1' and bclk_actrl_acmodel = '0'
          report "lrclk does not change on the bclk falling edge"
          severity failure;
      end if;
      -- Test that lrclk change from low to high on bclk high to low transition.
      if last_lrclk_value_r = '0' and lrclk_actrl_acmodel = '1' then
        assert last_bclk_value_r = '1' and bclk_actrl_acmodel = '0'
          report "lrclk does not change on the bclk falling edge"
          severity failure;
      end if;

    end if;
  end process test_clock_edges;

end testbench;
