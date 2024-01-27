library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity param_ctl is
    port (
        clk   : in std_logic;
        reset : in std_logic;

        din_valid : in std_logic;
        din_ready : out std_logic;
        din_data  : in std_logic_vector(7 downto 0);

        lo_phase_inc : out std_logic_vector(31 downto 0);
        atten_mixer  : out std_logic_vector(4 downto 0);
        atten_fir_if : out std_logic_vector(4 downto 0);
        atten_demod  : out std_logic_vector(3 downto 0);
        led          : out std_logic
    );
end entity;

architecture rtl of param_ctl is
    signal din_ready_r : std_logic;

    signal addr_latched : std_logic;
    signal addr         : std_logic_vector(7 downto 0);

    signal lo_phase_inc_r : std_logic_vector(31 downto 0);
    signal atten_mixer_r  : std_logic_vector(4 downto 0);
    signal atten_fir_if_r : std_logic_vector(4 downto 0);
    signal atten_demod_r  : std_logic_vector(3 downto 0);
    signal led_r          : std_logic;
begin

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                din_ready_r  <= '1';
                addr         <= (others => '0');
                addr_latched <= '0';

                lo_phase_inc <= (others => '0');
                atten_mixer  <= (others => '0');
                atten_fir_if <= (others => '0');
                atten_demod  <= (others => '0');
                led          <= '0';

                lo_phase_inc_r <= (others => '0');
                atten_mixer_r  <= (others => '0');
                atten_fir_if_r <= (others => '0');
                atten_demod_r  <= (others => '0');
                led_r          <= '0';
            else
                if (addr_latched = '0') then
                    if (din_valid = '1' and din_ready_r = '1') then
                        addr_latched <= '1';
                        addr         <= din_data;
                    end if;
                else
                    if (din_valid = '1' and din_ready_r = '1') then
                        addr_latched <= '0';
                        case (to_integer(unsigned(addr))) is
                            when 0 =>
                                lo_phase_inc_r(7 downto 0) <= din_data;
                            when 1 =>
                                lo_phase_inc_r(15 downto 8) <= din_data;
                            when 2 =>
                                lo_phase_inc_r(23 downto 16) <= din_data;
                            when 3 =>
                                lo_phase_inc_r(31 downto 24) <= din_data;
                            when 4 =>
                                atten_mixer_r <= din_data(4 downto 0);
                            when 8 =>
                                atten_fir_if_r <= din_data(4 downto 0);
                            when 12 =>
                                atten_demod_r <= din_data(3 downto 0);
                            when 16 =>
                                led_r <= din_data(0);
                            when 255 =>
                                lo_phase_inc <= lo_phase_inc_r;
                                atten_mixer  <= atten_mixer_r;
                                atten_fir_if <= atten_fir_if_r;
                                atten_demod  <= atten_demod_r;
                                led          <= led_r;
                            when others =>
                                null;
                        end case;
                    end if;
                end if;
            end if;
        end if;
    end process;

    din_ready <= din_ready_r;

end architecture;
