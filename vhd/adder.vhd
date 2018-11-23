-------------------------------------------------------------------------------
-- File       : adder.vhd
-- Created    : 21.11.2017
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Generic synchronous adder module.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adder is
  generic (
    operand_width_g : integer
    );
  port (
    rst_n   : in  std_logic;
    clk     : in  std_logic;
    a_in    : in  std_logic_vector(operand_width_g - 1 downto 0);
    b_in    : in  std_logic_vector(operand_width_g - 1 downto 0);
    sum_out : out std_logic_vector(operand_width_g downto 0)
    );
end adder;

architecture rtl of adder is

  -- Sum result.
  signal result_r : signed(operand_width_g downto 0);

begin  -- rtl

  -- Added result to output with type casting.
  sum_out <= std_logic_vector(result_r);

  -----------------------------------------------------------------------------
  -- purpose: Synchronous process for calculating the sum.
  -- type   : Sequential
  -- inputs : clk, rst_n
  -- outputs: result_r
  -----------------------------------------------------------------------------
  sum : process (clk, rst_n)
  begin  -- process sum
    if (rst_n = '0') then                 -- Asyncronous reset, active low.
      result_r <= (others => '0');
    elsif (clk'event and clk = '1') then  -- Rising edge of the clock.
      result_r <= resize(signed(a_in), operand_width_g + 1) + 
                  resize(signed(b_in), operand_width_g + 1);
    end if;
  end process sum;

end rtl;
