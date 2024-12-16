LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY drum IS
    PORT (
        clk : IN STD_LOGIC;
        enable : IN STD_LOGIC;
        lo_pitch : IN UNSIGNED(13 DOWNTO 0);
        hi_pitch : IN UNSIGNED(13 DOWNTO 0);
        audio_out : OUT SIGNED(15 DOWNTO 0)
    );
END drum;

ARCHITECTURE Behavioral OF drum IS
    SIGNAL curr_pitch : UNSIGNED(13 DOWNTO 0) := (OTHERS => '0');
    SIGNAL tone_active : SIGNED(15 DOWNTO 0) := (OTHERS => '0');
BEGIN

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF enable = '1' THEN
                curr_pitch <= lo_pitch; 
                tone_active <= to_signed(10000, 16); 
            ELSE
                tone_active <= (OTHERS => '0'); 
            END IF;
        END IF;
    END PROCESS;

    audio_out <= tone_active;

END Behavioral;