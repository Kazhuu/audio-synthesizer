-------------------------------------------------------------------------------
-- File       : wave_gen.vhd
-- Created    : 03.12.2017
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description:
-- Sine wave generation block. Range of the output value can be controlled with
-- the width_g parameter and frequency of the sine wave can be controlled with
-- step_g parameter.
--
-- Math used behind this to generate sine wave approximation is found from the
-- wikipedia:
-- https://en.wikipedia.org/wiki/Trigonometric_tables
-- #A_quick.2C_but_inaccurate.2C_approximation
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;


entity wave_gen is
  generic (
    width_g : positive := 16;           -- counter width in bits
    step_g : positive := 256           -- Max value for N
    );
  port (
    rst_n         : in  std_logic;
    clk           : in  std_logic;
    sync_clear_in : in  std_logic;
    -- Counter value out.
    value_out     : out std_logic_vector(width_g - 1 downto 0)
    );
end wave_gen;


architecture rtl of wave_gen is

  -- Constant values to hold counter min and max values.
  -- Values are calculated using formula:
  -- max = 2^(b-1)-1
  -- min = -max
  -- where b is width of the counter.
  constant max_value_c : integer := 2**(width_g - 1) - 1;
  constant min_value_c : integer := -max_value_c;
  -- Middle value where sin wave middle is.
  constant middle_c    : integer := 0;
  -- Scale factor used to calculate sine values without real type.
  constant scale_c     : integer := 1000;
  -- Up scaled value of d of the sine wave approximation equation.
  constant d_phase_c   : integer
    := integer(2.0 * MATH_PI / real(step_g) * real(scale_c));

  -- Function to calculate next sin value based on given sin_base and cos_base.
  -- Returns new value sin value.
  function sn(sin_base, cos_base : integer) return integer is
    variable temp_i : integer;
  begin
    temp_i := ((sin_base * scale_c) + d_phase_c * cos_base) / scale_c;
    if temp_i > max_value_c then
      return max_value_c;
    elsif temp_i < min_value_c then
      return min_value_c;
    else
      return temp_i;
    end if;
  end sn;

  -- Function to calculate next cos value based on given sin_base and cos_base.
  -- Returns new value cos value.
  function cn(sin_base, cos_base : integer) return integer is
    variable temp_i : integer;
  begin
    temp_i := ((cos_base * scale_c) - d_phase_c * sin_base) / scale_c;
    if temp_i > max_value_c then
      return max_value_c;
    elsif temp_i < min_value_c then
      return min_value_c;
    else
      return temp_i;
    end if;
  end cn;

  -- To hold last sin and cos values.
  signal last_sn_r : integer range min_value_c to max_value_c;
  signal last_cn_r : integer range min_value_c to max_value_c;

  -- To hold counter current value.
  signal counter_r : integer range 0 to step_g;

begin

  -----------------------------------------------------------------------------
  -- Synchronous process to calculate the next sin and cos values.
  -----------------------------------------------------------------------------
  next_approximation : process(clk, rst_n)
  begin  -- process next_approximation
    if rst_n = '0' then                 -- asynchronous reset, active low.
      last_sn_r <= middle_c;
      last_cn_r <= max_value_c;

    elsif clk'event and clk = '1' then  -- rising edge of the clock.
      if sync_clear_in = '1' then
        last_sn_r <= middle_c;
        last_cn_r <= max_value_c;
      elsif counter_r /= step_g then
        counter_r <= counter_r + 1;
        last_sn_r <= sn(last_sn_r, last_cn_r);
        last_cn_r <= cn(last_sn_r, last_cn_r);
      else
        counter_r <= 0;
        last_sn_r <= middle_c;
        last_cn_r <= max_value_c;
      end if;

    end if;
  end process next_approximation;

  -- Connect counter register to module output.
  value_out <= std_logic_vector(to_signed(last_sn_r, width_g));

end rtl;
