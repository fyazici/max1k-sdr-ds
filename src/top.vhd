library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
    port (
        -- CLOCKS
        clk_12 : in std_logic;
        clk_x  : in std_logic;

        -- LEDS
        led : out std_logic_vector(7 downto 0);

        -- BUTTONS
        user_btn : in std_logic;

        -- ACCELEROMETER
        sen_int1 : in std_logic;
        sen_int2 : in std_logic;
        sen_sdi  : out std_logic;
        sen_sdo  : in std_logic;
        sen_spc  : out std_logic;
        sen_cs   : out std_logic;

        -- SDRAM
        sdram_a   : out std_logic_vector(13 downto 0);
        sdram_ba  : out std_logic_vector(1 downto 0);
        sdram_clk : out std_logic;
        sdram_cke : out std_logic;
        sdram_ras : out std_logic;
        sdram_cas : out std_logic;
        sdram_we  : out std_logic;
        sdram_cs  : out std_logic;
        sdram_dq  : inout std_logic_vector(15 downto 0);
        sdram_dqm : out std_logic_vector(1 downto 0);

        -- EXT FLASH
        flash_cs  : out std_logic;
        flash_clk : out std_logic;
        flash_di  : inout std_logic;
        flash_do  : in std_logic;

        -- DUAL FUNCTION ADC INPUTS (NOT AVAILABLE IF BANK 1A USED FOR ADC)
        -- adc_ain: in std_logic;

        -- DIGITAL USER IO
        user_dio : inout std_logic_vector(14 downto 0);

        -- PMOD IO
        pio : inout std_logic_vector(7 downto 0);

        -- FT2232H UART
        ftdi_tx : in std_logic;
        ftdi_rx : out std_logic
    );
end entity top;

architecture rtl of top is

    constant C_ADC_SAMPLE_RATE : integer := 1_000_000;
    constant C_OUT_SAMPLE_RATE : integer := 20_000;
    constant C_DSP_CLOCK_HZ    : integer := 70_000_000;
    constant C_UART_BAUD_RATE  : integer := 1_000_000;

    constant C_DECIM_FACTOR           : integer          := C_ADC_SAMPLE_RATE / C_OUT_SAMPLE_RATE;
    constant C_DSP_OVERSAMPLE_FACTOR  : integer          := C_DSP_CLOCK_HZ / C_ADC_SAMPLE_RATE;
    constant C_UART_OVERSAMPLE_FACTOR : integer          := C_DSP_CLOCK_HZ / C_UART_BAUD_RATE;
    constant C_FIR_COEFF_IF           : std_logic_vector := x"00340038003C004000440048004C005100550059005E00620066006B006F00730078007C008000840087008B008E009200950097009A009C009E00A000A100A200A200A200A200A1009F009D009B009800940090008B0086007F007800710068005F0055004A003F0032002500170007FFF8FFE7FFD6FFC3FFAFFF9AFF85FF6EFF56FF3EFF24FF0AFEEFFED2FEB5FE97FE78FE58FE37FE15FDF3FDD0FDACFD87FD62FD3CFD15FCEEFCC6FC9EFC75FC4CFC22FBF9FBCFFBA5FB7AFB50FB26FAFCFAD2FAA9FA7FFA57FA2EFA07F9E0F9B9F994F970F94CF92AF909F8E9F8CBF8AEF893F87AF863F84DF83AF829F81AF80DF803F7FCF7F7F7F5F7F6F7FAF801F80CF819F82BF83FF858F874F894F8B8F8E0F90CF93CF970F9A9F9E6FA28FA6EFAB9FB09FB5EFBB7FC15FC78FCE0FD4DFDC0FE37FEB3FF35FFBB004600D7016D020802A9034E03F904A9055D061706D607990862092F0A010AD80BB30C930D770E600F4C103D1132122A13271427152A1631173B184819571A6A1B7F1C971DB01ECC1FEA2109222A234C246F259326B727DD29022A272B4D2C722D962EBA2FDC30FD321D333B345735713689379E38B139C03ACC3BD43CD93DDA3ED73FD040C441B3429E43834463453E461346E247AA486D492949DF4A8E4B364BD84C724D044D904E134E8F4F044F704FD55031508550D151155151518451AE51D151EA51FB5204520451FB51EA51D151AE51845151511550D1508550314FD54F704F044E8F4E134D904D044C724BD84B364A8E49DF4929486D47AA46E24613453E44634383429E41B340C43FD03ED73DDA3CD93BD43ACC39C038B1379E368935713457333B321D30FD2FDC2EBA2D962C722B4D2A27290227DD26B72593246F234C222A21091FEA1ECC1DB01C971B7F1A6A19571848173B1631152A14271327122A1132103D0F4C0E600D770C930BB30AD80A01092F0862079906D60617055D04A903F9034E02A90208016D00D70046FFBBFF35FEB3FE37FDC0FD4DFCE0FC78FC15FBB7FB5EFB09FAB9FA6EFA28F9E6F9A9F970F93CF90CF8E0F8B8F894F874F858F83FF82BF819F80CF801F7FAF7F6F7F5F7F7F7FCF803F80DF81AF829F83AF84DF863F87AF893F8AEF8CBF8E9F909F92AF94CF970F994F9B9F9E0FA07FA2EFA57FA7FFAA9FAD2FAFCFB26FB50FB7AFBA5FBCFFBF9FC22FC4CFC75FC9EFCC6FCEEFD15FD3CFD62FD87FDACFDD0FDF3FE15FE37FE58FE78FE97FEB5FED2FEEFFF0AFF24FF3EFF56FF6EFF85FF9AFFAFFFC3FFD6FFE7FFF80007001700250032003F004A0055005F006800710078007F0086008B009000940098009B009D009F00A100A200A200A200A200A100A0009E009C009A009700950092008E008B008700840080007C00780073006F006B00660062005E005900550051004C004800440040003C00380034";
    constant C_FIR_COEFF_WIDTH_IF     : integer          := 16;
    constant C_FIR_NUM_TAPS_IF        : integer          := 512;
    constant C_FIR_NUM_MAC_IF         : integer          := 8;

    constant C_MIXER_THROW_LSB  : integer := 11;
    constant C_FIR_IF_THROW_LSB : integer := 19;
    constant C_DEMOD_THROW_LSB  : integer := 7;

    signal clk_adc    : std_logic;
    signal clk_dsp    : std_logic;
    signal clk_nco    : std_logic;
    signal pll_locked : std_logic;

    signal reset   : std_logic := '1';
    signal reset_n : std_logic := '0';

    signal sample_valid : std_logic;
    signal sample_ready : std_logic;
    signal sample_data  : std_logic_vector(11 downto 0);

    signal lo_phase_inc : std_logic_vector(31 downto 0);
    signal lo_data_i    : std_logic_vector(15 downto 0);
    signal lo_data_q    : std_logic_vector(15 downto 0);

    signal mixer_valid_w  : std_logic;
    signal mixer_ready_w  : std_logic;
    signal mixer_data_i_w : std_logic_vector(31 downto 0);
    signal mixer_data_q_w : std_logic_vector(31 downto 0);

    signal mixer_valid  : std_logic;
    signal mixer_ready  : std_logic;
    signal mixer_data_i : std_logic_vector(15 downto 0);
    signal mixer_data_q : std_logic_vector(15 downto 0);

    signal fir_if_valid_w  : std_logic;
    signal fir_if_ready_w  : std_logic;
    signal fir_if_data_i_w : std_logic_vector(31 downto 0);
    signal fir_if_data_q_w : std_logic_vector(31 downto 0);

    signal fir_if_valid  : std_logic;
    signal fir_if_ready  : std_logic;
    signal fir_if_data_i : std_logic_vector(15 downto 0);
    signal fir_if_data_q : std_logic_vector(15 downto 0);

    signal demod_valid_w : std_logic;
    signal demod_ready_w : std_logic;
    signal demod_data_w  : std_logic_vector(15 downto 0);

    signal demod_valid : std_logic;
    signal demod_ready : std_logic;
    signal demod_data  : std_logic_vector(7 downto 0);

    signal uart_tx_valid : std_logic;
    signal uart_tx_ready : std_logic;
    signal uart_tx_data  : std_logic_vector(7 downto 0);

    signal uart_rx_data  : std_logic_vector(7 downto 0);
    signal uart_rx_valid : std_logic;
    signal uart_rx_ready : std_logic;

    signal atten_mixer  : std_logic_vector(4 downto 0);
    signal atten_fir_if : std_logic_vector(4 downto 0);
    signal atten_demod  : std_logic_vector(3 downto 0);

    signal param_led : std_logic;
begin

    ----------------------
    -- Clock generation --
    ----------------------
    U_PLL : entity work.pll_0
        port map(
            areset => '0',
            inclk0 => clk_12,
            c0     => clk_adc, -- 2M adc clock, phase aligned
            c1     => clk_dsp, -- 70M dsp clock, phase aligned
            c2     => clk_nco, -- 1M nco clock, phase aligned
            locked => pll_locked
        );

    ----------------------
    -- Reset controller --
    ----------------------
    U_RESET_CTL : entity work.reset_ctl
        generic map(
            C_INIT_RESET_CYCLES => 100
        )
        port map(
            slowest_sync_clk => clk_nco,
            pll_locked       => pll_locked,
            ext_reset        => '0',

            sync_reset   => reset,
            sync_reset_n => reset_n
        );

    -------------------------------------
    -- ADC Controller (+ ADC instance) --
    -------------------------------------
    U_ADC_CTL : entity work.adc_ctl
        generic map(
            C_ADC_CHANNEL => 2,
            C_OUT_WIDTH   => 12
        )
        port map(
            clk_adc    => clk_adc,
            pll_locked => pll_locked,

            clk     => clk_dsp,
            reset_n => reset_n,

            sample_valid => sample_valid,
            sample_ready => sample_ready,
            sample_data  => sample_data
        );

    --------------------------
    -- Local oscillator NCO --
    --------------------------
    U_NCO_LO : entity work.dsp_nco
        generic map(
            C_PHA_WIDTH => 32,
            C_ANG_WIDTH => 14,
            C_OUT_WIDTH => 16
        )
        port map(
            clk   => clk_nco,
            reset => reset,

            pha_en  => '1',
            pha_inc => lo_phase_inc,

            dout_i => lo_data_i,
            dout_q => lo_data_q
        );

    -----------
    -- Mixer --
    -----------
    U_MIXER : entity work.dsp_mixer
        generic map(
            C_RF_WIDTH        => 12,
            C_LO_WIDTH        => 16,
            C_OUT_DISCARD_LSB => 0,
            C_OUT_WIDTH       => 32
        )
        port map(
            clk   => clk_dsp,
            reset => reset,

            din_valid => sample_valid,
            din_ready => sample_ready,
            din_data  => sample_data,

            lo_data_i => lo_data_i,
            lo_data_q => lo_data_q,

            dout_valid  => mixer_valid_w,
            dout_ready  => mixer_ready_w,
            dout_data_i => mixer_data_i_w,
            dout_data_q => mixer_data_q_w
        );

    -----------------------------
    -- Mixer output attenuator --
    -----------------------------
    U_MIXER_ATTEN : entity work.dsp_atten
        generic map(
            C_NUM_STAGES => 5,
            C_IN_WIDTH   => 32,
            C_OUT_WIDTH  => 16
        )
        port map(
            clk   => clk_dsp,
            reset => reset,

            shift_amount => atten_mixer,
            shift_arith  => '1',

            din_valid  => mixer_valid_w,
            din_ready  => mixer_ready_w,
            din_data_i => mixer_data_i_w,
            din_data_q => mixer_data_q_w,

            dout_valid  => mixer_valid,
            dout_ready  => mixer_ready,
            dout_data_i => mixer_data_i,
            dout_data_q => mixer_data_q
        );

    -----------------------
    -- IF Lowpass filter --
    -----------------------
    U_FIR_IF : entity work.dsp_fir
        generic map(
            C_COEFF_INIT              => C_FIR_COEFF_IF,
            C_COEFF_WIDTH             => C_FIR_COEFF_WIDTH_IF,
            C_NUM_TAPS                => C_FIR_NUM_TAPS_IF,
            C_NUM_MACS                => C_FIR_NUM_MAC_IF,
            C_REGISTERED_MAC          => TRUE,
            C_INPUT_WIDTH             => 16,
            C_MULTIPLIER_DISCARD_LSB  => 0,
            C_ACCUMULATOR_WIDTH       => 36,
            C_ACCUMULATOR_DISCARD_LSB => 4,
            C_OUTPUT_WIDTH            => 32
        )
        port map(
            clk   => clk_dsp,
            reset => reset,

            din_valid  => mixer_valid,
            din_ready  => mixer_ready,
            din_data_i => mixer_data_i,
            din_data_q => mixer_data_q,

            dout_valid  => fir_if_valid_w,
            dout_ready  => fir_if_ready_w,
            dout_data_i => fir_if_data_i_w,
            dout_data_q => fir_if_data_q_w
        );

    ------------------------------
    -- Filter output attenuator --
    ------------------------------
    U_FIR_IF_ATTEN : entity work.dsp_atten
        generic map(
            C_NUM_STAGES => 5,
            C_IN_WIDTH   => 32,
            C_OUT_WIDTH  => 16
        )
        port map(
            clk   => clk_dsp,
            reset => reset,

            shift_amount => atten_fir_if,
            shift_arith  => '1',

            din_valid  => fir_if_valid_w,
            din_ready  => fir_if_ready_w,
            din_data_i => fir_if_data_i_w,
            din_data_q => fir_if_data_q_w,

            dout_valid  => fir_if_valid,
            dout_ready  => fir_if_ready,
            dout_data_i => fir_if_data_i,
            dout_data_q => fir_if_data_q
        );

    ----------------------------------------------
    -- Demodulator (AM envelope by square root) --
    ----------------------------------------------
    U_DEMOD : entity work.dsp_cplx_abs
        generic map(
            C_IN_WIDTH        => 16,
            C_OUT_DISCARD_LSB => 0, -- actual result is in signed 17-bits
            C_OUT_WIDTH       => 16
        )
        port map(
            clk   => clk_dsp,
            reset => reset,

            din_valid   => fir_if_valid,
            din_ready   => fir_if_ready,
            din_data_re => fir_if_data_i,
            din_data_im => fir_if_data_q,

            dout_valid => demod_valid_w,
            dout_ready => demod_ready_w,
            dout_data  => demod_data_w
        );

    -----------------------------------
    -- Demodulator output attenuator --
    -----------------------------------
    U_DEMOD_ATTEN : entity work.dsp_atten
        generic map(
            C_NUM_STAGES => 4,
            C_IN_WIDTH   => 16,
            C_OUT_WIDTH  => 8
        )
        port map(
            clk   => clk_dsp,
            reset => reset,

            shift_amount => atten_demod,
            shift_arith  => '0',

            din_valid  => demod_valid_w,
            din_ready  => demod_ready_w,
            din_data_i => demod_data_w,
            din_data_q => (others => '0'),

            dout_valid  => demod_valid,
            dout_ready  => demod_ready,
            dout_data_i => demod_data,
            dout_data_q => open
        );

    ----------------------------
    -- DSP to Audio Decimator --
    ----------------------------
    U_DECIM : entity work.dsp_decim
        generic map(
            C_INPUT_WIDTH  => 8,
            C_DECIM_FACTOR => C_DECIM_FACTOR
        )
        port map(
            clk   => clk_dsp,
            reset => reset,

            din_valid => demod_valid,
            din_ready => demod_ready,
            din_data  => demod_data,

            dout_valid => uart_tx_valid,
            dout_ready => uart_tx_ready,
            dout_data  => uart_tx_data
        );

    -------------
    -- UART TX --
    -------------
    U_UART_TX : entity work.uart_tx
        generic map(
            C_OVERSAMPLE_FACTOR => C_UART_OVERSAMPLE_FACTOR
        )
        port map(
            clk   => clk_dsp,
            reset => reset,

            din_valid => uart_tx_valid,
            din_ready => uart_tx_ready,
            din_data  => uart_tx_data,

            tx => ftdi_rx
        );

    -------------
    -- UART RX --
    -------------
    U_UART_RX : entity work.uart_rx
        generic map(
            C_OVERSAMPLE_FACTOR => C_UART_OVERSAMPLE_FACTOR
        )
        port map(
            clk   => clk_dsp,
            reset => reset,

            rx => ftdi_tx,

            dout_valid => uart_rx_valid,
            dout_ready => uart_rx_ready,
            dout_data  => uart_rx_data
        );

    --------------------------
    -- Parameter Controller --
    --------------------------
    U_PARAM_CTL : entity work.param_ctl
        port map(
            clk   => clk_dsp,
            reset => reset,

            din_valid => uart_rx_valid,
            din_ready => uart_rx_ready,
            din_data  => uart_rx_data,

            lo_phase_inc => lo_phase_inc,
            atten_mixer  => atten_mixer,
            atten_fir_if => atten_fir_if,
            atten_demod  => atten_demod,
            led          => param_led
        );

    --------------------------
    -- Debug output aligner --
    --------------------------
    U_DBG_ALIGNER : entity work.dbg_aligner
        port map(
            clk   => clk_dsp,
            reset => reset,

            sample_valid => sample_valid,
            sample_ready => sample_ready,
            sample_data  => sample_data,
            lo_data_i    => lo_data_i,
            lo_data_q    => lo_data_q,

            mixer_valid  => mixer_valid,
            mixer_ready  => mixer_ready,
            mixer_data_i => mixer_data_i,
            mixer_data_q => mixer_data_q,

            if_valid  => fir_if_valid,
            if_ready  => fir_if_ready,
            if_data_i => fir_if_data_i,
            if_data_q => fir_if_data_q,

            demod_valid => demod_valid,
            demod_ready => demod_ready,
            demod_data  => demod_data,

            -- debug outputs to be captured by SignalTap when dbg_valid=1
            dbg_valid        => open,
            dbg_sample_data  => open,
            dbg_lo_data_i    => open,
            dbg_lo_data_q    => open,
            dbg_mixer_data_i => open,
            dbg_mixer_data_q => open,
            dbg_if_data_i    => open,
            dbg_if_data_q    => open,
            dbg_demod_data   => open
        );

    ----------------
    -- Debug leds --
    ----------------
    led(0)          <= reset;
    led(1)          <= param_led;
    led(7 downto 2) <= uart_tx_data(5 downto 0);

end architecture;
