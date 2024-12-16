library IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY siren IS
    PORT (
        clk_50MHz : IN STD_LOGIC; -- system clock (50 MHz)
        hexclk_50MHz : IN STD_LOGIC;
        dac_MCLK : OUT STD_LOGIC; -- outputs to PMODI2L DAC
        dac_LRCK : OUT STD_LOGIC;
        dac_SCLK : OUT STD_LOGIC;
        dac_SDIN : OUT STD_LOGIC
    );
END siren;

ARCHITECTURE Behavioral OF siren IS
    CONSTANT lo_tone : UNSIGNED (13 DOWNTO 0) := to_unsigned(344, 14); -- lower limit of siren = 256 Hz
    CONSTANT hi_tone : UNSIGNED (13 DOWNTO 0) := to_unsigned(687, 14); -- upper limit of siren = 512 Hz
    SIGNAL wail_speed : UNSIGNED (15 DOWNTO 0) := (OTHERS => '0'); -- sets wailing speed, initialized
    SIGNAL tcount : UNSIGNED (19 DOWNTO 0) := (OTHERS => '0'); -- timing counter
    SIGNAL data_L, data_R : SIGNED (15 DOWNTO 0); -- 16-bit signed audio data
    SIGNAL dac_load_L, dac_load_R : STD_LOGIC; -- timing pulses to load DAC shift reg.
    SIGNAL slo_clk, sclk, audio_CLK : STD_LOGIC;
    SIGNAL kp_clk, kp_hit, sm_clk : STD_LOGIC;
    SIGNAL kp_value : STD_LOGIC_VECTOR (3 DOWNTO 0);
    SIGNAL KB_col : STD_LOGIC_VECTOR (4 DOWNTO 1); -- keypad column pins
    SIGNAL KB_row : STD_LOGIC_VECTOR (4 DOWNTO 1); -- keypad row pins
    SIGNAL cnt : std_logic_vector(20 DOWNTO 0);

    TYPE state IS (ENTER_NUM, NUM_RELEASE);
    SIGNAL pr_state, nx_state : state;

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

    COMPONENT keypad IS
        PORT (
            samp_ck : IN STD_LOGIC;
            col : OUT STD_LOGIC_VECTOR (4 DOWNTO 1);
            row : IN STD_LOGIC_VECTOR (4 DOWNTO 1);
            value : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
            hit : OUT STD_LOGIC
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

	ck_proc : PROCESS (hexclk_50MHz)
	BEGIN
		IF rising_edge(hexclk_50MHz) THEN -- on rising edge of clock
			cnt <= cnt + 1; -- increment counter
		END IF;
	END PROCESS;
	
	kp_clk <= cnt(15); -- keypad interrogation clock
	sm_clk <= cnt(20); -- state machine clock

    -- Process to set up timing signals using a 20-bit counter
    tim_pr : PROCESS
    BEGIN
        WAIT UNTIL rising_edge(clk_50MHz);
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
    END PROCESS;

    -- State machine for keypad control
    drum_kit : PROCESS (kp_hit, kp_value, pr_state)
    BEGIN
        CASE pr_state IS
            WHEN ENTER_NUM =>
                IF kp_hit = '1' THEN
                    IF kp_value = "0001" THEN
                        -- Bass
                        wail_speed <= resize(unsigned(wail_speed * to_unsigned(1, 16)), 16);
                    ELSIF kp_value = "0010" THEN
                        -- Snare
                        wail_speed <= resize(unsigned(wail_speed * to_unsigned(10, 16)), 16);
                    ELSIF kp_value = "0011" THEN
                        -- Hi-hat
                        wail_speed <= resize(unsigned(wail_speed * to_unsigned(50, 16)), 16);
                    END IF;
                ELSIF kp_hit = '0' THEN
                    nx_state <= NUM_RELEASE;
                END IF;

            WHEN NUM_RELEASE =>
                IF kp_hit = '1' THEN
                    nx_state <= ENTER_NUM;
                END IF;
        END CASE;

        -- Update current state
        pr_state <= nx_state;
    END PROCESS;

    -- Derived clock signals
    dac_MCLK <= NOT tcount(1); -- DAC master clock (12.5 MHz)
    audio_CLK <= tcount(9); -- audio sampling rate (48.8 kHz)
    dac_LRCK <= audio_CLK; -- Left/right channel clock
    sclk <= tcount(4); -- Serial data clock (1.56 MHz)
    dac_SCLK <= sclk;
    slo_clk <= tcount(19); -- Clock for wailing tone (47.6 Hz)

    -- Instantiate DAC interface
    dac : dac_if
    PORT MAP(
        SCLK => sclk,
        L_start => dac_load_L,
        R_start => dac_load_R,
        L_data => data_L,
        R_data => data_R,
        SDATA => dac_SDIN
    );

    -- Instantiate keypad
    kp1 : keypad
    PORT MAP(
        samp_ck => kp_clk,
        col => KB_col,
        row => KB_row,
        value => kp_value,
        hit => kp_hit
    );

    -- Instantiate wail component
    w1 : wail
    PORT MAP(
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
