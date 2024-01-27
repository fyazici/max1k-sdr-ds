
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity dsp_fir is
    generic (
        C_COEFF_INIT     : std_logic_vector;
        C_COEFF_WIDTH    : positive;
        C_NUM_TAPS       : positive;
        C_NUM_MACS       : positive;
        C_REGISTERED_MAC : boolean := FALSE;

        C_INPUT_WIDTH             : positive;
        C_MULTIPLIER_DISCARD_LSB  : natural;
        C_ACCUMULATOR_WIDTH       : positive;
        C_ACCUMULATOR_DISCARD_LSB : natural;
        C_OUTPUT_WIDTH            : positive
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;

        din_valid  : in std_logic;
        din_ready  : out std_logic;
        din_data_i : in std_logic_vector((C_INPUT_WIDTH - 1) downto 0);
        din_data_q : in std_logic_vector((C_INPUT_WIDTH - 1) downto 0);

        dout_valid  : out std_logic;
        dout_ready  : in std_logic;
        dout_data_i : out std_logic_vector((C_OUTPUT_WIDTH - 1) downto 0);
        dout_data_q : out std_logic_vector((C_OUTPUT_WIDTH - 1) downto 0)
    );
end entity dsp_fir;

architecture rtl of dsp_fir is
    alias C_COEFF_INIT_DT       : std_logic_vector((C_COEFF_INIT'length - 1) downto 0) is C_COEFF_INIT;
    constant C_MULTIPLIER_WIDTH : positive := C_INPUT_WIDTH + C_COEFF_WIDTH - C_MULTIPLIER_DISCARD_LSB;
    constant C_NUM_STEPS        : positive := C_NUM_TAPS / C_NUM_MACS;

    subtype coeff_word_t is std_logic_vector((C_NUM_MACS * C_COEFF_WIDTH - 1) downto 0);
    subtype op_word_t is std_logic_vector((C_NUM_MACS * C_INPUT_WIDTH - 1) downto 0);

    type coeff_mem_t is array ((C_NUM_STEPS - 1) downto 0) of coeff_word_t;
    type op_mem_t is array ((C_NUM_STEPS - 1) downto 0) of op_word_t;

    impure function init_coeff_rom return coeff_mem_t is
        variable r : coeff_mem_t;
    begin
        for i in 0 to (C_NUM_STEPS - 1) loop
            r(i) := std_logic_vector(C_COEFF_INIT_DT(((i + 1) * C_NUM_MACS * C_COEFF_WIDTH - 1) downto (i * C_NUM_MACS * C_COEFF_WIDTH)));
        end loop;
        return r;
    end function;

    signal coeff_mem       : coeff_mem_t := init_coeff_rom;
    signal coeff_mem_raddr : natural range 0 to (C_NUM_STEPS - 1);
    signal coeff_mem_out   : coeff_word_t;

    signal op_i_mem       : op_mem_t := (others => (others => '0'));
    signal op_i_mem_raddr : natural range 0 to (C_NUM_STEPS - 1);
    signal op_i_mem_out   : op_word_t;
    signal op_i_mem_we    : std_logic;
    signal op_i_mem_waddr : natural range 0 to (C_NUM_STEPS - 1);
    signal op_i_mem_in    : op_word_t;

    signal op_q_mem       : op_mem_t := (others => (others => '0'));
    signal op_q_mem_raddr : natural range 0 to (C_NUM_STEPS - 1);
    signal op_q_mem_out   : op_word_t;
    signal op_q_mem_we    : std_logic;
    signal op_q_mem_waddr : natural range 0 to (C_NUM_STEPS - 1);
    signal op_q_mem_in    : op_word_t;

    attribute romstyle              : string;
    attribute romstyle of coeff_mem : signal is "M9K"; -- infer single-port rom
    attribute romstyle of op_i_mem    : signal is "M9K"; -- infer simple dual-port ram
    attribute romstyle of op_q_mem    : signal is "M9K"; -- infer simple dual-port ram

    -- op mem shift register signals
    signal op_i_shift_in  : std_logic_vector((C_INPUT_WIDTH - 1) downto 0);
    signal op_i_shift_out : std_logic_vector((C_INPUT_WIDTH - 1) downto 0);
    signal op_q_shift_in  : std_logic_vector((C_INPUT_WIDTH - 1) downto 0);
    signal op_q_shift_out : std_logic_vector((C_INPUT_WIDTH - 1) downto 0);

    signal index        : natural range 0 to (C_NUM_STEPS - 1);
    signal index_next   : natural range 0 to (C_NUM_STEPS - 1);

    signal partial_i      : signed((C_ACCUMULATOR_WIDTH - 1) downto 0);
    signal partial_q      : signed((C_ACCUMULATOR_WIDTH - 1) downto 0);
    signal accumulator_i  : signed((C_ACCUMULATOR_WIDTH - 1) downto 0);
    signal accumulator_q  : signed((C_ACCUMULATOR_WIDTH - 1) downto 0);
    signal dout_acc_i_r   : signed((C_ACCUMULATOR_WIDTH - 1) downto 0);
    signal dout_acc_q_r   : signed((C_ACCUMULATOR_WIDTH - 1) downto 0);
    
    signal busy         : std_logic := '0';
    signal stall        : std_logic;
    signal dout_valid_r : std_logic;
    signal next_busy    : std_logic;

    -- registered mac signals, unused if !C_REGISTERED_MAC
    type mult_out_t is array ((C_NUM_MACS - 1) downto 0) of signed((C_MULTIPLIER_WIDTH - 1) downto 0);
    signal mult_out_i_comb : mult_out_t;
    signal mult_out_q_comb : mult_out_t;
    signal mult_out_i      : mult_out_t; -- same as mul_out_comb if !C_REGISTERED_MAC
    signal mult_out_q      : mult_out_t; -- same as mul_out_comb if !C_REGISTERED_MAC
    signal mult_done    : std_logic;  -- always 0 if !C_REGISTERED_MAC
begin
    assert C_COEFF_INIT'length = C_COEFF_WIDTH * C_NUM_TAPS report "taps invalid";
    assert C_NUM_STEPS * C_NUM_MACS = C_NUM_TAPS report "taps not divisible by macs";

    -- main control logic
    PROC_SEQ : process (clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                busy         <= '0';
                index        <= 0;
                mult_done    <= '0';
                dout_valid_r <= '0';
                accumulator_i  <= (others => '0');
                accumulator_q  <= (others => '0');
                dout_acc_i_r   <= (others => '0');
                dout_acc_q_r   <= (others => '0');
            else
                if (busy = '1') then
                    accumulator_i <= accumulator_i + partial_i;
                    accumulator_q <= accumulator_q + partial_q;
                elsif (stall = '0') then
                    if C_REGISTERED_MAC then
                        accumulator_i <= (others => '0');
                        accumulator_q <= (others => '0');
                    else
                        accumulator_i <= partial_i;
                        accumulator_q <= partial_q;
                    end if;
                end if;

                if (busy = '1' or next_busy = '1') then
                    if (index = (C_NUM_STEPS - 1)) then
                        -- introduce 1 cycle latency if mac register enabled
                        if C_REGISTERED_MAC then
                            mult_done <= '1';
                            busy      <= '1';
                        else
                            dout_valid_r <= '1';
                            dout_acc_i_r   <= accumulator_i + partial_i;
                            dout_acc_q_r   <= accumulator_q + partial_q;
                            busy         <= '0';
                        end if;
                    else
                        busy <= '1';
                    end if;
                end if;

                -- never trig'd if mac register not enabled
                if (mult_done = '1') then
                    mult_done    <= '0';
                    dout_valid_r <= '1';
                    dout_acc_i_r   <= accumulator_i + partial_i;
                    dout_acc_q_r   <= accumulator_q + partial_q;
                    busy         <= '0';
                end if;

                if (dout_valid_r = '1' and dout_ready = '1') then
                    dout_valid_r <= '0';
                end if;

                index <= index_next;
            end if;
        end if;
    end process;

    -- next index calculation logic
    PROC_INDEX_NEXT : process (busy, next_busy, index, mult_done)
    begin
        index_next <= 0;

        if (busy = '1' or next_busy = '1') then
            if (index /= (C_NUM_STEPS - 1)) then
                if (mult_done = '0') then -- dont advance if waiting for mac register
                    index_next <= index + 1;
                end if;
            end if;
        end if;
    end process;

    -- i and q multipliers
    PROC_MUL : process (op_i_mem_in, op_q_mem_in, coeff_mem_out)
        variable v_coeff   : signed((C_COEFF_WIDTH - 1) downto 0);
        variable v_operand_i : signed((C_INPUT_WIDTH - 1) downto 0);
        variable v_operand_q : signed((C_INPUT_WIDTH - 1) downto 0);
    begin
        for i in 0 to (C_NUM_MACS - 1) loop
            v_coeff   := signed(coeff_mem_out(((i + 1) * C_COEFF_WIDTH - 1) downto (i * C_COEFF_WIDTH)));
            v_operand_i := signed(op_i_mem_in(((i + 1) * C_INPUT_WIDTH - 1) downto (i * C_INPUT_WIDTH)));
            v_operand_q := signed(op_q_mem_in(((i + 1) * C_INPUT_WIDTH - 1) downto (i * C_INPUT_WIDTH)));
            mult_out_i_comb(i) <= resize(shift_right(v_coeff * v_operand_i, C_MULTIPLIER_DISCARD_LSB), C_MULTIPLIER_WIDTH);
            mult_out_q_comb(i) <= resize(shift_right(v_coeff * v_operand_q, C_MULTIPLIER_DISCARD_LSB), C_MULTIPLIER_WIDTH);
        end loop;
    end process;

    -- multiplier output process for registered mac
    GEN_REGISTERED_MAC : if C_REGISTERED_MAC generate
        PROC_MUL_REG : process (clk)
        begin
            if rising_edge(clk) then
                for i in 0 to (C_NUM_MACS - 1) loop
                    if (reset = '1') then
                        mult_out_i(i) <= (others => '0');
                        mult_out_q(i) <= (others => '0');
                    else
                        mult_out_i(i) <= mult_out_i_comb(i);
                        mult_out_q(i) <= mult_out_q_comb(i);
                    end if;
                end loop;
            end if;
        end process;
    end generate;

    -- multiplier output connection for combinational mac
    GEN_COMB_MAC : if not C_REGISTERED_MAC generate
        PROC_MUL_COMB : process (mult_out_i_comb, mult_out_q_comb)
        begin
            for i in 0 to (C_NUM_MACS - 1) loop
                mult_out_i(i) <= mult_out_i_comb(i);
                mult_out_q(i) <= mult_out_q_comb(i);
            end loop;
        end process;
    end generate;

    -- add-reduction of multiplier outputs
    PROC_ADD : process (mult_out_i, mult_out_q)
        variable v_add_i : signed((C_ACCUMULATOR_WIDTH - 1) downto 0);
        variable v_add_q : signed((C_ACCUMULATOR_WIDTH - 1) downto 0);
    begin
        v_add_i := (others => '0');
        v_add_q := (others => '0');
        for i in 0 to (C_NUM_MACS - 1) loop
            v_add_i := v_add_i + resize(mult_out_i(i), C_ACCUMULATOR_WIDTH);
            v_add_q := v_add_q + resize(mult_out_q(i), C_ACCUMULATOR_WIDTH);
        end loop;
        partial_i <= v_add_i;
        partial_q <= v_add_q;
    end process;

    -- coeff rom synth
    PROC_COEFF_ROM : process (clk)
    begin
        if rising_edge(clk) then
            coeff_mem_out <= coeff_mem(coeff_mem_raddr);
        end if;
    end process;

    -- op_i ram synth
    PROC_OP_I_RAM : process (clk)
    begin
        if rising_edge(clk) then
            if (op_i_mem_we = '1') then
                op_i_mem(op_i_mem_waddr) <= op_i_mem_in;
            end if;

            op_i_mem_out <= op_i_mem(op_i_mem_raddr);
        end if;
    end process;

    -- op_q ram synth
    PROC_OP_Q_RAM : process (clk)
    begin
        if rising_edge(clk) then
            if (op_q_mem_we = '1') then
                op_q_mem(op_q_mem_waddr) <= op_q_mem_in;
            end if;

            op_q_mem_out <= op_q_mem(op_q_mem_raddr);
        end if;
    end process;

    -- op ram shift input generation
    PROC_OP_SHIFT : process (clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                op_i_shift_out <= (others => '0');
                op_q_shift_out <= (others => '0');
            else
                op_i_shift_out <= op_i_mem_out((C_NUM_MACS * C_INPUT_WIDTH - 1) downto ((C_NUM_MACS - 1) * C_INPUT_WIDTH));
                op_q_shift_out <= op_q_mem_out((C_NUM_MACS * C_INPUT_WIDTH - 1) downto ((C_NUM_MACS - 1) * C_INPUT_WIDTH));
            end if;
        end if;
    end process;

    -- control logic signals
    dout_valid  <= dout_valid_r;
    stall       <= dout_valid_r and not dout_ready;
    din_ready   <= not (busy or stall);
    dout_data_i <= std_logic_vector(resize(shift_right(dout_acc_i_r, C_ACCUMULATOR_DISCARD_LSB), C_OUTPUT_WIDTH));
    dout_data_q <= std_logic_vector(resize(shift_right(dout_acc_q_r, C_ACCUMULATOR_DISCARD_LSB), C_OUTPUT_WIDTH));
    next_busy   <= din_valid and (not stall);
    op_i_shift_in <= din_data_i when (index = 0) else op_i_shift_out;
    op_q_shift_in <= din_data_q when (index = 0) else op_q_shift_out;

    -- coeff rom io
    coeff_mem_raddr <= index_next;

    -- op_i ram io
    op_i_mem_raddr <= index_next;
    op_i_mem_we    <= (busy or next_busy) and not reset;
    op_i_mem_waddr <= index;
    op_i_mem_in    <= op_i_mem_out(((C_NUM_MACS - 1) * C_INPUT_WIDTH - 1) downto 0) & op_i_shift_in;

    -- op_q ram io
    op_q_mem_raddr <= index_next;
    op_q_mem_we    <= (busy or next_busy) and not reset;
    op_q_mem_waddr <= index;
    op_q_mem_in    <= op_q_mem_out(((C_NUM_MACS - 1) * C_INPUT_WIDTH - 1) downto 0) & op_q_shift_in;
end architecture;
