-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- File       : tb_wave_gen.vhd
-------------------------------------------------------------------------------
-- Description: Stimulus generation for wave generator. NOTE! This does not
--              check the validity of DUV's output signal!
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity tb_wave_gen is

end tb_wave_gen;


architecture testbench of tb_wave_gen is

--  CONSTANT width_c : INTEGER := 6;
  constant width_c : integer := 16;

  -- Set the clk period and total simulation length
  constant period_c       : time := 10 ns;  -- 10 ns = 100 MHz
  constant sim_duration_c : time := 1 ms;

  -- Set the time when generator is cleared synchronously
  constant clear_delay_c    : integer := 74000;
  constant clear_duration_c : integer := 6000;


  -- Signals for the DUV
  signal clk        : std_logic := '0';
  signal rst_n      : std_logic := '0';
  type output_array is array (1 to 4) of std_logic_vector(width_c-1 downto 0);
  signal output     : output_array;
  signal sync_clear : std_logic;

  signal maxim : output_array;
  signal minim : output_array;


  component wave_gen
    generic (
      width_g : integer;
      step_g : integer);
    port (
      rst_n         : in  std_logic;
      clk           : in  std_logic;
      sync_clear_in : in  std_logic;
      value_out     : out std_logic_vector(width_g-1 downto 0));
  end component;

  signal sync_clear_old_r : std_logic;

  constant zero_c : std_logic_vector(width_c-1 downto 0) := (others => '0');

  signal endsim : std_logic := '0';

begin  -- testbench

  clk   <= not clk after period_c/2;
  rst_n <= '1'     after period_c*4;

  -- Create synchronous clear signal
  sync_clear <= '0',
                '1' after period_c*clear_delay_c,
                '0' after period_c*(clear_delay_c+clear_duration_c);

  g_wave_gen : for i in 1 to 4 generate
    i_wave_gen : wave_gen
      generic map (
        width_g => width_c,
        step_g => i * 300
        )
      port map (
        rst_n         => rst_n,
        clk           => clk,
        sync_clear_in => sync_clear,
        value_out     => output(i)
        );

  end generate g_wave_gen;


  sync_test : process (clk, rst_n)
  begin  -- PROCESS sync_test
    if rst_n = '0' then                 -- asynchronous reset (active low)
      maxim            <= (others => (others => '0'));
      minim            <= (others => (others => '0'));
      sync_clear_old_r <= '0';
    elsif clk'event and clk = '1' then  -- rising clock edge
      sync_clear_old_r <= sync_clear;
      for i in 1 to 4 loop
        if signed(output(i)) > signed(maxim(i)) then
          maxim(i) <= output(i);
        end if;
        if signed(output(i)) < signed(minim(i)) then
          minim(i) <= output(i);
        end if;

        assert sync_clear_old_r = '0' or output(i) = zero_c
          report "Sync clear failed" severity error;

      end loop;  -- i

    end if;
  end process sync_test;

  -- Stop the simulation
  endsim <= '1' after sim_duration_c;
  assert endsim = '0' report "Simulation done" severity failure;

end testbench;
