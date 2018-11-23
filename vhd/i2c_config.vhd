-------------------------------------------------------------------------------
-- File       : i2c_config.vhd
-- Created    : 05.02.2018
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description:
-- Block configures Wolfson WM8731 audio codec using it's i2c software
-- interface. Codec needs three different values for one register
-- configuration. After each succesful configuration corresponding bit in
-- param_status_out output is set high. When all registers are configured,
-- then finished_out is set high.
--
-- Block also contains dbg_transfer_out output, which is used to output
-- currently transfered dbg_trans_width_g length value. This output is
-- supposed to be used for debugging purposes only.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;


entity i2c_config is
  generic(
    ref_clk_freq_g    : positive := 50_000_000;  -- frequency of clk-signal
    i2c_freq_g        : positive := 20_000;  -- i2c-bus (sclk_out) frequency
    n_params_g        : positive := 10;  -- number of configuration parameters
    -- debug generics
    dbg_trans_width_g : positive := 8   -- bit width of debug line
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
end i2c_config;


architecture rtl of i2c_config is

  constant conf_value_len : integer := 9;
  -- Array holding configuration register values. Each register has 9 bits.
  -- Register address is 7 bits and can be calculated adding one after writing.
  -- On second byte transfer first bit is 9th bit of the conf value. On third
  -- transfer last 8 bits are transfered.
  -- Example write to Left Headphone Out register:
  -- (dev addr) (reg addr)  (reg value)
  -- (00110100) (0000 0100) (0111 1011)
  type conf_array is array(0 to n_params_g - 1) of
    std_logic_vector(conf_value_len - 1 downto 0);
  constant conf_values : conf_array := (
    -- register values : register address
    ("000011010"),  -- 0000 000 Left Line In
    ("000011010"),  -- 0000 001 Right Line In
    ("001111011"),  -- 0000 010 Left Headphone Out
    ("001111011"),  -- 0000 011 Right Headphone Out
    ("011111000"),  -- 0000 100 Analogue Audio Path Control
    ("000000110"),  -- 0000 101 Digital Audio Path Control
    ("000000000"),  -- 0000 110 Power Down Control
    ("000000001"),  -- 0000 111 Digital Audio Interface Format
    ("000000010"),  -- 0001 000 Sampling Control
    ("000000001")   -- 0001 001 Active Control
    );

  -- Acknowledge (ACK) bit constant.
  constant ack_c       : std_logic := '0';
  -- Not acknowledge (NACK) bit constant.
  constant nack_c      : std_logic := '1';
  -- Master write bit constant.
  constant write_bit_c : std_logic := '0';

  -- How many bytes we transfer between start and stop.
  constant bytes_count_c      : integer                      := 3;
  -- How many bits is transfered between each acknowledge.
  constant transfer_bit_len_c : integer                      := 8;
  -- Address of the Wolfson audio codec.
  constant codec_address_c    : std_logic_vector(6 downto 0) := "0011010";

  -- Minimum time needed for all setup and hold times for i2c.
  constant min_time_us_c      : real := 6.0;
  -- Maxmimum time to hold sdat after falling edge of the sclk.
  -- Signal transition time (1000 ns) is decreased from the original 3.45 us
  -- time from i2c specification.
  constant data_hold_max_us_c : real := 2.35;
  constant clk_period_us_c    : real
    := 1.0 / real(ref_clk_freq_g) * 1_000_000.0;
  constant sclk_period_us_c : real := 1.0 / real(i2c_freq_g) * 1_000_000.0;

  -- Counter maximums.
  constant sclk_counter_max_c     : integer := ref_clk_freq_g / i2c_freq_g / 2;
  constant min_time_counter_max_c : integer
    := integer(ceil(min_time_us_c / clk_period_us_c));
  -- How many sclk edges we pass during bus_free state before moving to start
  -- state.
  constant bus_free_edge_count_c : integer := 2;
  -- Counter how long sdat is held at z when it's needed.
  constant sdat_hold_counter_max_c : integer := sclk_counter_max_c;

  -- Counter registers.
  signal sclk_counter_r  : integer;
  signal sdat_counter_r  : integer;
  signal sdat_curr_max_r : integer;

  -- States of the FSM.
  type states is (start, r_start, transmit, acknowledge, stop, bus_free, final);
  -- Register to hold current state.
  signal curr_state_r : states;

  -- Register to hold currently transfered byte.
  signal transfer_r     : std_logic_vector(transfer_bit_len_c - 1 downto 0);
  -- Register to hold how many config values we have transfered.
  signal config_index_r : integer;
  -- Register to hold how many bytes we have transfered.
  signal byte_index_r   : integer;
  -- Register to hold how many bits we have transfeted.
  signal bit_index_r    : integer;
  -- Register to hold current edge counter value used by bus_free state.
  signal edge_counter_r : integer;
  -- If '1' then z value is held until counter is reached.
  signal hold_z_r            : std_logic;
  -- Current counter value for holding sdat signal.
  signal sdat_hold_counter_r : integer;
  -- Register to hold last clk cycle sclk value.
  signal old_sclk_r          : std_logic;

  -- Registers to hold output values.
  signal sclk_r         : std_logic;
  signal param_status_r : std_logic_vector(n_params_g - 1 downto 0);

begin

  -----------------------------------------------------------------------------
  -- Process to control the fsm.
  -----------------------------------------------------------------------------
  fsm : process(clk, rst_n)
  begin
    if rst_n = '0' then                 -- asynchronous reset (active low)
      param_status_r      <= (others => '0');
      curr_state_r        <= start;
      sdat_counter_r      <= 0;
      sdat_curr_max_r     <= sclk_counter_max_c / 2;
      sdat_inout          <= '1';
      transfer_r          <= codec_address_c & write_bit_c;
      config_index_r      <= 0;
      byte_index_r        <= 0;
      bit_index_r         <= transfer_bit_len_c - 1;
      old_sclk_r          <= '0';
      edge_counter_r      <= 0;
      sdat_hold_counter_r <= 0;
      hold_z_r            <= '0';

    elsif clk'event and clk = '1' then  -- rising clock edge

      -- Save sclk value.
      old_sclk_r <= sclk_r;

      -- Increase sdat counter on it's own.
      if sdat_counter_r /= sdat_curr_max_r then
        sdat_counter_r <= sdat_counter_r + 1;
      else
        sdat_counter_r <= 0;
      end if;

      case curr_state_r is
        -- Generate start condition.
        when start =>
          -- Set sdat to low after certain time.
          if sdat_counter_r = sdat_curr_max_r then
            sdat_inout <= '0';
          end if;

          -- On falling edge of the sclk start transmitting bits.
          if old_sclk_r = '1' and sclk_r = '0' then
            curr_state_r <= transmit;
            sdat_inout   <= transfer_r(bit_index_r);
            bit_index_r  <= bit_index_r - 1;
          end if;

        -- Repeated start condition. Just for testing purposes and not used.
        when r_start =>
          curr_state_r <= stop;
          -- Hold sdat in Z state for the counter cycles. After that assign new
          -- value to it.
          -- if hold_z_r = '1' then
          --   if sdat_hold_counter_r /= sdat_hold_counter_max_c then
          --     sdat_hold_counter_r <= sdat_hold_counter_r + 1;
          --   else
          --     hold_z_r            <= '0';
          --     sdat_hold_counter_r <= 0;
          --     sdat_inout          <= '1';
          --     sdat_curr_max_r <= sclk_counter_max_c / 4;
          --     sdat_counter_r <= 0;
          --   end if;
          -- end if;
          --
          -- if sdat_counter_r = sdat_curr_max_r then
          --   sdat_inout <= '0';
          --   curr_state_r <= transmit;
          -- end if;


        -- Transmit one byte of data.
        when transmit =>
          -- Hold sdat in Z state for the counter cycles. After that assign new
          -- value to it.
          if hold_z_r = '1' then
            if sdat_hold_counter_r /= sdat_hold_counter_max_c then
              sdat_hold_counter_r <= sdat_hold_counter_r + 1;
            else
              hold_z_r            <= '0';
              sdat_hold_counter_r <= 0;
              sdat_inout          <= transfer_r(bit_index_r);
              bit_index_r         <= bit_index_r - 1;
            end if;

          -- On falling edge of the sclk output new bit to sdat.
          elsif old_sclk_r = '1' and sclk_r = '0' and bit_index_r /= -1 then
            sdat_inout  <= transfer_r(bit_index_r);
            bit_index_r <= bit_index_r - 1;

          -- On falling edge of the sclk and last bit to transfer, start
          -- waiting for the ack signal from slave.
          elsif bit_index_r = -1 and old_sclk_r = '1' and sclk_r = '0' then
            bit_index_r <= transfer_bit_len_c - 1;
            sdat_curr_max_r <=
              (sclk_counter_max_c / 2) + sclk_counter_max_c - 1;
            sdat_counter_r <= 0;
            -- Set sdat to Z to wait for slave acknowledge.
            sdat_inout     <= 'Z';
            curr_state_r   <= acknowledge;
          end if;

        -- Wait for acknowledge from the receiver. If it is received, send next
        -- byte. If not, resend bytes from beginning.
        when acknowledge =>
          if sdat_counter_r = sdat_curr_max_r then
            -- Next state needs to hold sdat in Z state for a while.
            hold_z_r <= '1';
            -- ACK received.
            if sdat_inout = ack_c then
              -- Transfer different value depending on how many values we have
              -- succesfully transfered so far.
              case byte_index_r is
                -- Device address.
                when 0 =>
                  transfer_r <= std_logic_vector(
                    to_signed(config_index_r, transfer_r'length - 1))
                    & conf_values(config_index_r)(conf_value_len - 1);
                  byte_index_r <= byte_index_r + 1;
                  curr_state_r <= transmit;

                -- Register address and also LSB bit containing part of the
                -- configuration value.
                when 1 =>
                  transfer_r <=
                    conf_values(config_index_r)(conf_value_len - 2 downto 0);
                  byte_index_r <= byte_index_r + 1;
                  curr_state_r <= transmit;

                -- Final byte to transfer. Move to generate stop condition.
                when others =>
                  param_status_r(config_index_r) <= '1';
                  config_index_r <= config_index_r + 1;
                  byte_index_r   <= 0;
                  transfer_r     <= codec_address_c & write_bit_c;
                  curr_state_r   <= stop;
              end case;

            -- NACK received, go to stop state and transfer bytes again.
            else
              byte_index_r <= 0;
              transfer_r   <= codec_address_c & write_bit_c;
              curr_state_r <= stop;
            end if;

          end if;

        -- Generate stop condition and go to bus_free state if all config
        -- values are not transfered yet. Otherwise go to final state.
        when stop =>
          -- Hold sdat in Z state for the counter cycles. After that assign new
          -- value to it.
          if hold_z_r = '1' then
            if sdat_hold_counter_r /= sdat_hold_counter_max_c then
              sdat_hold_counter_r <= sdat_hold_counter_r + 1;
            else
              hold_z_r            <= '0';
              sdat_hold_counter_r <= 0;
              sdat_inout          <= '0';
              sdat_curr_max_r <=
                sclk_counter_max_c + (sclk_counter_max_c / 2) - 1;
              sdat_counter_r <= 0;
            end if;
          end if;

          -- After certain time rise sdat to finish stop condition.
          -- sclk is already up before this time.
          if sdat_counter_r = sdat_curr_max_r then
            sdat_inout <= '1';
            -- If we still need to transfer values, go to bus_free state.
            -- Ohterwise to final state and stop transfering.
            if config_index_r /= n_params_g then
              curr_state_r <= bus_free;
            else
              curr_state_r <= final;
            end if;
          end if;

        -- State when bus is considered to be free. After certain time go to
        -- start condition to start new transmit.
        when bus_free =>
          -- Idle few sclk edges before moving on.
          if sclk_counter_r = sclk_counter_max_c then
            edge_counter_r <= edge_counter_r + 1;

          -- When edge counter is reached. Go to start condition and start
          -- transmitting again.
          elsif edge_counter_r = 2 then
            edge_counter_r  <= 0;
            sdat_curr_max_r <= sclk_counter_max_c / 2;
            sdat_counter_r  <= 1;
            curr_state_r    <= start;
          end if;

        -- Final state when all config values are succesfully transfered.
        -- sdat line is pulled high to end transmission.
        when final =>
          sdat_inout <= '1';

      end case;

    end if;
  end process fsm;


  -----------------------------------------------------------------------------
  -- Process to generate sclk output. Counter is increased on every rising edge
  -- of the clock, but during the bus_free of final state sclk_r is not
  -- updated.
  -----------------------------------------------------------------------------
  sclk_gen : process(clk, rst_n)
  begin
    if rst_n = '0' then                 -- asynchronous reset (active low)
      sclk_counter_r <= 0;
      sclk_r         <= '1';

    elsif clk'event and clk = '1' then  -- rising clock edge
      if sclk_counter_r /= sclk_counter_max_c then
        sclk_counter_r <= sclk_counter_r + 1;
      else
        sclk_counter_r <= 0;
        -- sclk_r is not updated when current state is bus_free or final.
        if curr_state_r /= final and curr_state_r /= bus_free then
          if sclk_r = '1' then
            sclk_r <= '0';
          else
            sclk_r <= '1';
          end if;
        else
          sclk_r <= '1';
        end if;
      end if;

    end if;
  end process sclk_gen;


  -----------------------------------------------------------------------------
  -- Combinatorial process to update debug output when transfer_r register
  -- changes.
  -----------------------------------------------------------------------------
  dbg_output : process(transfer_r)
  begin
    dbg_transfer_out <= transfer_r(dbg_trans_width_g - 1 downto 0);
  end process dbg_output;


  -- Connect inner registers to the outputs.
  sclk_out         <= sclk_r;
  param_status_out <= param_status_r;
  finished_out     <= param_status_r(n_params_g - 1);


  -----------------------------------------------------------------------------
  -- Asserts for verification
  -----------------------------------------------------------------------------

  -- Assert given i2c_freq_g is in allowed range.
  assert i2c_freq_g <= 100_000 and i2c_freq_g < ref_clk_freq_g
    report "i2c_freq_g must be between ref_clk_freq_g and 100 kHz"
    severity failure;

  -- Maximum data hold time is 3.45 us according to i2c specification. Make
  -- sure given ref_clk_freq_g period is smaller than this maximum, so we can
  -- release sdat line before maximum time has passed.
  assert clk_period_us_c < data_hold_max_us_c
    report "ref_clk_freq_g is too low to keep maximum i2c time constraint"
    severity failure;

  -- Assert that i2c_freq_g is low enough to avoid all i2c timing constraints.
  assert sclk_period_us_c / 4.0 >= min_time_us_c
    report "i2c_freq_g is too high to keep i2c timing constraints"
    severity failure;

  -- Check that given dbg_trans_width_g is inside of transfer_bit_len_c.
  -- We want to avoid index out of bound errors.
  assert transfer_bit_len_c <= dbg_trans_width_g
    report "dbg_trans_width_g cannot be larger than transfer_bit_len_c"
    severity failure;

end rtl;
