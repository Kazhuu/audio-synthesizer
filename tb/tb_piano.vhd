-------------------------------------------------------------------------------
-- File       : tb_piano.vhd
-- Created    : 23.2.2018
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description:
-- Simple testbench for piano block.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity tb_piano is
end tb_piano;


architecture testbench of tb_piano is

  constant n_keys_c           : integer := 4;
  constant clk_freq_c         : integer := 20_000_000;
  constant clk_period_c       : time    := 20 ns;
  constant tone_change_freq_c : real    := 1_000_000.0;

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

  signal clk   : std_logic := '0';
  signal rst_n : std_logic := '0';

  -- Signals fed to DUV.
  signal enable : std_logic := '0';
  signal keys_r : std_logic_vector(n_keys_c - 1 downto 0);

  signal end_r : std_logic_vector(n_keys_c - 1 downto 0) := (others => '1');

begin

  clk    <= not clk after clk_period_c / 2;
  rst_n  <= '1'     after clk_period_c * 4;
  enable <= '1'     after clk_period_c * 8;

  piano_i : piano
    generic map (
      clk_freq_g         => clk_freq_c,
      tone_change_freq_g => tone_change_freq_c,
      n_keys_g           => n_keys_c
      )
    port map (
      clk       => clk,
      rst_n     => rst_n,
      enable_in => enable,
      keys_out  => keys_r
      );

  -- Test that enable works as intended.
  test_enable : process(enable)
  begin
    if enable = '0' then
      assert to_integer(signed(keys_r)) = 0
        report "enable not disabling keys output"
        severity failure;
    end if;
  end process test_enable;

  -- End when maximum key value is reached.
  assert keys_r /= end_r
    report "simulation done"
    severity failure;

end testbench;
