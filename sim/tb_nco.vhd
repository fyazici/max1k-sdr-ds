
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library std;
use std.textio.all;

entity tb_nco is
end entity;

architecture sim of tb_nco is
    constant C_PHA_WIDTH : positive := 32;
    constant C_ANG_WIDTH : positive := 15;
    constant C_OUT_WIDTH : positive := 16;

    signal clk : std_logic := '0';
    signal reset : std_logic := '1';

    signal pha_en : std_logic := '0';
    signal pha_inc : std_logic_vector((C_PHA_WIDTH - 1) downto 0) := (others => '0');
    signal dout_i : std_logic_vector((C_OUT_WIDTH - 1) downto 0);
    signal dout_q : std_logic_vector((C_OUT_WIDTH - 1) downto 0);
begin
    clk <= not clk after 5 ns;
    reset <= '0' after 10 ns;

    U_UUT: entity work.dsp_nco
        generic map (
            C_PHA_WIDTH => C_PHA_WIDTH,
            C_ANG_WIDTH => C_ANG_WIDTH,
            C_OUT_WIDTH => C_OUT_WIDTH
        )
        port map (
            clk => clk,
            reset => reset,

            pha_en => pha_en,
            pha_inc => pha_inc,

            dout_i => dout_i,
            dout_q => dout_q
        );

    PROC_SEQ : process
        file f : text open write_mode is "nco_data.csv";
        variable ln : line;
    begin
        wait until reset = '0';
        wait for 20 ns;
        pha_inc <= std_logic_vector(to_unsigned(429496730, 32));
        pha_en <= '1';
        wait until rising_edge(clk);
        for i in 0 to 8192 loop
            wait until rising_edge(clk);
            write(ln, to_integer(signed(dout_i)));
            writeline(f, ln);
        end loop;
        wait;
    end process;
    

end architecture;