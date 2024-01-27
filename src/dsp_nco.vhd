
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity dsp_nco is
    generic (
        C_PHA_WIDTH       : positive;
        C_ANG_WIDTH       : positive;
        C_OUT_WIDTH       : positive;
        C_PHASE_DITHERING : boolean := FALSE
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;

        pha_en  : in std_logic;
        pha_inc : in std_logic_vector((C_PHA_WIDTH - 1) downto 0);

        dout_i : out std_logic_vector((C_OUT_WIDTH - 1) downto 0);
        dout_q : out std_logic_vector((C_OUT_WIDTH - 1) downto 0)
    );
end entity;

architecture rtl of dsp_nco is
    constant C_LUT_LENGTH : positive := (2 ** (C_ANG_WIDTH - 2));

    subtype sample_t is signed((C_OUT_WIDTH - 1) downto 0);
    type sample_mem_t is array (0 to (C_LUT_LENGTH - 1)) of sample_t;
    function init_sample_mem return sample_mem_t is
        variable result    : sample_mem_t := (others => (others => '0'));
        variable t         : real;
        constant amplitude : real := real(2 ** (C_OUT_WIDTH - 1) - 1);
        variable int_value : integer;
    begin
        for i in 0 to (C_LUT_LENGTH - 1) loop
            t         := MATH_PI_OVER_2 * real(i) / real(C_LUT_LENGTH);
            int_value := integer(round(amplitude * cos(t)));
            result(i) := to_signed(int_value, C_OUT_WIDTH);
        end loop;
        return result;
    end function;
    signal sample_mem : sample_mem_t := init_sample_mem;
    signal sample_addr_i : natural range 0 to (C_LUT_LENGTH - 1);
    signal sample_addr_q : natural range 0 to (C_LUT_LENGTH - 1);
    signal sample_out_i : sample_t;
    signal sample_out_q : sample_t;

    attribute romstyle               : string;
    attribute romstyle of sample_mem : signal is "M9K"; -- infer single-port rom

    signal phase_i : unsigned((C_PHA_WIDTH - 1) downto 0);
    signal phase_q : unsigned((C_PHA_WIDTH - 1) downto 0);

    subtype angle_t is unsigned((C_ANG_WIDTH - 1) downto 0);

    signal angle_i : angle_t;
    signal angle_q : angle_t;

    signal sample_sign_i : std_logic;
    signal sample_zero_i : std_logic;
    signal sample_sign_q : std_logic;
    signal sample_zero_q : std_logic;
    
    signal sample_sign_i_dly : std_logic;
    signal sample_zero_i_dly : std_logic;
    signal sample_sign_q_dly : std_logic;
    signal sample_zero_q_dly : std_logic;

	 -- NOTE: register address lookup (and dly2) if timing fails
    procedure lookup_sample_addr(
        constant angle_in : in angle_t;
        signal addr_out : out natural;
        signal sign_out : out std_logic;
        signal zero_out : out std_logic
        ) is
        constant Q_1   : natural := 1 * (2 ** (C_ANG_WIDTH - 2));
        constant Q_2   : natural := 2 * (2 ** (C_ANG_WIDTH - 2));
        constant Q_3   : natural := 3 * (2 ** (C_ANG_WIDTH - 2));
        constant Q_4   : natural := 4 * (2 ** (C_ANG_WIDTH - 2));
        constant alpha : natural := to_integer(angle_in);
    begin
        assert alpha < Q_4 report "angles beyond 2*PI are not supported" severity error;
        if (alpha < Q_1) then
            addr_out <= alpha;
            sign_out <= '0';
            zero_out <= '0';
        elsif (alpha = Q_1) then
            addr_out <= 0;
            sign_out <= '0';
            zero_out <= '1';
        elsif (alpha <= Q_2) then
            addr_out <= Q_2 - alpha;
            sign_out <= '1';
            zero_out <= '0';
        elsif (alpha < Q_3) then
            addr_out <= alpha - Q_2;
            sign_out <= '1';
            zero_out <= '0';
        elsif (alpha = Q_3) then
            addr_out <= 0;
            sign_out <= '0';
            zero_out <= '1';
        else -- alpha < Q_4
            addr_out <= Q_4 - alpha;
            sign_out <= '0';
            zero_out <= '0';
        end if;
    end procedure;
begin
    assert C_PHASE_DITHERING = FALSE report "phase dithering is not supported yet" severity error;

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                phase_i <= to_unsigned(0, C_PHA_WIDTH);
                phase_q <= 0 - to_unsigned(2 ** (C_PHA_WIDTH - 2), C_PHA_WIDTH);
            else
                if (pha_en = '1') then
                    phase_i <= phase_i + unsigned(pha_inc);
                    phase_q <= phase_q + unsigned(pha_inc);
                end if;
            end if;
        end if;
    end process;

    process (phase_i, phase_q)
    begin
        if (phase_i(C_PHA_WIDTH - C_ANG_WIDTH - 1) = '1') then
            angle_i <= phase_i((C_PHA_WIDTH - 1) downto (C_PHA_WIDTH - C_ANG_WIDTH)) + 1;
        else
            angle_i <= phase_i((C_PHA_WIDTH - 1) downto (C_PHA_WIDTH - C_ANG_WIDTH));
        end if;

        if (phase_q(C_PHA_WIDTH - C_ANG_WIDTH - 1) = '1') then
            angle_q <= phase_q((C_PHA_WIDTH - 1) downto (C_PHA_WIDTH - C_ANG_WIDTH)) + 1;
        else
            angle_q <= phase_q((C_PHA_WIDTH - 1) downto (C_PHA_WIDTH - C_ANG_WIDTH));
        end if;
    end process;

    process (angle_i, angle_q)
    begin
        lookup_sample_addr(
            angle_in => angle_i,
            addr_out => sample_addr_i,
            sign_out => sample_sign_i,
            zero_out => sample_zero_i
        );

        lookup_sample_addr(
            angle_in => angle_q,
            addr_out => sample_addr_q,
            sign_out => sample_sign_q,
            zero_out => sample_zero_q
        );
    end process;

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                sample_sign_i_dly <= '0';
                sample_zero_i_dly <= '0';
                sample_sign_q_dly <= '0';
                sample_zero_q_dly <= '0';
            else
                sample_sign_i_dly <= sample_sign_i;
                sample_zero_i_dly <= sample_zero_i;
                sample_sign_q_dly <= sample_sign_q;
                sample_zero_q_dly <= sample_zero_q;
            end if;
        end if;
    end process;

    process (clk)
    begin
        if rising_edge(clk) then
            sample_out_i <= sample_mem(sample_addr_i);
            sample_out_q <= sample_mem(sample_addr_q);
        end if;
    end process;

    process (sample_sign_i_dly, sample_zero_i_dly, sample_out_i, sample_sign_q_dly, sample_zero_q_dly, sample_out_q)
    begin
        if (sample_zero_i_dly = '1') then
            dout_i <= (others => '0');
        elsif (sample_sign_i_dly = '0') then
            dout_i <= std_logic_vector(sample_out_i);
        else
            dout_i <= std_logic_vector(-sample_out_i);
        end if;

        if (sample_zero_q_dly = '1') then
            dout_q <= (others => '0');
        elsif (sample_sign_q_dly = '0') then
            dout_q <= std_logic_vector(sample_out_q);
        else
            dout_q <= std_logic_vector(-sample_out_q);
        end if;
    end process;

end architecture;
