
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_top is
end entity;

architecture rtl of tb_top is
    signal clk_12 : std_logic := '0';
    signal led : std_logic_vector(7 downto 0);
    signal ftdi_tx: std_logic := '1';
    signal ftdi_rx: std_logic;
begin
    clk_12 <= not clk_12 after 83.333 ns;

    U_UUT: entity work.top
    port map (
        clk_12 => clk_12,
        led => led,
        ftdi_tx => ftdi_tx,
        ftdi_rx => ftdi_rx,

        clk_x => '0',
        user_btn => '0',
        sen_int1 => '0',
        sen_int2 => '0',
        sen_sdo => '0',
        flash_do => '0'

    );

end architecture;