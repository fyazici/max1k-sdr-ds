
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity dsp_mixer is
    generic (
        C_RF_WIDTH        : positive;
        C_LO_WIDTH        : positive;
        C_OUT_DISCARD_LSB : natural;
        C_OUT_WIDTH       : positive
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;

        din_valid : in std_logic;
        din_ready : out std_logic;
        din_data  : in std_logic_vector((C_RF_WIDTH - 1) downto 0);

        lo_data_i : in std_logic_vector((C_LO_WIDTH - 1) downto 0);
        lo_data_q : in std_logic_vector((C_LO_WIDTH - 1) downto 0);

        dout_valid  : out std_logic;
        dout_ready  : in std_logic;
        dout_data_i : out std_logic_vector((C_OUT_WIDTH - 1) downto 0);
        dout_data_q : out std_logic_vector((C_OUT_WIDTH - 1) downto 0)
    );
end entity;

architecture rtl of dsp_mixer is
    constant C_MULT_WIDTH : natural := C_RF_WIDTH + C_LO_WIDTH;

    signal din_ready_r  : std_logic;
    signal dout_valid_r : std_logic;
    signal lo_data_q_r  : std_logic_vector((C_LO_WIDTH - 1) downto 0);

    signal mult_in_rf : signed((C_RF_WIDTH - 1) downto 0);
    signal mult_in_lo : signed((C_LO_WIDTH - 1) downto 0);
    signal mult_out   : signed((C_MULT_WIDTH - 1) downto 0);

    type state_t is (S_IDLE, S_MULT_I, S_MULT_Q, S_END);
    signal state : state_t;
begin

    -- use a single multiplier
    mult_out <= mult_in_rf * mult_in_lo;

    PROC_DSP_MIXER : process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                mult_in_rf   <= (others => '0');
                mult_in_lo   <= (others => '0');
                din_ready_r  <= '1';
                dout_valid_r <= '0';
                dout_data_i  <= (others => '0');
                dout_data_q  <= (others => '0');
                lo_data_q_r  <= (others => '0');
                state        <= S_IDLE;
            else
                case state is
                    when S_IDLE =>
                        if (din_valid = '1' and din_ready_r = '1') then
                            din_ready_r <= '0';
                            mult_in_rf  <= signed(din_data);
                            mult_in_lo  <= signed(lo_data_i);
                            lo_data_q_r <= lo_data_q;
                            state       <= S_MULT_I;
                        end if;
                    when S_MULT_I =>
                        dout_data_i <= std_logic_vector(resize(shift_right(mult_out, C_OUT_DISCARD_LSB), C_OUT_WIDTH));
                        mult_in_lo  <= signed(lo_data_q_r);
                        state       <= S_MULT_Q;
                    when S_MULT_Q =>
                        dout_data_q  <= std_logic_vector(resize(shift_right(mult_out, C_OUT_DISCARD_LSB), C_OUT_WIDTH));
                        dout_valid_r <= '1';
                        state        <= S_END;
                    when S_END =>
                        if (dout_ready = '1') then
                            dout_valid_r <= '0';
                            din_ready_r  <= '1';
                            state        <= S_IDLE;
                        end if;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

    din_ready  <= din_ready_r;
    dout_valid <= dout_valid_r;

end architecture;
