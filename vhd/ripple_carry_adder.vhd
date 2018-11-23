-------------------------------------------------------------------------------
-- File       : ripple_carry_adder.vhd
-- Created    : 18.11.2017
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Ripple carry adder module.
-------------------------------------------------------------------------------

-- Include standard library.
library ieee;
use ieee.std_logic_1164.all;

-- Entity of the ripple carry added.
entity ripple_carry_adder is
  port(
    a_in  : in  std_logic_vector(2 downto 0);
    b_in  : in  std_logic_vector(2 downto 0);
    s_out : out std_logic_vector(3 downto 0)
    );
end ripple_carry_adder;

-- Architecture of the 3-bit ripple carry adder.
architecture gate of ripple_carry_adder is
  signal carry_ha, carry_fa, c, d, e, f, g, h : std_logic;
begin  -- gate
  -- Half added.
  s_out(0) <= a_in(0) xor b_in(0);
  carry_ha <= a_in(0) and b_in(0);
  -- First full adder.
  c        <= a_in(1) xor b_in(1);
  d        <= carry_ha and c;
  e        <= a_in(1) and b_in(1);
  s_out(1) <= c xor carry_ha;
  carry_fa <= d or e;
  -- Last full adder.
  f        <= a_in(2) xor b_in(2);
  g        <= carry_fa and f;
  h        <= a_in(2) and b_in(2);
  s_out(2) <= f xor carry_fa;
  s_out(3) <= g or h;
end gate;
