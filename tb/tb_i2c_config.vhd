-------------------------------------------------------------------------------
-- File       : tb_i2c_config.vhd
-- Created    : 05.02.2018
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description:
-- Test bench to verify i2c_config correct behaviour. Test bench act as a slave
-- device and also generates few nack to test that master starts transmitting
-- data again from the beginning. Test bench verifies that correct
-- configuration values are received.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity tb_i2c_config is
end tb_i2c_config;


architecture testbench of tb_i2c_config is

  -- Number of parameters to expect.
  constant n_params_c       : integer                      := 10;
  constant i2c_freq_c       : integer                      := 20_000;
  constant ref_freq_c       : integer                      := 50_000_000;
  constant clock_period_c   : time                         := 20 ns;
  constant device_address_c : std_logic_vector(6 downto 0) := "0011010";
  constant write_bit_c      : std_logic                    := '0';

  -- Every transmission consists several bytes and every byte contains given
  -- amount of bits.
  constant n_bytes_c       : integer := 3;
  constant bit_count_max_c : integer := 8;

  -- Define array which defines on which succesful transfer cycles test bench
  -- will send nack instead of ack.
  -- Numbers must be in ascending order.
  type int_array is array (integer range <>) of integer;
  constant nack_arr_c : int_array(0 to 2) := (0, 2, 4);

  type byte_array is array(0 to n_params_c - 1) of
    std_logic_vector(bit_count_max_c - 1 downto 0);
  -- Expected register addresses received from the master. Also one LSB bit
  -- is part of the value data.
  constant register_addrs : byte_array := (
    ("00000000"),                       -- 0000 000 Left Line In
    ("00000010"),                       -- 0000 001 Right Line In
    ("00000100"),                       -- 0000 010 Left Headphone Out
    ("00000110"),                       -- 0000 011 Right Headphone Out
    ("00001000"),                       -- 0000 100 Analogue Audio Path Control
    ("00001010"),                       -- 0000 101 Digital Audio Path Control
    ("00001100"),                       -- 0000 110 Power Down Control
    ("00001110"),  -- 0000 111 Digital Audio Interface Format
    ("00010000"),                       -- 0001 000 Sampling Control
    ("00010010")                        -- 0001 001 Active Control
    );

  -- Expected configuration values received from the master.
  constant conf_values : byte_array := (
    ("00011010"),                       -- 0000 000 Left Line In
    ("00011010"),                       -- 0000 001 Right Line In
    ("01111011"),                       -- 0000 010 Left Headphone Out
    ("01111011"),                       -- 0000 011 Right Headphone Out
    ("11111000"),                       -- 0000 100 Analogue Audio Path Control
    ("00000110"),                       -- 0000 101 Digital Audio Path Control
    ("00000000"),                       -- 0000 110 Power Down Control
    ("00000001"),  -- 0000 111 Digital Audio Interface Format
    ("00000010"),                       -- 0001 000 Sampling Control
    ("00000001")                        -- 0001 001 Active Control
    );

  -- Signals fed to the DUV.
  signal clk   : std_logic := '0';
  signal rst_n : std_logic := '0';

  -- The DUV prototype.
  component i2c_config
    generic(
      ref_clk_freq_g    : positive;
      i2c_freq_g        : positive;
      n_params_g        : positive;
      dbg_trans_width_g : positive
      );
    port(
      clk              : in    std_logic;
      rst_n            : in    std_logic;
      sdat_inout       : inout std_logic;
      sclk_out         : out   std_logic;
      param_status_out : out   std_logic_vector(n_params_g - 1 downto 0);
      finished_out     : out   std_logic;
      -- debug interface
      dbg_transfer_out : out   std_logic_vector(dbg_trans_width_g - 1 downto 0)
      );
  end component;

  -- Signals coming from the DUV.
  signal sdat         : std_logic := 'Z';
  signal sclk         : std_logic;
  signal param_status : std_logic_vector(n_params_c - 1 downto 0);
  signal finished     : std_logic;
  signal dbg_transfer : std_logic_vector(bit_count_max_c - 1 downto 0);

  -- To hold the value that will be driven to sdat when sclk is high.
  signal sdat_r : std_logic;

  -- To hold the last value received from DUV.
  signal received_val_r : std_logic_vector(bit_count_max_c - 1 downto 0);

  -- Counters for receiving bits and bytes.
  signal bit_counter_r        : integer range 0 to bit_count_max_c - 1;
  signal byte_counter_r       : integer range 0 to n_bytes_c - 1;
  -- Counter to count succesful byte transfers.
  signal succ_trans_counter_r : integer;
  -- Counter to count how many NACKs are sended to master.
  signal nack_counter_r       : integer range 0 to nack_arr_c'length;
  -- Counter to count completed tranfers without nack.
  signal comp_trans_counter_r : integer;

  -- States for the FSM.
  type states is (wait_start, read_byte, send_ack, wait_stop);
  signal curr_state_r : states;

  -- Previous values of the I2C signals for edge detection.
  signal sdat_old_r : std_logic;
  signal sclk_old_r : std_logic;

begin

  clk   <= not clk after clock_period_c / 2;
  rst_n <= '1'     after clock_period_c * 4;

  -- Assign sdat_r when sclk is active, otherwise 'Z'.
  -- Note that sdat_r is usually 'Z'.
  with sclk select
    sdat <=
    sdat_r when '1',
    'Z'    when others;

  -- Component instantiation.
  i2c_config_1 : i2c_config
    generic map(
      ref_clk_freq_g    => ref_freq_c,
      i2c_freq_g        => i2c_freq_c,
      n_params_g        => n_params_c,
      dbg_trans_width_g => bit_count_max_c)
    port map(
      clk              => clk,
      rst_n            => rst_n,
      sdat_inout       => sdat,
      sclk_out         => sclk,
      param_status_out => param_status,
      finished_out     => finished,
      dbg_transfer_out => dbg_transfer);

  -----------------------------------------------------------------------------
  -- The main process that controls the behavior of the test bench.
  fsm_proc : process(clk, rst_n)
  begin  -- process fsm_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)
      curr_state_r         <= wait_start;
      sdat_old_r           <= '0';
      sclk_old_r           <= '0';
      byte_counter_r       <= 0;
      bit_counter_r        <= 0;
      succ_trans_counter_r <= 0;
      comp_trans_counter_r <= 0;
      sdat_r               <= 'Z';

    elsif clk'event and clk = '1' then  -- rising clock edge
      -- The previous values are required for the edge detection.
      sclk_old_r <= sclk;
      sdat_old_r <= sdat;
      -- Falling edge detection for acknowledge control.
      -- Must be done on the falling edge in order to be stable during
      -- the high period of sclk.
      if sclk = '0' and sclk_old_r = '1' then
        -- If we are supposed to send ack.
        if curr_state_r = send_ack then
          -- If current we are supposed to send nack instead of ack on this
          -- transfer cycle.
          if nack_counter_r /= nack_arr_c'length and
            succ_trans_counter_r /= nack_arr_c(nack_counter_r) then
            -- Send ack, low.
            sdat_r <= '0';

          end if;
        else
          -- Otherwise, sdat is in high impedance state.
          sdat_r <= 'Z';
        end if;
      end if;

      -------------------------------------------------------------------------
      -- FSM
      case curr_state_r is
        -----------------------------------------------------------------------
        -- Wait for the start condition.
        when wait_start =>
          -- While clk stays high, the sdat falls.
          if sclk = '1' and sclk_old_r = '1' and
            sdat_old_r = '1' and sdat = '0' then
            curr_state_r <= read_byte;
          end if;

        -----------------------------------------------------------------------
        -- Wait for a byte to be read.
        when read_byte =>
          -- Detect a rising edge.
          if sclk = '1' and sclk_old_r = '0' then
            if bit_counter_r /= bit_count_max_c - 1 then
              -- Normally just receive a bit.
              received_val_r(bit_count_max_c - bit_counter_r - 1) <= sdat;
              bit_counter_r <= bit_counter_r + 1;
            else
              -- Read last from sdat.
              received_val_r(bit_count_max_c - bit_counter_r - 1) <= sdat;
              -- When terminal count is reached, let's send the ack.
              curr_state_r  <= send_ack;
              bit_counter_r <= 0;
            end if;
          end if;

        -----------------------------------------------------------------------
        -- Send acknowledge.
        when send_ack =>
          -- Detect a rising edge.
          if sclk = '1' and sclk_old_r = '0' then
            -- On this cycle we send nack and master is supposed to send same
            -- values again from start using stop and start conditions.
            if nack_counter_r /= nack_arr_c'length and
              succ_trans_counter_r = nack_arr_c(nack_counter_r) then
              byte_counter_r <= 0;
              sdat_r         <= '1';
              curr_state_r   <= wait_stop;
              nack_counter_r <= nack_counter_r + 1;

            -- Transmission continues.
            elsif byte_counter_r /= n_bytes_c - 1 then
              sdat_r               <= '0';
              succ_trans_counter_r <= succ_trans_counter_r + 1;
              byte_counter_r       <= byte_counter_r + 1;
              curr_state_r         <= read_byte;

              -- Make sure received value is same as expected.
              assert unsigned(dbg_transfer) = unsigned(received_val_r)
                report "received value differs from the expected value"
                severity failure;

              if byte_counter_r = 0 then
                -- Make sure write bit and device address are correct on
                -- first byte.
                assert received_val_r(received_val_r'length - 1 downto 1)
                  = device_address_c
                  report "not expected device address"
                  severity failure;
                -- Make sure master is writing, not reading.
                assert write_bit_c = received_val_r(0)
                  report "master is not writing"
                  severity failure;
              else
                -- Make sure we received expected register address.
                assert signed(register_addrs(comp_trans_counter_r)) =
                  signed(received_val_r)
                  report "not expected register address"
                  severity failure;
              end if;

            -- Transmission is about to stop.
            else
              sdat_r               <= '0';
              byte_counter_r       <= 0;
              comp_trans_counter_r <= comp_trans_counter_r + 1;
              curr_state_r         <= wait_stop;

              -- Make sure we received expected configuration value.
              assert signed(conf_values(comp_trans_counter_r)) =
                signed(received_val_r)
                report "not expected configuration value"
                severity failure;
            end if;
          end if;

        -----------------------------------------------------------------------
        -- Wait for the stop condition.
        when wait_stop =>
          -- Stop condition detection: sdat rises while sclk stays high.
          if sclk = '1' and sclk_old_r = '1' and
            sdat_old_r = '0' and sdat = '1' then
            curr_state_r <= wait_start;
          -- Repeated start condition: sdat falls while sclk stays high.
          elsif sclk = '1' and sclk_old_r = '1' and
            sdat_old_r = '1' and sdat = '0' then
            curr_state_r <= read_byte;
          end if;
      end case;

    end if;
  end process fsm_proc;

  -----------------------------------------------------------------------------
  -- Asserts for verification
  -----------------------------------------------------------------------------

  -- SDAT should never contain X:s.
  assert sdat /= 'X'
    report "three state bus in state X"
    severity error;

  -- End of simulation, but not during the reset.
  assert finished = '0' or rst_n = '0'
    report "simulation done"
    severity failure;

end testbench;
