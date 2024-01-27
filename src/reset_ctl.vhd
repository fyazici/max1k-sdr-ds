
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity reset_ctl is
    generic (
        C_INIT_RESET_CYCLES : positive
    );
    port (
        slowest_sync_clk : in std_logic;
        pll_locked       : in std_logic;
        ext_reset        : in std_logic;

        sync_reset   : out std_logic;
        sync_reset_n : out std_logic
    );
end entity;

architecture rtl of reset_ctl is
    signal ctr : integer range 0 to (C_INIT_RESET_CYCLES - 1);
begin

    PROC_RESET : process (ext_reset, pll_locked, slowest_sync_clk) is
    begin
        if ((ext_reset = '1') or (pll_locked = '0')) then
            sync_reset   <= '1';
            sync_reset_n <= '0';
            ctr          <= C_INIT_RESET_CYCLES - 1;
        else
            if rising_edge(slowest_sync_clk) then
                if (ctr = 0) then
                    sync_reset   <= '0';
                    sync_reset_n <= '1';
                else
                    ctr <= ctr - 1;
                end if;
            end if;
        end if;
    end process;

end architecture;
