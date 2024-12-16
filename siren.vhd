library IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY siren IS
    PORT (
        clk_50MHz : IN STD_LOGIC; -- System clock (50 MHz)
        dac_MCLK : OUT STD_LOGIC; -- Outputs to PMODI2L DAC
        dac_LRCK : OUT STD_LOGIC;
        dac_SCLK : OUT STD_LOGIC;
        dac_SDIN : OUT STD_LOGIC;
        bt_clr : IN STD_LOGIC; -- Calculator "clear" button
        bt_plus : IN STD_LOGIC; -- Calculator "+" button
        bt_eq : IN STD_LOGIC; -- Calculator "=" button
        BTNR : IN STD_LOGIC;
        BTND : IN STD_LOGIC
    );
END siren;

ARCHITECTURE Behavioral OF siren IS
    -- Constants
    CONSTANT lo_tone : UNSIGNED (13 DOWNTO 0) := to_unsigned(344, 14); -- Lower limit of siren (256 Hz)
    CONSTANT hi_tone : UNSIGNED (13 DOWNTO 0) := to_unsigned(687, 14); -- Upper limit of siren (512 Hz)

    -- Signals
    SIGNAL wail_speed : UNSIGNED (15 DOWNTO 0) := (OTHERS => '0'); -- Wailing speed
    SIGNAL tcount : UNSIGNED (19 DOWNTO 0) := (OTHERS => '0'); -- Timing counter
    SIGNAL data_L, data_R : SIGNED (15 DOWNTO 0); -- 16-bit signed audio data
    SIGNAL dac_load_L, dac_load_R : STD_LOGIC; -- Timing pulses to load DAC shift register
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

    -- Process to set up timing signals using a 20-bit counter
    tim_pr : PROCESS (clk_50MHz)
    BEGIN
        IF rising_edge(clk_50MHz) THEN
            -- Generate DAC load pulses
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

            -- Increment timing counter
            tcount <= tcount + 1;
        END IF;
    END PROCESS;

    -- Process to control wail_speed based on button inputs
    drum_kit : PROCESS (clk_50MHz)
    BEGIN
        IF rising_edge(clk_50MHz) THEN
            IF bt_clr = '1' THEN
                -- Bass drum effect
                wail_speed <= to_unsigned(1, 16);
            ELSIF bt_plus = '1' THEN
                -- Snare drum effect
                wail_speed <= to_unsigned(10, 16);
            ELSIF bt_eq = '1' THEN
                -- Hi-hat effect
                wail_speed <= to_unsigned(50, 16);
            ELSE
                -- Default (reset speed)
                wail_speed <= to_unsigned(0, 16);
            END IF;
        END IF;
    END PROCESS;

    -- Derived clock signals
    dac_MCLK <= NOT tcount(1); -- DAC master clock (12.5 MHz)
    audio_CLK <= tcount(9); -- Audio sampling rate (48.8 kHz)
    dac_LRCK <= audio_CLK; -- Left/right channel clock
    sclk <= tcount(4); -- Serial data clock (1.56 MHz)
    dac_SCLK <= sclk;
    slo_clk <= tcount(19); -- Clock for wailing tone (47.6 Hz)

    -- Instantiate DAC interface
    dac : dac_if
        PORT MAP (
            SCLK => sclk,
            L_start => dac_load_L,
            R_start => dac_load_R,
            L_data => data_L,
            R_data => data_R,
            SDATA => dac_SDIN
        );

    -- Instantiate wail component
    w1 : wail
        PORT MAP (
            lo_pitch => lo_tone,
            hi_pitch => hi_tone,
            wspeed => wail_speed(7 DOWNTO 0), -- Truncated to 8 bits
            wclk => slo_clk,
            audio_clk => audio_CLK,
            audio_data => data_L
        );

    -- Duplicate data for right channel
    data_R <= data_L;

END Behavioral;
