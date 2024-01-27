library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity tb_fir is
end entity;

architecture sim of tb_fir is
    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal din_valid  : std_logic := '0';
    signal din_ready  : std_logic;
    signal din_data_i : std_logic_vector(7 downto 0);
    signal din_data_q : std_logic_vector(7 downto 0);

    signal dout_valid  : std_logic;
    signal dout_data_i : std_logic_vector(7 downto 0);
    signal dout_data_q : std_logic_vector(7 downto 0);

    constant C_IMPULSE : std_logic_vector := x"F807FA05FC03FE01";
    constant C_STEP    : std_logic_vector := x"FC04FD03FE02FF01";
    alias C_IMPULSE_DT : std_logic_vector((C_IMPULSE'length - 1) downto 0) is C_IMPULSE;
    alias C_STEP_DT    : std_logic_vector((C_STEP'length - 1) downto 0) is C_STEP;
begin

    clk   <= not clk after 5 ns;
    reset <= '0' after 90.001 ns;

    U_UUT : entity work.dsp_fir
        generic map(
            C_COEFF_INIT     => C_IMPULSE,
            C_COEFF_WIDTH    => 8,
            C_NUM_TAPS       => 8,
            C_NUM_MACS       => 2,
            C_REGISTERED_MAC => TRUE,

            C_INPUT_WIDTH             => 8,
            C_MULTIPLIER_DISCARD_LSB  => 0,
            C_ACCUMULATOR_WIDTH       => 10,
            C_ACCUMULATOR_DISCARD_LSB => 0,
            C_OUTPUT_WIDTH            => 8
        )
        port map(
            clk   => clk,
            reset => reset,

            din_valid  => din_valid,
            din_ready  => din_ready,
            din_data_i => din_data_i,
            din_data_q => din_data_q,

            dout_valid  => dout_valid,
            dout_ready  => '1',
            dout_data_i => dout_data_i,
            dout_data_q => dout_data_q
        );

    PROC_SEQ : process
        variable hi : integer;
        variable lo : integer;
    begin
        wait until reset = '0';
        -- impulse resp on i, step resp on q
        din_data_i <= x"01";
        din_data_q <= x"01";
        din_valid  <= '1';

        wait until falling_edge(din_ready);
        din_data_i <= x"00";

        for i in 0 to 7 loop
            hi := (i + 1) * 8 - 1;
            lo := i * 8;
            wait until rising_edge(dout_valid);
            assert dout_data_i = C_IMPULSE_DT(hi downto lo) report "I data mistmatch: " & to_hstring(dout_data_i);
            assert dout_data_q = C_STEP_DT(hi downto lo) report "Q data mismatch: " & to_hstring(dout_data_q);
        end loop;

        wait;
    end process;

end architecture;
