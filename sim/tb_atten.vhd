
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library std;
use std.textio.all;

entity tb_atten is
end entity;

architecture sim of tb_atten is
    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal shift_amount : std_logic_vector(2 downto 0);
    signal shift_arith  : std_logic;

    signal din_valid  : std_logic := '0';
    signal din_data_i : std_logic_vector(7 downto 0);
    signal din_data_q : std_logic_vector(7 downto 0);

    signal dout_data_i : std_logic_vector(7 downto 0);
    signal dout_data_q : std_logic_vector(7 downto 0);
begin

    clk   <= not clk after 5 ns;
    reset <= '0' after 90.001 ns;

    U_UUT : entity work.dsp_atten
        generic map(
            C_NUM_STAGES => 3,
            C_IN_WIDTH   => 8,
            C_OUT_WIDTH  => 8
        )
        port map(
            clk   => clk,
            reset => reset,

            shift_amount => shift_amount,
            shift_arith  => shift_arith,

            din_valid  => din_valid,
            din_ready  => open,
            din_data_i => din_data_i,
            din_data_q => din_data_q,

            dout_valid  => open,
            dout_ready  => '1',
            dout_data_i => din_data_i,
            dout_data_q => din_data_q
        );

    PROC_SEQ : process
    begin
        shift_amount <= "000";
        shift_arith  <= '0';
        din_valid    <= '1';
        din_data_i   <= x"99";
        din_data_q   <= x"FF";
        wait for 10 ns;

        shift_amount <= "001";
        wait for 10 ns;

        shift_amount <= "101";
        wait for 10 ns;

        shift_arith <= '1';
        wait for 10 ns;

        din_data_i <= x"AA";
        din_data_q <= x"00";
        wait for 10 ns;

        shift_amount <= "111";
        wait for 10 ns;

        wait;
    end process;
end architecture;
