-------------------------------------------------------------------------------
-- File       : tb_ripple_carry_adder.vhd
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Tests all combinations of summing two 3-bit values
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.all;

entity tb_ripple_carry_adder is
end tb_ripple_carry_adder;


architecture testbench of tb_ripple_carry_adder is


  -- Define constants: bit widths and duration of clk period
  constant input_w_c    : integer := 3;
  constant output_w_c   : integer := 4;
  constant clk_period_c : time    := 100 ns;

  -- Component declaration of  Design Under Verification (DUV)
  component ripple_carry_adder
    port (
      a_in  : in  std_logic_vector(2 downto 0);
      b_in  : in  std_logic_vector(2 downto 0);
      s_out : out std_logic_vector(3 downto 0));
  end component;

  -- Define the needed signals
  signal clk     : std_logic := '0';
  signal rst_n   : std_logic := '0';
  signal term1_r : unsigned(input_w_c-1 downto 0);
  signal term2_r : unsigned(input_w_c-1 downto 0);

  signal sum     : unsigned(output_w_c-1 downto 0);
  signal sum_slv : std_logic_vector(output_w_c-1 downto 0);

begin  -- testbench

  i_ripple_carry_adder : ripple_carry_adder
    port map (
      a_in  => std_logic_vector(term1_r),
      b_in  => std_logic_vector(term2_r),
      s_out => sum_slv);
  sum <= unsigned(sum_slv);


  -- Generate rst signals to initialize registers
  rst_n <= '1' after clk_period_c*2;

  -- purpose: Generate clock signal for DUV
  -- type   : combinational
  -- inputs : clk (this is a special case for test purposes!)
  -- outputs: clk
  clk_gen : process (clk)
  begin  -- process clk_gen
    clk <= not clk after clk_period_c/2;
  end process clk_gen;



  -- purpose: Generate all possible inputs values and check the result
  -- type   : sequential
  -- inputs : clk, rst_n
  -- outputs: term1_r, term2_r
  input_gen_output_check : process (clk, rst_n)
  begin  -- process input_gen_output_check
    if rst_n = '0' then                 -- asynchronous reset (active low)

      -- Reset all registers here
      term1_r <= (others => '0');
      term2_r <= (others => '0');

    elsif clk'event and clk = '1' then  -- rising clock edge

      -- Increment term1 on every clock cycle (else-branch)
      -- Increment also term2 when term1 has max value (if-branch)
      -- Simulation terminates when term2 has max value
      if (to_integer(term1_r) = 2**input_w_c-1) then
        term1_r <= (others => '0');
        if (term2_r = 2**input_w_c-1) then
          assert false report "Simulation ended!" severity failure;
        else
          term2_r <= to_unsigned(to_integer(term2_r) + 1, input_w_c);
        end if;
      else
        term1_r <= to_unsigned(to_integer(term1_r) + 1, input_w_c);
      end if;

      -- Check the result. This condition should always be true. If not, the report message will be printed.
      assert to_integer(sum) = to_integer(term1_r) + to_integer(term2_r)
        report "Output signal is not equal to the sum of the inputs"
        severity error;

    end if;
  end process input_gen_output_check;

end testbench;
