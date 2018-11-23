-------------------------------------------------------------------------------
-- File       : piano.vhd
-- Created    : 23.2.2018
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description:
-- Simple piano block which produces n_keys_g output.
-- Can be used to play melody instead of key presses.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;


entity piano is
  generic (
    clk_freq_g         : positive := 18_432_000;  -- 18.432 MHz
    tone_change_freq_g : real     := 0.5;         -- 2 seconds/tone.
    n_keys_g           : positive := 4
    );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    enable_in : in  std_logic;
    keys_out  : out std_logic_vector(n_keys_g - 1 downto 0)
    );
end piano;


architecture rtl of piano is

  constant logic_array_size : integer := 2**n_keys_g;
  type logic_array is array (integer range <>)
    of std_logic_vector(n_keys_g - 1 downto 0);
  -- Emulated key presses.
  constant keys_c : logic_array(0 to logic_array_size - 1) := (
    "0000",
    "0001",
    "0010",
    "0011",
    "0100",
    "0101",
    "0110",
    "0111",
    "1000",
    "1001",
    "1010",
    "1011",
    "1100",
    "1101",
    "1110",
    "1111"
    );

  -- Counter maximum for keeping the tone.
  constant counter_max_c : integer :=
    integer(real(clk_freq_g) / tone_change_freq_g);

  -- Counter registers.
  signal keys_index_r : integer range 0 to logic_array_size - 1;
  signal counter_r    : integer range 0 to counter_max_c;


begin

  -- Process to increase counter and then when it is reached. Assign new tone
  -- index.
  counter : process(clk, rst_n)
  begin
    if rst_n = '0' then
      keys_index_r <= 0;
      counter_r    <= 0;

    elsif clk'event and clk = '1' then
      if enable_in = '0' then
        keys_index_r <= 0;
        counter_r    <= 0;
      elsif counter_r /= counter_max_c then
        counter_r <= counter_r + 1;
      else
        counter_r <= 0;
        if keys_index_r /= logic_array_size - 1 then
          keys_index_r <= keys_index_r + 1;
        else
          keys_index_r <= 0;
        end if;
      end if;

    end if;
  end process counter;

  -- Combinational process to assign new tone to the output.
  keys : process(keys_index_r)
  begin
    keys_out <= keys_c(keys_index_r);
  end process keys;

end rtl;
