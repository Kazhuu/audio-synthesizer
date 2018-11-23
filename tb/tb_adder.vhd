-------------------------------------------------------------------------------
-- File       : tb_adder.vhd
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Tests all combinations of summing two 8-bit values
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_adder is
end tb_adder;


architecture testbench of tb_adder is

  -- Define constants: bit widths and duration of clk period
  constant input_w_c    : integer := 8;
  constant output_w_c   : integer := 9;
  constant clk_period_c : time    := 100 ns;

  -- Calculate minimum and maximum values of input values
  -- Note the asymmetrical value range
  constant min_value_c : signed(input_w_c-1 downto 0) := to_signed( -(2**(input_w_c-1)), input_w_c);
  constant max_value_c : signed(input_w_c-1 downto 0) := to_signed( 2**(input_w_c-1)-1, input_w_c);


  -- Component declaration of DUV
  component adder
    generic (
      operand_width_g :     integer
      );
    port (
      clk             : in  std_logic;
      rst_n           : in  std_logic;
      a_in            : in  std_logic_vector(operand_width_g-1 downto 0);
      b_in            : in  std_logic_vector(operand_width_g-1 downto 0);
      sum_out         : out std_logic_vector(operand_width_g downto 0));
  end component;


  -- Define the needed signals
  signal clk   : std_logic := '0';
  signal rst_n : std_logic := '0';
  -- Note: Init values are not supported in synthesis

  signal term1_r : signed(input_w_c-1 downto 0);
  signal term2_r : signed(input_w_c-1 downto 0);

  signal sum              : std_logic_vector(output_w_c-1 downto 0);
  signal expected_sum_r   : signed(output_w_c-1 downto 0);
  signal end_simulation_r : std_logic;



begin  -- testbench

  -- Instantiate DUV and connect the ports to testbench's signals
  adder_1 : adder
    generic map (
      operand_width_g => input_w_c)
    port map (
      clk             => clk,
      rst_n           => rst_n,
      a_in            => std_logic_vector(term1_r),
      b_in            => std_logic_vector(term2_r),
      sum_out         => sum);


  -- Reset the DUV
  rst_n <= '1' after clk_period_c*2;

  -- purpose: Generate clock signal for DUV
  -- type   : combinational
  -- inputs : clk  (this is a special case for test purposes!)
  -- outputs: clk  (this is a special case for test purposes!)
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

      term1_r          <= min_value_c;
      term2_r          <= min_value_c;
      expected_sum_r   <= (others => '0');
      end_simulation_r <= '0';

    elsif clk'event and clk = '1' then  -- rising clock edge
      -- Similar behavior as in tb_ripple_carry_adder but more elegant

      -- Generate input values
      if ( term1_r = max_value_c ) then
        term1_r            <= min_value_c;
        if ( term2_r = max_value_c ) then
          term2_r          <= min_value_c;
          end_simulation_r <= '1';
        else
          term2_r <= term2_r + to_signed(1, input_w_c);
        end if;
      else
          term1_r <= term1_r + to_signed(1, input_w_c);
      end if;


      -- Check the result
      expected_sum_r <= resize(term1_r, output_w_c) +
                        resize(term2_r, output_w_c);
      assert to_integer(signed(sum)) = to_integer(expected_sum_r)
        report "output signal is not equal to the sum of the inputs"
        severity failure;


      -- Stop the simulator
      assert end_simulation_r = '0'
        report "Simulation ended!" severity failure;

    end if;
  end process input_gen_output_check;



end testbench;
