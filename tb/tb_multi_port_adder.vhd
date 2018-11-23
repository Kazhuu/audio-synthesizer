-------------------------------------------------------------------------------
-- File       : tb_multi_port_adder.vhd
-- Created    : 30.11.2017
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Test bech for multi_port_adder entity. Uses separate files
-- for input, output and expected results. Test bench uses shift register to
-- synchronies input read and checker processes.
--
-- Input and reference files can be found under /workspace/sim/files/ folder.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_multi_port_adder is
  generic (
    operand_width_g : integer := 16
    );
end entity;

architecture testbench of tb_multi_port_adder is

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

  -- Define test bech constants.
  -- Period of one clock cycle.
  constant clk_period_c      : time    := 10 ns;
  -- Number of bits per one operand.
  constant num_of_operands_c : integer := 4;
  -- DUV delay from input to output.
  constant duv_delay_c       : integer := 2;

  -- Signal definitions for a test bench with inital values. Note that
  -- initial values are only supported in simulation.
  -- Clock signal.
  signal clk   : std_logic := '0';
  -- Reset signal.
  signal rst_n : std_logic := '0';
  -- Register which contains operands feeded in to DUV.
  signal operands_r :
    std_logic_vector((num_of_operands_c * operand_width_g) - 1 downto 0);
  -- Signal to hold result from output of DUV.
  signal sum            : std_logic_vector(operand_width_g - 1 downto 0);
  -- Signal to hold overflow value from the multi_port_adder.
  signal overflow_r     : std_logic;
  -- Shift register to hold DUV output values and compensate happening delay.
  signal output_valid_r : std_logic_vector(duv_delay_c downto 0);

  -- Filenames used by the test bench, note VHDL'93 syntax.
  file input_f : text
    open read_mode is "files/tb_multi_port_adder_input.txt";
  file ref_result_f : text
    open read_mode is "files/tb_multi_port_adder_ref_result.txt";
  file output_f : text
    open write_mode is "files/tb_multi_port_adder_output.txt";

begin

  -----------------------------------------------------------------------------
  -- Purpose: Process to generate the clock signal.
  -----------------------------------------------------------------------------
  clk_gen : process (clk)
  begin  -- process clk_gen
    clk <= not clk after clk_period_c / 2;
  end process clk_gen;

  -- Set reset to '1' after four clock cycles.
  rst_n <= '1' after clk_period_c * 4;

  -- Instantiate the multi_port_adder component and connect the signals.
  i_multi_port_adder_1 : multi_port_adder
    generic map (
      operand_width_g   => operand_width_g,
      num_of_operands_g => num_of_operands_c
      )
    port map (
      rst_n        => rst_n,
      clk          => clk,
      operands_in  => operands_r,
      sum_out      => sum,
      overflow_out => overflow_r
      );

  -----------------------------------------------------------------------------
  -- Purpose: Read input from input file and assing values to DUV operands_r
  -- input. Process is synched using shift register output_valid_r with checker
  -- process. DUV uses two clock cycles to do the calculation.
  -----------------------------------------------------------------------------
  input_reader : process (clk, rst_n)
    variable input_line_v    : line;
    -- Four integers per line.
    type line_integers is array (0 to num_of_operands_c - 1) of integer;
    variable line_integers_v : line_integers;
    -- Help variables to hold ranges for operands_r register.
    variable max_v           : integer;
    variable min_v           : integer;
  begin  -- process input_reader
    if rst_n = '0' then                 -- Asyncronous reset, active low.
      operands_r      <= (others => '0');
      output_valid_r  <= (others => '0');
      line_integers_v := (others => 0);
      max_v           := 0;
      min_v           := 0;
    elsif clk'event and clk = '1' then  -- Rising edge of the clock.
      -- Check if end of file is reached and checker process has run.
      if not endfile(input_f) and to_integer(signed(output_valid_r)) = 0 then
        -- Shift output_valid_r register to left and assign LSB to '1'.
        output_valid_r(duv_delay_c downto 1)
          <= output_valid_r(duv_delay_c - 1 downto 0);
        output_valid_r(0) <= '1';
        -- Read one line.
        readline(input_f, input_line_v);
        -- Read four integers from a single line.
        for i in 0 to line_integers_v'length - 1 loop
          read(input_line_v, line_integers_v(i));
        end loop;
        -- Assign four integers to operand_r register, input to DUV.
        -- i = 0, 2 downto 0
        -- i = 1, 5 downto 3
        -- i = 2, 8 downto 6 and so on.
        for i in 0 to line_integers_v'length - 1 loop
          max_v := (operand_width_g * i) + operand_width_g - 1;
          min_v := operand_width_g * i;
          operands_r(max_v downto min_v)
            <= std_logic_vector(to_signed(line_integers_v(i), operand_width_g));
        end loop;
      else
        -- Shift output_valid_r register to left and assign LSB to '0'.
        output_valid_r(duv_delay_c downto 1)
          <= output_valid_r(duv_delay_c - 1 downto 0);
        output_valid_r(0) <= '0';
      end if;
    end if;
  end process input_reader;

  -----------------------------------------------------------------------------
  -- Purpose: Check result file input and assert that it matches with output
  -- of the multi_port_adder. Start assertion when MSB of shift register
  -- output_valid_r is '1'. Also write sum output to output_f file.
  -----------------------------------------------------------------------------
  checker : process(clk, rst_n)
    variable input_line_v  : line;
    variable output_line_v : line;
    variable ref_value_v   : integer;
  begin  -- process checker
    if rst_n = '0' then
      ref_value_v := 0;
    elsif clk'event and clk = '1' then
      -- Check for the end of result file.
      if not endfile(ref_result_f) then
        -- Check that MSB is one, then we can start checking for the results.
        if output_valid_r(output_valid_r'length - 1) = '1' then
          readline(ref_result_f, input_line_v);
          read(input_line_v, ref_value_v);
          assert ref_value_v = to_integer(signed(sum))
            report "sum is not equal to value from reference input file"
            severity failure;
          -- Write the actual result to output_f file.
          write(output_line_v, to_integer(signed(sum)));
          writeline(output_f, output_line_v);
        end if;
      else
        -- End of result file is reached, end simulation.
        assert false
          report "end of ref file reached, simulation ended"
          severity failure;
      end if;
    end if;
  end process checker;

end architecture;
