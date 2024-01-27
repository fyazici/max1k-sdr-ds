library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity uart_tx is
    generic (
        C_OVERSAMPLE_FACTOR : positive
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;

        din_valid : in std_logic;
        din_ready : out std_logic;
        din_data  : in std_logic_vector(7 downto 0);

        tx : out std_logic
    );
end entity;

architecture rtl of uart_tx is
    signal din_ready_r : std_logic;
    signal tx_data     : std_logic_vector(7 downto 0);
    signal bit_timer   : natural range 0 to C_OVERSAMPLE_FACTOR;
    signal bit_idx     : natural range 0 to 9;
begin
    PROC_UART_TX : process (clk) is
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                din_ready_r <= '1';
                bit_timer   <= 0;
                bit_idx     <= 0;
            else
                if (din_valid = '1' and din_ready_r = '1') then
                    din_ready_r <= '0';
                    tx_data     <= din_data;
                    bit_idx     <= 9;
                    bit_timer   <= C_OVERSAMPLE_FACTOR - 1;
                else
                    if (bit_timer = 0) then
                        if (bit_idx > 0) then
                            bit_idx   <= bit_idx - 1;
                            bit_timer <= C_OVERSAMPLE_FACTOR - 1;
                        else
                            din_ready_r <= '1';
                        end if;
                    else
                        bit_timer <= bit_timer - 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    PROC_UART_OUT : process (clk) is
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                tx <= '1';
            else
                case (bit_idx) is
                    when 0 =>
                        tx <= '1';
                    when 1 to 8 =>
                        tx <= tx_data(8 - bit_idx);
                    when 9 =>
                        tx <= '0';
                    when others =>
                        tx <= '1';
                end case;
            end if;
        end if;
    end process;

    din_ready <= din_ready_r;

end architecture;
