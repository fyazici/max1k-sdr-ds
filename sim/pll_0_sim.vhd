library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pll_0 is
    port (
        areset : in std_logic;
        inclk0 : in std_logic;
        c0     : out std_logic;
        c1     : out std_logic;
        c2     : out std_logic;
        locked : out std_logic := '0'
    );
end entity;

architecture rtl of pll_0 is
    signal c0_r: std_logic := '0';
    signal c1_r: std_logic := '0';
    signal c2_r: std_logic := '0';

begin
    locked <= '1' after 100 ns;
    c0_r <= not c0_r after 250 ns;
    c1_r <= not c1_r after 7.143 ns;
    c2_r <= not c2_r after 500 ns;

    c0 <= c0_r;
    c1 <= c1_r;
    c2 <= c2_r;

end architecture;
