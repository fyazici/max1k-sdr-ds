library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity dsp_atten is
    generic (
        C_NUM_STAGES : positive;
        C_IN_WIDTH   : positive;
        C_OUT_WIDTH  : positive
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;

        shift_amount : in std_logic_vector((C_NUM_STAGES - 1) downto 0);
        shift_arith  : in std_logic;

        din_valid : in std_logic;
        din_ready : out std_logic;
        din_data_i  : in std_logic_vector((C_IN_WIDTH - 1) downto 0);
        din_data_q  : in std_logic_vector((C_IN_WIDTH - 1) downto 0);

        dout_valid : out std_logic;
        dout_ready : in std_logic;
        dout_data_i  : out std_logic_vector((C_OUT_WIDTH - 1) downto 0);
        dout_data_q  : out std_logic_vector((C_OUT_WIDTH - 1) downto 0)
    );
end entity;

architecture rtl of dsp_atten is
    signal din_ready_r  : std_logic;
    signal dout_valid_r : std_logic;

    signal dout_i_comb : std_logic_vector((C_OUT_WIDTH - 1) downto 0);
    signal dout_q_comb : std_logic_vector((C_OUT_WIDTH - 1) downto 0);

    subtype stage_t is std_logic_vector((C_IN_WIDTH - 1) downto 0);
    type inter_t is array (0 to C_NUM_STAGES) of stage_t;
    signal inter_i : inter_t;
    signal inter_q : inter_t;

    impure function barrel_shift_stage(
        constant din : stage_t;
        constant i: natural range 0 to (C_NUM_STAGES - 1)) return stage_t is
        constant offset : natural := (2 ** i);
        variable dout : stage_t;
    begin
        for j in 0 to (C_IN_WIDTH - 1 - offset) loop
            if (shift_amount(i) = '0') then
                dout(j) := din(j);
            else
                dout(j) := din(j + offset);
            end if;
        end loop;
        for j in (C_IN_WIDTH - offset) to (C_IN_WIDTH - 1) loop
            if (shift_amount(i) = '0') then
                dout(j) := din(j);
            else
                if (shift_arith = '0') then
                    dout(j) := '0';
                else
                    dout(j) := din(C_IN_WIDTH - 1);
                end if;
            end if;
        end loop;
        return dout;
    end function;
begin
    assert C_IN_WIDTH = integer(2 ** C_NUM_STAGES) report "width must match exactly 2**C_NUM_STAGES" severity error;

    inter_i(0)  <= din_data_i;
    inter_q(0)  <= din_data_q;
    dout_i_comb <= inter_i(C_NUM_STAGES)(C_OUT_WIDTH - 1 downto 0);
    dout_q_comb <= inter_q(C_NUM_STAGES)(C_OUT_WIDTH - 1 downto 0);

    GEN_INTER : for i in 0 to (C_NUM_STAGES - 1) generate
        inter_i(i + 1) <= barrel_shift_stage(inter_i(i), i);
        inter_q(i + 1) <= barrel_shift_stage(inter_q(i), i);
    end generate;

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                din_ready_r  <= '1';
                dout_valid_r <= '0';
            else
                if (din_valid = '1' and din_ready_r = '1') then
                    din_ready_r  <= '0';
                    dout_valid_r <= '1';
                    dout_data_i    <= dout_i_comb;
                    dout_data_q    <= dout_q_comb;
                end if;

                if (dout_valid_r = '1' and dout_ready = '1') then
                    dout_valid_r <= '0';
                    din_ready_r  <= '1';
                end if;
            end if;
        end if;
    end process;

    din_ready  <= din_ready_r;
    dout_valid <= dout_valid_r;
end architecture;
