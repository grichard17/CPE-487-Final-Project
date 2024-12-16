library IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY drumkit IS
    PORT (
        clk_50MHz : IN STD_LOGIC; 
        dac_MCLK : OUT STD_LOGIC; 
        dac_LRCK : OUT STD_LOGIC;
        dac_SCLK : OUT STD_LOGIC;
        dac_SDIN : OUT STD_LOGIC;
        btnc : IN STD_LOGIC; 
        btnu : IN STD_LOGIC; 
        btnl : IN STD_LOGIC
    );
END drumkit;

ARCHITECTURE Behavioral OF drumkit IS
    CONSTANT bass_tone : UNSIGNED (13 DOWNTO 0) := to_unsigned(300, 14); 
    CONSTANT snare_tone : UNSIGNED (13 DOWNTO 0) := to_unsigned(400, 14); 
    CONSTANT hihat_tone : UNSIGNED (13 DOWNTO 0) := to_unsigned(500, 14); 

    SIGNAL tcount : UNSIGNED (19 DOWNTO 0) := (OTHERS => '0'); 
    SIGNAL data_L, data_R : SIGNED (15 DOWNTO 0); 
    SIGNAL bass_audio, snare_audio, hihat_audio : SIGNED (15 DOWNTO 0); 
    SIGNAL dac_load_L, dac_load_R : STD_LOGIC; 
    SIGNAL slo_clk, sclk, audio_CLK : STD_LOGIC;

    COMPONENT dac_if IS
        PORT (
            SCLK : IN STD_LOGIC;
            L_start : IN STD_LOGIC;
            R_start : IN STD_LOGIC;
            L_data : IN SIGNED (15 DOWNTO 0);
            R_data : IN SIGNED (15 DOWNTO 0);
            SDATA : OUT STD_LOGIC
        );
    END COMPONENT;

    COMPONENT wail IS
        PORT (
            lo_pitch : IN UNSIGNED (13 DOWNTO 0);
            hi_pitch : IN UNSIGNED (13 DOWNTO 0);
            wspeed : IN UNSIGNED (7 DOWNTO 0);
            wclk : IN STD_LOGIC;
            audio_clk : IN STD_LOGIC;
            audio_data : OUT SIGNED (15 DOWNTO 0)
        );
    END COMPONENT;

BEGIN
    tim_pr : PROCESS (clk_50MHz)
    BEGIN
        IF rising_edge(clk_50MHz) THEN
            IF (tcount(9 DOWNTO 0) >= X"00F") AND (tcount(9 DOWNTO 0) < X"02E") THEN
                dac_load_L <= '1';
            ELSE
                dac_load_L <= '0';
            END IF;

            IF (tcount(9 DOWNTO 0) >= X"20F") AND (tcount(9 DOWNTO 0) < X"22E") THEN
                dac_load_R <= '1';
            ELSE
                dac_load_R <= '0';
            END IF;
            tcount <= tcount + 1;
        END IF;
    END PROCESS;

    -- Derived clock signals
    dac_MCLK <= NOT tcount(1); 
    audio_CLK <= tcount(9); 
    dac_LRCK <= audio_CLK; 
    sclk <= tcount(4); 
    dac_SCLK <= sclk;
    slo_clk <= tcount(19); 

    dac : dac_if
        PORT MAP (
            SCLK => sclk,
            L_start => dac_load_L,
            R_start => dac_load_R,
            L_data => data_L,
            R_data => data_R,
            SDATA => dac_SDIN
        );

    bass : wail
        PORT MAP (
            lo_pitch => bass_tone,
            hi_pitch => bass_tone,
            wspeed => to_unsigned(0, 8), 
            wclk => slo_clk,
            audio_clk => audio_CLK,
            audio_data => bass_audio
        );

    snare : wail
        PORT MAP (
            lo_pitch => snare_tone,
            hi_pitch => snare_tone,
            wspeed => to_unsigned(0, 8),
            wclk => slo_clk,
            audio_clk => audio_CLK,
            audio_data => snare_audio
        );

    -- Instantiate Hi-Hat
    hihat : wail
        PORT MAP (
            lo_pitch => hihat_tone,
            hi_pitch => hihat_tone,
            wspeed => to_unsigned(0, 8), 
            wclk => slo_clk,
            audio_clk => audio_CLK,
            audio_data => hihat_audio
        );

    PROCESS (btnc, btnu, btnl, bass_audio, snare_audio, hihat_audio)
    BEGIN
        IF btnc = '1' THEN
            data_L <= bass_audio; 
        ELSIF btnu = '1' THEN
            data_L <= snare_audio; 
        ELSIF btnl = '1' THEN
            data_L <= hihat_audio; 
        ELSE
            data_L <= (OTHERS => '0'); 
        END IF;

        data_R <= data_L;
    END PROCESS;

END Behavioral;
