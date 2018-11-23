-------------------------------------------------------------------------------
-- Created    : 24.01.2018
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description:
-- Not synthesizable Wolfson WM8731 audio codec model. Used just for testing
-- and verification the audio_ctrl module.
--
-- Model reads the data from the aud_data_in input to left and right registers
-- according to aud_lrclk_in input and when aud_lrclk_in changes its state
-- then output is updated with the new data.
--
-- Model is a state machine with states, wait_for_input, read_left and
-- read_right.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;


entity audio_codec_model is
  generic (
    data_width_g : integer := 16
    );
  port (
    rst_n           : in  std_logic;
    aud_bclk_in     : in  std_logic;
    aud_data_in     : in  std_logic;
    aud_lrclk_in    : in  std_logic;
    value_left_out  : out std_logic_vector(data_width_g - 1 downto 0);
    value_right_out : out std_logic_vector(data_width_g - 1 downto 0)
    );
end audio_codec_model;


architecture rtl of audio_codec_model is

  -- Enum to label state machine states.
  type states_type is (wait_for_input, read_left, read_right);
  -- Signal to hold current state of the machine.
  signal current_state_r : states_type;

  -- Buffer registers for the lef and right input bits from aud_data_in.
  signal left_data_buffer_r  : std_logic_vector(data_width_g - 1 downto 0);
  signal right_data_buffer_r : std_logic_vector(data_width_g - 1 downto 0);
  -- Left and right data output registers.
  signal left_data_r         : std_logic_vector(data_width_g - 1 downto 0);
  signal right_data_r        : std_logic_vector(data_width_g - 1 downto 0);

begin

  -----------------------------------------------------------------------------
  -- Process to control the whole fsm. Also read bits from the aud_data_in
  -- and when aud_lrclk_in changes, then output register is updated.
  -- type   : synchronous
  -- inputs : aud_bclk_in, rst_n
  -- outputs: current_state_r, left_data_buffer_r, right_data_buffer_r,
  -- left_data_r, right_data_r
  -----------------------------------------------------------------------------
  current_state : process(aud_bclk_in, rst_n)
  begin
    if rst_n = '0' then                 -- asynchronous reset, active low.
      current_state_r     <= wait_for_input;
      left_data_buffer_r  <= (others => '0');
      right_data_buffer_r <= (others => '0');
      left_data_r         <= (others => '0');
      right_data_r        <= (others => '0');

    elsif aud_bclk_in'event and aud_bclk_in = '1' then  -- clock rising edge.

      case (current_state_r) is
        when wait_for_input =>
          if aud_lrclk_in = '1' then
            -- Start reading left channel.
            current_state_r <= read_left;
            -- Read current bit in the input so we don't miss it.
            left_data_buffer_r
              <= left_data_buffer_r(data_width_g - 2 downto 0) & aud_data_in;
          end if;

        when read_left =>
          if aud_lrclk_in = '1' then
            -- Read left channel bits to buffer.
            left_data_buffer_r
              <= left_data_buffer_r(data_width_g - 2 downto 0) & aud_data_in;
          elsif aud_lrclk_in = '0' then
            -- All bits are transfered, move to read right channel data.
            current_state_r <= read_right;
            -- Read first right channel bit so we don't miss it.
            right_data_buffer_r
              <= right_data_buffer_r(data_width_g - 2 downto 0) & aud_data_in;
            -- Update output.
            left_data_r <= left_data_buffer_r;
          end if;

        when read_right =>
          if aud_lrclk_in = '0' then
            -- Read right channel bits to buffer.
            right_data_buffer_r
              <= right_data_buffer_r(data_width_g - 2 downto 0) & aud_data_in;
          elsif aud_lrclk_in = '1' then
            -- All bits are transfered, move to read left channel data.
            current_state_r <= read_left;
            -- Read first left channel bit so we don't miss it.
            left_data_buffer_r
              <= left_data_buffer_r(data_width_g - 2 downto 0) & aud_data_in;
            -- Update output.
            right_data_r <= right_data_buffer_r;
          end if;
      end case;

    end if;

  end process current_state;

  value_left_out  <= left_data_r;
  value_right_out <= right_data_r;

end rtl;
