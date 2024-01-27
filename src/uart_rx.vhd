library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity uart_rx is
    generic (
        C_OVERSAMPLE_FACTOR : positive
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;

        rx : in std_logic;

        dout_valid : out std_logic;
        dout_ready : in std_logic;
        dout_data  : out std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of uart_rx is
    signal dout_valid_r : std_logic;

    signal rx_prev   : std_logic;
    signal bit_timer : natural range 0 to C_OVERSAMPLE_FACTOR;
    signal bit_idx   : natural range 0 to 7;

    type state_t is (S_IDLE, S_START, S_SAMPLE, S_STOP, S_END);
    signal state : state_t;
begin

    PROC_UART_RX : process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                bit_timer     <= 0;
                bit_idx       <= 0;
                dout_data  <= (others => '0');
                dout_valid_r <= '0';
                rx_prev       <= '1';
            else
                rx_prev <= rx;
                case (state) is
                    when S_IDLE =>
                        dout_valid_r <= '0';
                        if (rx = '0' and rx_prev = '1') then
                            bit_timer     <= C_OVERSAMPLE_FACTOR / 2 - 1;
                            state <= S_START;
                        end if;
                    when S_START =>
                        if (rx = '0') then
                            if (bit_timer = 0) then
                                bit_timer     <= C_OVERSAMPLE_FACTOR - 1;
                                bit_idx       <= 7;
                                dout_data  <= (others => '0');
                                state <= S_SAMPLE;
                            else
                                bit_timer <= bit_timer - 1;
                            end if;
                        else
                            state <= S_IDLE;
                        end if;
                    when S_SAMPLE =>
                        if (bit_timer = 0) then
                            dout_data(7 - bit_idx) <= rx;
                            if (bit_idx = 0) then
                                state <= S_STOP;
                            else
                                bit_idx <= bit_idx - 1;
                            end if;
                            bit_timer <= C_OVERSAMPLE_FACTOR - 1;
                        else
                            bit_timer <= bit_timer - 1;
                        end if;
                    when S_STOP =>
                        if (bit_timer = 0) then
                            if (rx = '1') then
                                dout_valid_r <= '1';
                            end if;
                            state <= S_END;
                        else
                            bit_timer <= bit_timer - 1;
                        end if;
                    when S_END =>
                        if (dout_valid_r = '1' and dout_ready = '1') then
                            dout_valid_r <= '0';
                            state <= S_IDLE;
                        end if;
                    when others => null;
                end case;
            end if;
        end if;
    end process;

    dout_valid <= dout_valid_r;

end architecture;
