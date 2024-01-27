
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dsp_cplx_abs is
    generic (
        C_IN_WIDTH        : positive;
        C_OUT_DISCARD_LSB : natural;
        C_OUT_WIDTH       : positive
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;

        din_valid   : in std_logic;
        din_ready   : out std_logic;
        din_data_re : in std_logic_vector((C_IN_WIDTH - 1) downto 0);
        din_data_im : in std_logic_vector((C_IN_WIDTH - 1) downto 0);

        dout_valid : out std_logic;
        dout_ready : in std_logic;
        dout_data  : out std_logic_vector((C_OUT_WIDTH - 1) downto 0)
    );
end entity;

architecture rtl of dsp_cplx_abs is
    constant C_RES_WIDTH : natural := C_IN_WIDTH;
    constant C_SQ_WIDTH  : natural := C_RES_WIDTH * 2 + 1;
    constant C_NUM_ITERS : natural := C_RES_WIDTH;

    signal dout_valid_r : std_logic;
    signal din_ready_r  : std_logic;

    -- acc = re^2 + im^2
    -- abs(re + j*im) = sqrt(acc)
    signal acc : unsigned((C_SQ_WIDTH - 1) downto 0);

    type state_t is (S_IDLE, S_SQ_IM, S_ITER, S_END);
    signal state : state_t;

    -- current iteration number
    signal iter : natural range 0 to (C_NUM_ITERS - 1);

    -- result reg
    signal result : unsigned((C_RES_WIDTH - 1) downto 0);
    -- output mirror reg to prevent unnecessary toggling
    signal result_r : unsigned((C_RES_WIDTH - 1) downto 0);

    -- for discard lsb
    signal result_pre : unsigned((C_RES_WIDTH - 1) downto 0);

    signal sq_in  : signed(C_RES_WIDTH downto 0);
    signal sq_out : unsigned((C_SQ_WIDTH - 1) downto 0);

    signal din_data_im_r : std_logic_vector((C_IN_WIDTH - 1) downto 0);
begin
    -- use a single multiplier
    sq_out <= unsigned(resize(sq_in * sq_in, C_SQ_WIDTH));

    PROC_FSM : process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                din_ready_r  <= '1';
                dout_valid_r <= '0';

                result        <= (others => '0');
                result_r      <= (others => '0');
                acc           <= (others => '0');
                din_data_im_r <= (others => '0');
                iter          <= 0;
                state         <= S_IDLE;
            else
                case (state) is
                    when S_IDLE =>
                        if (din_valid = '1' and din_ready_r = '1') then
                            din_ready_r   <= '0';
                            din_data_im_r <= din_data_im;

                            acc    <= sq_out;
                            state  <= S_SQ_IM;
                            iter   <= C_NUM_ITERS - 1;
                            result <= (others => '0');

                            result(C_NUM_ITERS - 1) <= '1';
                        end if;
                    when S_SQ_IM =>
                        acc   <= acc + sq_out;
                        state <= S_ITER;
                    when S_ITER =>
                        if (iter = C_OUT_DISCARD_LSB) then
                            state        <= S_END;
                            dout_valid_r <= '1';
                            result_r     <= result;
                        else
                            result(iter - 1) <= '1';
                            iter             <= iter - 1;
                        end if;

                        if (acc < sq_out) then
                            result(iter) <= '0';
                            if (iter = C_OUT_DISCARD_LSB) then
                                result_r(iter) <= '0';
                            end if;
                        end if;
                    when S_END =>
                        if (dout_valid_r = '1' and dout_ready = '1') then
                            dout_valid_r <= '0';
                            din_ready_r  <= '1';
                            state        <= S_IDLE;
                        end if;
                    when others =>
                        state <= S_IDLE;
                end case;
            end if;
        end if;
    end process;

    process (state, din_data_re, din_data_im_r, result)
    begin
        case (state) is
            when S_IDLE =>
                sq_in <= resize(signed(din_data_re), sq_in'length);
            when S_SQ_IM =>
                sq_in <= resize(signed(din_data_im_r), sq_in'length);
            when S_ITER =>
                sq_in <= signed('0' & result);
            when others      =>
                sq_in <= (others => '0');
        end case;
    end process;

    dout_valid <= dout_valid_r;
    din_ready  <= din_ready_r;
    result_pre <= resize(shift_right(result_r, C_OUT_DISCARD_LSB), C_RES_WIDTH);
    dout_data  <= std_logic_vector(result_pre(C_OUT_WIDTH - 1 downto 0));

end architecture;
