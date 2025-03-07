library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity nco_0 is
    port (
        clk       : in  std_logic                     := 'X';             -- clk
        clken     : in  std_logic                     := 'X';             -- clken
        phi_inc_i : in  std_logic_vector(31 downto 0) := (others => 'X'); -- phi_inc_i
        fsin_o    : out std_logic_vector(15 downto 0);                    -- fsin_o
        fcos_o    : out std_logic_vector(15 downto 0);                    -- fcos_o
        out_valid : out std_logic;                                        -- out_valid
        reset_n   : in  std_logic                     := 'X'              -- reset_n
    );
end entity;

architecture rtl of nco_0 is
    signal sin_o : boolean;
    signal cos_o : boolean;

    constant out_high : std_logic_vector := std_logic_vector(to_signed(32767, 16));
    constant out_low : std_logic_vector := std_logic_vector(to_signed(-32767, 16));
begin
    PROC_OSC : process
    begin
        cos_o <= true;
        sin_o <= true;

        wait until rising_edge(clk);

        L_OSC : loop
            wait for 500 ns;
            cos_o <= not cos_o;
            wait for 500 ns;
            sin_o <= not sin_o;
        end loop; -- L_OSC
    end process;

    fsin_o <= out_high when sin_o else out_low;
    fcos_o <= out_high when cos_o else out_low;
    out_valid <= '1';
    

end architecture;