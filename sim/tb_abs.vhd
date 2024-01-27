
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_abs is
end entity;

architecture sim of tb_abs is
    constant C_WIDTH : natural := 16;
    constant C_MIN : integer := -50; -- -(2 ** (C_WIDTH - 1));
    constant C_MAX : integer := 50; -- (2 ** (C_WIDTH - 1)) - 1;

    signal clk : std_logic := '0';
    signal reset : std_logic := '1';

    signal valid_in : std_logic := '0';
    signal i_in : std_logic_vector((C_WIDTH - 1) downto 0);
    signal q_in : std_logic_vector((C_WIDTH - 1) downto 0);

    signal valid_out : std_logic;
    signal u_out : std_logic_vector((C_WIDTH - 1) downto 0);
begin
    clk <= not clk after 5 ns;
    reset <= '0' after 10 ns;

    U_UUT: entity work.dsp_cplx_abs
        generic map (
            C_IN_WIDTH => C_WIDTH,
            C_OUT_DISCARD_LSB => 1,
            C_OUT_WIDTH => C_WIDTH
        )
        port map (
            clk => clk,
            reset => reset,

            din_valid => valid_in,
            din_ready => open,
            din_data_re => i_in,
            din_data_im => q_in,

            dout_valid => valid_out,
            dout_ready => '1',
            dout_data => u_out
        );

    PROC_SEQ : process
        variable v_expect : signed(C_WIDTH - 1 downto 0);
    begin
        valid_in <= '1';
        for i in C_MIN to C_MAX loop
            for j in C_MIN to C_MAX loop
                --report "testing abs(" & integer'image(i) & " + j" & integer'image(j) & ")";
                i_in <= std_logic_vector(to_signed(i, C_WIDTH));
                q_in <= std_logic_vector(to_signed(j, C_WIDTH));
                v_expect := shift_right(to_signed(integer(floor(sqrt(real(i * i + j * j)))), C_WIDTH), 1);
                wait until (valid_out = '1');
                wait until falling_edge(clk);
                assert (signed(u_out) = v_expect)
                    report "result incorrect: abs(" 
                        & integer'image(i) & " + j" & integer'image(j) 
                        & ") = " & integer'image(to_integer(v_expect)) & " != " 
                        & integer'image(to_integer(unsigned(u_out)));
            end loop;
        end loop;
        valid_in <= '0';

        wait;
    end process;
    

end architecture;