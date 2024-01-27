library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_0 is
    port (
        adc_pll_clock_clk      : in std_logic;                                        -- clk
        adc_pll_locked_export  : in std_logic;                                        -- export
        clock_clk              : in std_logic;                                        -- clk
        command_valid          : in std_logic;                                        -- valid
        command_channel        : in std_logic_vector(4 downto 0);                     -- channel
        command_startofpacket  : in std_logic;                                        -- startofpacket
        command_endofpacket    : in std_logic;                                        -- endofpacket
        command_ready          : out std_logic;                                       -- ready
        reset_sink_reset_n     : in std_logic;                                        -- reset_n
        response_valid         : out std_logic;                                       -- valid
        response_channel       : out std_logic_vector(4 downto 0) := (others => '0'); -- channel
        response_data          : out std_logic_vector(11 downto 0);                   -- data
        response_startofpacket : out std_logic := '0';                                -- startofpacket
        response_endofpacket   : out std_logic := '0'                                 -- endofpacket
    );
end entity;

architecture rtl of adc_0 is
    signal running : boolean   := false;
    signal ctr     : std_logic := '0';
    signal r       : std_logic;
begin

    command_ready <= '1';
    response_data <= (others => r);

    process (adc_pll_clock_clk)
    begin
        if rising_edge(adc_pll_clock_clk) then
            if reset_sink_reset_n = '0' then
                running        <= false;
                response_valid <= '0';
                r              <= '0';
            else
                if (command_valid = '1') then
                    running <= true;
                    ctr     <= '1';
                end if;

                if (running) then
                    ctr <= not ctr;
                    if (ctr = '0') then
                        r              <= not r;
                        response_valid <= '1';
                    else
                        response_valid <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture;
