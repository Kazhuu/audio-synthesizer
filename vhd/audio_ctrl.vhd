-------------------------------------------------------------------------------
-- File       : audio_ctrl.vhd
-- Created    : 06.01.2018
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description:
-- Wolfson WM8731 audio codec controller. Controller takes a snapshot from left
-- and right data on beginning of each sample cycle and feeds that data out to
-- aud_data_out according to the specification of Wolfson audio codec. WM8731
-- is expected to be configured to run in left justified slave mode. Main clock,
-- data bit width and sample rate can be configured.
--
-- Controller generates two different kind of clock signals to aud_bclk_out and
-- aud_lrclk_out, which are clocked using the provided clk signal.
--
-- Connections to Wolfson WM8731 audio codec:
-- aud_bclk_out -> BCLK (bit clock)
-- aud_data_out -> DACDAT (digital-to-analog converter data)
-- aud_lrclk_out -> DACLRC (digital-to-analog converter left-right clock)
--
-- During the first clock cycle after reseting, controller idles cycles to
-- produce even clock frequency which can be divided easily to produce
-- configured sample rate for the audio codec. Idling does not take place if
-- clock frequency can be divided with the sampling rate without rounding.
-- For example with 18.432 MHz/48 kfs, one sample rate takes 384 main clock
-- cycles.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;


entity audio_ctrl is
  generic(
    ref_clk_freq_g : integer := 18_432_000;  -- 18.432 MHz
    sample_rate_g  : integer := 48_000;      -- 48 kHz
    data_width_g   : integer := 16           -- 8, 16, 32
    );
  port(
    rst_n         : in  std_logic;
    clk           : in  std_logic;
    left_data_in  : in  std_logic_vector(data_width_g - 1 downto 0);
    right_data_in : in  std_logic_vector(data_width_g - 1 downto 0);
    aud_bclk_out  : out std_logic;           -- audio bit clock output
    aud_data_out  : out std_logic;           -- data output
    aud_lrclk_out : out std_logic            -- left-right clock output
    );
end audio_ctrl;


architecture rtl of audio_ctrl is

  -- Constants related DACLRC counters:
  -- Amount of clock cycles to skip in order to get the right sample_rate_g.
  constant residue_ref_clk_freg_c : integer
    := ref_clk_freq_g mod sample_rate_g;
  -- Frequency used to calculate counter values without decimals.
  constant mod_ref_clk_freq_c : integer
    := ref_clk_freq_g - residue_ref_clk_freg_c;
  -- Counter maximum when lrclk_r is high.
  constant lrclk_high_counter_max_c : integer
    := (mod_ref_clk_freq_c / sample_rate_g / 2) - 1;
  -- Counter maximum when lrclk_r is low.
  constant lrclk_low_counter_max_c : integer
    := integer(ceil(real(mod_ref_clk_freq_c) / real(sample_rate_g) / 2.0)) - 1;

  -- Constants related BCLK counters:
  -- Maximum bits possible.
  constant max_bits_c         : integer := 32;
  -- BCLK frequency with maximum 32 bits, 64 total within one sample.
  constant bclk_freq_c        : integer := sample_rate_g * 64;
  -- Counter maximum value.
  constant bclk_counter_max_c : integer
    := (mod_ref_clk_freq_c / bclk_freq_c / 2) - 1;
  -- End bit transfering after this many main clock (clk) rising edges.
  constant end_transfer_value : integer
    := ((bclk_counter_max_c + 1) * (data_width_g - 1) * 2) + bclk_counter_max_c;

  -- Signals first clock cycle for lrclk counter after reseting.
  signal lrclk_first_cycle : std_logic;
  -- Current maximum for lrclk_counter_r counter.
  signal lrclk_counter_max : integer;
  -- DACLRC counter value register.
  signal lrclk_counter_r   : integer;
  -- DACLRC signal register.
  signal lrclk_r           : std_logic;

  -- Signals first clock cycle for bclk counter after reseting.
  signal bclk_first_cycle : std_logic;
  -- BCLK counter value register.
  signal bclk_counter_r   : integer;
  -- BCLK signal register.
  signal bclk_r           : std_logic;
  -- Currently transfered bit index (0 to data_width_g).
  signal bit_counter_r    : integer;

  -- Signals first clock cycle for bit transfering after reseting.
  signal transfer_bits_first_cycle : std_logic;
  -- DACDAT signal register.
  signal aud_data_r                : std_logic;

  -- Left audio data input sample register.
  signal left_data_r  : std_logic_vector(data_width_g - 1 downto 0);
  -- Right audio data input sample register.
  signal right_data_r : std_logic_vector(data_width_g - 1 downto 0);

begin

  -----------------------------------------------------------------------------
  -- Process to increment and update lrclk counter. Process also changes
  -- counter maximum value to produce wanted sampling rates.
  -- type   : synchronous
  -- inputs : clk, rst_n
  -- outputs: lrclk_counter_max, lrclk_counter_r, lrclk_r, lrclk_first_cycle
  -----------------------------------------------------------------------------
  lrclk_counter : process(clk, rst_n)
  begin
    if rst_n = '0' then                 -- asynchronous reset, active low.
      -- Set counter value to first count the residue cycles to match wanted
      -- sample rate.
      if residue_ref_clk_freg_c = 0 then
        lrclk_counter_max <= lrclk_high_counter_max_c;
      else
        lrclk_counter_max <= residue_ref_clk_freg_c - 1;
      end if;
      lrclk_counter_r   <= 0;
      lrclk_r           <= '0';
      lrclk_first_cycle <= '1';

    elsif clk'event and clk = '1' then  -- rising edge of the clock.

      -- Assign lrclk_r register directly during the first cycle after reset.
      -- Need to avoid counter delays.
      if lrclk_first_cycle = '1' then
        lrclk_r           <= '1';
        lrclk_first_cycle <= '0';
      else
        -- DACLRC counter incrementation.
        if lrclk_counter_r /= lrclk_counter_max then
          lrclk_counter_r <= lrclk_counter_r + 1;
        else
          -- On max value invert the signal and reset the counter.
          if lrclk_r = '0' then
            lrclk_counter_max <= lrclk_high_counter_max_c;
          else
            lrclk_counter_max <= lrclk_low_counter_max_c;
          end if;
          lrclk_counter_r <= 0;
          lrclk_r         <= not lrclk_r;
        end if;
      end if;

    end if;
  end process lrclk_counter;

  -----------------------------------------------------------------------------
  -- Process to increment and update bclk counter. Process also updated
  -- bit_counter_r register to match which bit should be outputed at
  -- aud_data_out.
  -- type   : synchronous
  -- inputs : clk, rst_n
  -- outputs: bclk_counter_r, bit_counter_r, bclk_r, bclk_first_cycle
  -----------------------------------------------------------------------------
  bclk_counter : process(clk, rst_n)
  begin
    if rst_n = '0' then                 -- asynchronous reset, active low.
      bclk_counter_r   <= 0;
      bit_counter_r    <= data_width_g - 1;
      bclk_r           <= '1';
      bclk_first_cycle <= '1';

    elsif clk'event and clk = '1' then  -- rising edge of the clock.

      -- Increase the counter during needed period of the lrclk. Not outside of
      -- it.
      if lrclk_counter_r <= end_transfer_value
                            or lrclk_counter_r = lrclk_counter_max then

        -- Assign bclk_r register directly during the first cycle after reset.
        -- Need to avoid counter delays.
        if bclk_first_cycle = '1' then
          bclk_r           <= '0';
          bclk_first_cycle <= '0';
        else
          -- BCLK counter incrementation.
          if bclk_counter_r /= bclk_counter_max_c then
            bclk_counter_r <= bclk_counter_r + 1;
          else
            -- On max value invert the signal and reset the counter.
            if bclk_r = '1' then
              bit_counter_r <= bit_counter_r - 1;
              if bit_counter_r = 0 then
                bit_counter_r <= data_width_g - 1;
              end if;
            end if;
            bclk_counter_r <= 0;
            bclk_r         <= not bclk_r;
          end if;
        end if;
      -- Outside of the lrclk cycles set counter to the maximum.
      else
        bclk_r         <= '1';
        bclk_counter_r <= bclk_counter_max_c;
      end if;

    end if;
  end process bclk_counter;

  -----------------------------------------------------------------------------
  -- Process takes care of sampling the left and right data input lines and
  -- outputing sample bits to aud_data_r according to bit_counter_r register
  -- value. Register bit_counter_r value is used after the first bclk cycle.
  -- First cycle is updated with different logic because of the synchronous
  -- update needed without delay.
  -- type   : synchronous
  -- inputs : clk, rst_n
  -- outputs: left_data_r, right_data_r, aud_data_r, transfer_bits_first_cycle
  -----------------------------------------------------------------------------
  sample_and_transfer : process(clk, rst_n)
  begin
    if rst_n = '0' then                 -- asynchronous reset, active low.

      left_data_r               <= (others => '0');
      right_data_r              <= (others => '0');
      aud_data_r                <= '0';
      transfer_bits_first_cycle <= '1';

    elsif clk'event and clk = '1' then  -- rising edge of the clock.

      -- Sample input at start of the sample cycle or at start of first cycle
      -- after reseting.
      if (lrclk_counter_r = lrclk_counter_max and lrclk_r = '0')
        or transfer_bits_first_cycle = '1' then
        left_data_r               <= left_data_in;
        right_data_r              <= right_data_in;
        transfer_bits_first_cycle <= '0';
      end if;

      -- Transfer bits according this if block.
      -- Transfer first MSB bit from left or right data to the ouput. Needed
      -- because bit_counter_r is updated syncronously to bclk rising edges.
      if lrclk_counter_r = lrclk_counter_max then
        if lrclk_r = '0' then
          -- Take input directly from the output to avoid one clock cycle delay.
          aud_data_r <= left_data_in(data_width_g - 1);
        else
          aud_data_r <= right_data_r(data_width_g - 1);
        end if;

      -- All other data bits are transfered with this condition block when
      -- bclk_r goes from high to low.
      elsif (bclk_counter_r = bclk_counter_max_c and bclk_r = '1')
        and lrclk_counter_r <= end_transfer_value and bit_counter_r /= 0 then
        -- Output left data when lrclk high and right when low.
        if lrclk_r = '0' then
          aud_data_r <= right_data_r(bit_counter_r - 1);
        else
          aud_data_r <= left_data_r(bit_counter_r - 1);
        end if;
      end if;

    end if;

  end process sample_and_transfer;

  -- Connect inner registers to the outputs.
  aud_bclk_out  <= bclk_r;
  aud_data_out  <= aud_data_r;
  aud_lrclk_out <= lrclk_r;

  -- Assert some generic values.
  assert data_width_g = 8 or data_width_g = 16 or data_width_g = 32
    report "Not allowed value for data_width_g"
    severity failure;

end rtl;
