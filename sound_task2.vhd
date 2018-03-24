-- Filename: sound_task2.vhd
-- Author 1: Sheung Yau (Gary) Chung
-- Author 1 Student #: 301236546
-- Author 2: Yu Xuan (Shawn) Wang
-- Author 2 Student #: 301227972
-- Group Number: 40
-- Lab Section: LA04
-- Lab: ASB 10808
-- Task Completed: 2, 3, Challenge
-- Date: March 9, 2018 
------------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;

ENTITY sound IS
	PORT (CLOCK_50,CLOCK2_50, AUD_DACLRCK, AUD_ADCLRCK, AUD_BCLK,AUD_ADCDAT			:IN STD_LOGIC;
			KEY																:IN STD_LOGIC_VECTOR(3 DOWNTO 0);
			SW																	:IN STD_LOGIC_VECTOR(17 downto 0);			
			I2C_SDAT															:INOUT STD_LOGIC;
			I2C_SCLK,AUD_DACDAT,AUD_XCK								:OUT STD_LOGIC);
END sound;

ARCHITECTURE Behavior OF sound IS

													  
   -- CODEC Cores.  These will be included in your design as is
	
	COMPONENT clock_generator
		PORT(	CLOCK2_50														:IN STD_LOGIC;
		    	reset															:IN STD_LOGIC;
				AUD_XCK														:OUT STD_LOGIC);
	END COMPONENT;

	COMPONENT audio_and_video_config
		PORT(	CLOCK_50,reset												:IN STD_LOGIC;
		    	I2C_SDAT														:INOUT STD_LOGIC;
				I2C_SCLK														:OUT STD_LOGIC);
	END COMPONENT;
	
	COMPONENT audio_codec
		PORT(	CLOCK_50,reset,read_s,write_s							:IN STD_LOGIC;
				writedata_left, writedata_right						:IN STD_LOGIC_VECTOR(23 DOWNTO 0);
				AUD_ADCDAT,AUD_BCLK,AUD_ADCLRCK,AUD_DACLRCK		:IN STD_LOGIC;
				read_ready, write_ready									:OUT STD_LOGIC;
				readdata_left, readdata_right							:OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
				AUD_DACDAT													:OUT STD_LOGIC);
	END COMPONENT;


	-- local signals and constants.  You will want to add some stuff here
	constant MAX_P_AMPLITUDE : std_logic_vector(23 downto 0) := std_logic_vector(to_unsigned(2**13,24));--"000000000000000000000010";--(2 => '1', others => '0');
	constant MAX_N_AMPLITUDE : std_logic_vector(23 downto 0) := std_logic_vector(to_unsigned(-2**13,24));
	signal reset, read_s, write_s, read_ready, write_ready  : std_logic;
	signal writedata_left, writedata_right, readdata_left, readdata_right : STD_LOGIC_VECTOR(23 DOWNTO 0);
	
BEGIN

   -- The audio core requires an active high reset signal

	reset <= NOT(KEY(3));
	
	-- we will never read from the microphone in this lab, so we might as well set read_s to 0.
	
	read_s <= '0';

	-- instantiate the parts of the audio core. 
	
	my_clock_gen: clock_generator PORT MAP (CLOCK2_50, reset, AUD_XCK);
	cfg: audio_and_video_config PORT MAP (CLOCK_50, reset, I2C_SDAT, I2C_SCLK);
	codec: audio_codec PORT MAP(CLOCK_50,reset,read_s,write_s,writedata_left, writedata_right,AUD_ADCDAT,AUD_BCLK,AUD_ADCLRCK,AUD_DACLRCK,read_ready, write_ready,readdata_left, readdata_right,AUD_DACDAT);

	-- the rest of your code goes here
	MONOTONE : process (CLOCK_50, reset)
	-- states
	type stateType is (waiting, sending);
	variable curr_state: stateType := waiting;
	variable curr_dir : std_logic := '1';		-- 1: negative; 0: positive
	variable cnt : integer range 0 to 168 := 0;	-- 336/2 = 168. 336 is target sample rate for 262Hz
	
	begin
		if reset = '1' then
			curr_state := waiting;
		elsif rising_edge(CLOCK_50) then
			case curr_state is 
			when waiting =>
				if write_ready = '1' then
					if curr_dir = '0' then
						writedata_left  <= MAX_P_AMPLITUDE;
						writedata_right <= MAX_P_AMPLITUDE;
					else
						writedata_left  <= MAX_N_AMPLITUDE;
						writedata_right <= MAX_N_AMPLITUDE;
					end if;
					write_s <= '1';
					curr_state := sending;
					-- update cnter
					if cnt < 168 then
						cnt := cnt + 1;
					else
						cnt := 0;
						curr_dir := not(curr_dir);
					end if;
				else
					curr_state := waiting;
				end if;
			when sending =>
				if write_ready = '0' then
					write_s <= '0';
					curr_state := waiting;
				else
					curr_state := sending;
				end if;
			end case;
		end if;
	end process;
end Behavior;