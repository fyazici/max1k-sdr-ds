library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity dbg_aligner is
    port (
        clk   : in std_logic;
        reset : in std_logic;

        sample_valid : in std_logic;
        sample_ready : in std_logic;
        sample_data  : in std_logic_vector(11 downto 0);
        lo_data_i    : in std_logic_vector(15 downto 0);
        lo_data_q    : in std_logic_vector(15 downto 0);

        mixer_valid  : in std_logic;
        mixer_ready  : in std_logic;
        mixer_data_i : in std_logic_vector(15 downto 0);
        mixer_data_q : in std_logic_vector(15 downto 0);

        if_valid  : in std_logic;
        if_ready  : in std_logic;
        if_data_i : in std_logic_vector(15 downto 0);
        if_data_q : in std_logic_vector(15 downto 0);

        demod_valid : in std_logic;
        demod_ready : in std_logic;
        demod_data  : in std_logic_vector(7 downto 0);

        dbg_valid        : out std_logic;
        dbg_sample_data  : out std_logic_vector(11 downto 0);
        dbg_lo_data_i    : out std_logic_vector(15 downto 0);
        dbg_lo_data_q    : out std_logic_vector(15 downto 0);
        dbg_mixer_data_i : out std_logic_vector(15 downto 0);
        dbg_mixer_data_q : out std_logic_vector(15 downto 0);
        dbg_if_data_i    : out std_logic_vector(15 downto 0);
        dbg_if_data_q    : out std_logic_vector(15 downto 0);
        dbg_demod_data   : out std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of dbg_aligner is
    signal sample_data_dly1 : std_logic_vector(11 downto 0);
    signal sample_data_dly2 : std_logic_vector(11 downto 0);
    signal sample_data_dly3 : std_logic_vector(11 downto 0);

    signal lo_data_i_dly1 : std_logic_vector(15 downto 0);
    signal lo_data_q_dly1 : std_logic_vector(15 downto 0);
    signal lo_data_i_dly2 : std_logic_vector(15 downto 0);
    signal lo_data_q_dly2 : std_logic_vector(15 downto 0);
    signal lo_data_i_dly3 : std_logic_vector(15 downto 0);
    signal lo_data_q_dly3 : std_logic_vector(15 downto 0);

    signal mixer_data_i_dly1 : std_logic_vector(15 downto 0);
    signal mixer_data_q_dly1 : std_logic_vector(15 downto 0);
    signal mixer_data_i_dly2 : std_logic_vector(15 downto 0);
    signal mixer_data_q_dly2 : std_logic_vector(15 downto 0);

    signal if_data_i_dly1 : std_logic_vector(15 downto 0);
    signal if_data_q_dly1 : std_logic_vector(15 downto 0);
begin

    PROC_SAMPLE_DATA : process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                sample_data_dly1 <= (others => '0');
                sample_data_dly2 <= (others => '0');
                sample_data_dly3 <= (others => '0');
                lo_data_i_dly1   <= (others => '0');
                lo_data_i_dly2   <= (others => '0');
                lo_data_i_dly3   <= (others => '0');
                lo_data_q_dly1   <= (others => '0');
                lo_data_q_dly2   <= (others => '0');
                lo_data_q_dly3   <= (others => '0');
            else
                if (sample_valid = '1' and sample_ready = '1') then
                    sample_data_dly1 <= sample_data;
                    sample_data_dly2 <= sample_data_dly1;
                    sample_data_dly3 <= sample_data_dly2;
                    lo_data_i_dly1   <= lo_data_i;
                    lo_data_i_dly2   <= lo_data_i_dly1;
                    lo_data_i_dly3   <= lo_data_i_dly2;
                    lo_data_q_dly1   <= lo_data_q;
                    lo_data_q_dly2   <= lo_data_q_dly1;
                    lo_data_q_dly3   <= lo_data_q_dly2;
                end if;
            end if;
        end if;
    end process;

    PROC_MIXER_DATA : process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                mixer_data_i_dly1 <= (others => '0');
                mixer_data_i_dly2 <= (others => '0');
            else
                if (mixer_valid = '1' and mixer_ready = '1') then
                    mixer_data_i_dly1 <= mixer_data_i;
                    mixer_data_i_dly2 <= mixer_data_i_dly1;
                    mixer_data_q_dly1 <= mixer_data_q;
                    mixer_data_q_dly2 <= mixer_data_q_dly1;
                end if;
            end if;
        end if;
    end process;

    PROC_IF_DATA : process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                if_data_i_dly1 <= (others => '0');
            else
                if (if_valid = '1' and if_ready = '1') then
                    if_data_i_dly1 <= if_data_i;
                    if_data_q_dly1 <= if_data_q;
                end if;
            end if;
        end if;
    end process;

    dbg_sample_data  <= sample_data_dly3;
    dbg_lo_data_i    <= lo_data_i_dly3;
    dbg_lo_data_q    <= lo_data_q_dly3;
    dbg_mixer_data_i <= mixer_data_i_dly2;
    dbg_mixer_data_q <= mixer_data_q_dly2;
    dbg_if_data_i    <= if_data_i_dly1;
    dbg_if_data_q    <= if_data_q_dly1;
    dbg_demod_data   <= demod_data;
    dbg_valid        <= demod_valid and demod_ready;

end architecture;
