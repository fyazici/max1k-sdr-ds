
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity dsp_decim is
    generic (
        C_INPUT_WIDTH  : positive;
        C_DECIM_FACTOR : positive
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;

        din_valid : in std_logic;
        din_ready : out std_logic;
        din_data  : in std_logic_vector((C_INPUT_WIDTH - 1) downto 0);

        dout_valid : out std_logic;
        dout_ready : in std_logic;
        dout_data  : out std_logic_vector((C_INPUT_WIDTH - 1) downto 0)
    );
end entity;

architecture rtl of dsp_decim is
    signal din_ready_r  : std_logic;
    signal dout_valid_r : std_logic;
    signal ctr          : integer range 0 to (C_DECIM_FACTOR - 1);
begin

    PROC_DECIM : process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                din_ready_r  <= '1';
                dout_valid_r <= '0';
                dout_data    <= (others => '0');

                ctr <= C_DECIM_FACTOR - 1;
            else
                if (din_valid = '1' and din_ready_r = '1') then
                    if (ctr = 0) then
                        din_ready_r  <= '0';
                        dout_valid_r <= '1';
                        dout_data    <= din_data;
                    else
                        ctr <= ctr - 1;
                    end if;
                end if;

                if (dout_valid_r = '1' and dout_ready = '1') then
                    dout_valid_r <= '0';
                    din_ready_r  <= '1';

                    ctr <= C_DECIM_FACTOR - 1;
                end if;
            end if;
        end if;
    end process;

    din_ready <= din_ready_r;
    dout_valid <= dout_valid_r;

end architecture;
