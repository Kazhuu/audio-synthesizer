-------------------------------------------------------------------------------
-- File       : multi_port_adder.vhd
-- Created    : 26.11.2017
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Multi port generic adder. Added sum_out does not contain a
--              carry bit.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;


entity multi_port_adder is
  generic (
    operand_width_g   : integer := 16;
    num_of_operands_g : integer := 4
    );
  port (
    rst_n        : in  std_logic;
    clk          : in  std_logic;
    operands_in  : in  std_logic_vector(
      (operand_width_g * num_of_operands_g) - 1 downto 0);
    sum_out      : out std_logic_vector(operand_width_g - 1 downto 0);
    overflow_out : out std_logic
    );
end multi_port_adder;


architecture structural of multi_port_adder is

  -- Introduce used adder component.
  component adder
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
  end component;

  -- Own defined array type to hold all subtotals from the first adders.
  -- One subtotal also holds the adder carry bit.
  type subtotal_vector is array (0 to (num_of_operands_g / 2) - 1)
    of std_logic_vector(operand_width_g downto 0);

  -- An array to hold subtotals from each adder component.
  signal subtotals : subtotal_vector;
  -- Total sum of all adder components, also includes the carry bits.
  signal total     : std_logic_vector(operand_width_g + 1 downto 0);

  -- Constant values used to specify adder ranges. With default values:
  -- 64
  constant adder1_a_max_c : integer
    := (operand_width_g * num_of_operands_g);
  -- 48
  constant adder1_b_max_c : integer
    := operand_width_g * (num_of_operands_g - 1);
  -- 32
  constant adder2_a_max_c : integer
    := operand_width_g * (num_of_operands_g - 2);
  -- 16
  constant adder2_b_max_c : integer
    := operand_width_g * (num_of_operands_g - 3);

begin

  -- Assert that num_of_operands_g is equal to 4.
  assert num_of_operands_g = 4
    report "num_of_operands_g needs to be equal to 4"
    severity failure;

  -- Intantiate first adder.
  i_adder_1 : adder
    generic map (
      operand_width_g => operand_width_g
      )
    port map (
      clk     => clk,
      rst_n   => rst_n,
      -- First two higer operand widths (63 - 32).
      a_in    => operands_in(adder1_a_max_c - 1 downto adder1_b_max_c),
      b_in    => operands_in(adder1_b_max_c - 1 downto adder2_a_max_c),
      sum_out => subtotals(0)
      );
  -- Intantiate second adder.
  i_adder_2 : adder
    generic map (
      operand_width_g => operand_width_g
      )
    port map (
      clk     => clk,
      rst_n   => rst_n,
      -- Last two lower operand widths (31 - 0).
      a_in    => operands_in(adder2_a_max_c - 1 downto adder2_b_max_c),
      b_in    => operands_in(adder2_b_max_c -1 downto 0),
      sum_out => subtotals(1)
      );
  -- Intantiate last adder.
  i_adder_3 : adder
    generic map (
      operand_width_g => operand_width_g + 1
      )
    port map (
      clk     => clk,
      rst_n   => rst_n,
      -- Two subtotals from first two adders.
      a_in    => subtotals(0),
      b_in    => subtotals(1),
      sum_out => total
      );

  -- Connect added total to sum_out, not connecting two MSBs.
  sum_out      <= total(operand_width_g - 1 downto 0);
  -- Overflow happens when operand_width_g last bit differs from the sign bit.
  overflow_out <= '1' when total(operand_width_g) /= total(operand_width_g - 1)
                  else '0';

end structural;
