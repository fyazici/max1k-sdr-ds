
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library adc_0;

entity adc_ctl is
    generic (
        C_ADC_CHANNEL : positive := 2;
        C_OUT_WIDTH   : positive := 12
    );
    port (
        clk_adc    : in std_logic;
        pll_locked : in std_logic;

        clk     : in std_logic;
        reset_n : in std_logic;

        sample_valid : out std_logic;
        sample_ready : in std_logic;
        sample_data  : out std_logic_vector((C_OUT_WIDTH - 1) downto 0)
    );
end entity;

architecture rtl of adc_ctl is
    signal sample_valid_r : std_logic;
    signal sample_stall   : std_logic;

    signal adc_cmd_valid : std_logic;
    signal adc_cmd_sop   : std_logic;
    signal adc_cmd_ready : std_logic;

    signal adc_resp_valid : std_logic;
    signal adc_resp_prev  : std_logic;
    signal adc_resp_data  : std_logic_vector(11 downto 0);
begin
    assert C_ADC_CHANNEL = 2 report "only channel 2 is enabled in ADC IP instance" severity error;
    assert C_OUT_WIDTH >= 12 report "sample output must be at least 12-bits wide" severity error;

    U_ADC : entity adc_0.adc_0
        port map(
            adc_pll_clock_clk     => clk_adc,
            adc_pll_locked_export => pll_locked,

            clock_clk          => clk,
            reset_sink_reset_n => reset_n,

            command_valid         => adc_cmd_valid,
            command_channel       => std_logic_vector(to_unsigned(C_ADC_CHANNEL, 5)),
            command_startofpacket => adc_cmd_sop,
            command_endofpacket   => '0',
            command_ready         => adc_cmd_ready,

            response_valid         => adc_resp_valid,
            response_channel       => open,
            response_data          => adc_resp_data,
            response_startofpacket => open,
            response_endofpacket   => open
        );

    PROC_ADC_CTL : process (clk) is
    begin
        if rising_edge(clk) then
            if (reset_n = '0') then
                adc_cmd_valid  <= '0';
                adc_cmd_sop    <= '0';
                adc_resp_prev  <= '0';
                sample_valid_r <= '0';
                sample_data    <= (others => '0');
            else
                if (adc_cmd_valid = '0') then
                    adc_cmd_valid <= '1';
                    adc_cmd_sop   <= '1';
                end if;

                if (adc_cmd_sop = '1' and adc_cmd_ready = '1') then
                    adc_cmd_sop <= '0';
                end if;

                adc_resp_prev <= adc_resp_valid;
                if (sample_stall = '0' and adc_resp_valid = '1' and adc_resp_prev = '0') then
                    sample_valid_r <= '1';
                    sample_data    <= std_logic_vector(resize(signed('0' & adc_resp_data) - 2048, 12));
                end if;

                if (sample_valid_r = '1' and sample_ready = '1') then
                    sample_valid_r <= '0';
                end if;
            end if;
        end if;
    end process;

    sample_valid <= sample_valid_r;
    sample_stall <= sample_valid_r and not sample_ready;

end architecture;
