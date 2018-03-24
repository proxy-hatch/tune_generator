-- Filename: sound_challenge.vhd
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
			-- SW																	:IN STD_LOGIC_VECTOR(17 downto 0);			
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
	
	
	COMPONENT single_port_rom
		PORT(
		-- addr	: in natural range 0 to 255;
		clk		: in std_logic;		-- clk is 50MHz
		q0		: out std_logic_vector(14 downto 0);
		q1		: out std_logic_vector(14 downto 0);
		q2		: out std_logic_vector(14 downto 0)
	);
	END COMPONENT;

	-- local signals and constants.  
	signal noteIdx0, noteIdx1, noteIdx2 : std_logic_vector(14 downto 0);	-- for reading ROM
	
	type notearr is array(14 downto 0) of integer range 0 to 336; -- e.g.262hz: 88,000 samples/s / 262hz / 2 = 168 samples
	constant max_note_cnt : notearr := (336, 300, 267, 252, 225, 200, 179, 168, 150, 134, 127, 113, 100, 90, 85); -- two octaves
	constant max_amplitude : signed(23 downto 0) := to_signed(2**16,24);	-- 2^16
	signal reset, read_s, write_s, read_ready, write_ready  : std_logic;
	signal writedata_left, writedata_right, readdata_left, readdata_right : std_logic_vector(23 downto 0);
BEGIN
   -- the audio core requires an active high reset signal
	reset <= not(key(3));
	-- we will never read from the microphone in this lab, so we might as well set read_s to 0.
	read_s <= '0';
	-- instantiate the parts of the audio core. 
	my_clock_gen: clock_generator port map (CLOCK2_50, reset, aud_xck);
	cfg: audio_and_video_config port map (CLOCK_50, reset, i2c_sdat, i2c_sclk);
	codec: audio_codec port map(CLOCK_50,reset,read_s,write_s,writedata_left, writedata_right,aud_adcdat,aud_bclk,aud_adclrck,
												aud_daclrck,read_ready, write_ready,readdata_left, readdata_right,aud_dacdat);
	ROM_READ : single_port_rom port map(CLOCK_50, noteIdx0, noteIdx1, noteIdx2);
												
	-- the rest of your code goes here
	ROM_MUSIC : process (clock_50, reset)
		type statetype is (waiting, draining);
		variable curr_state: statetype := waiting;
		variable cnt : notearr := (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
		
		-- +ve / -ve / off (high impedance) for each SW
		type direction is array(14 downto 0) of signed(3 downto 0);	-- can have value of either -1/0/1
		variable curr_dir : direction := ("0000","0000","0000","0000","0000","0000","0000","0000","0000","0000","0000","0000","0000","0000","0000");
		
		-- sum of amplitude for a single sample
		variable sumAmp : signed(3 downto 0);
		variable sumSample : std_logic_vector(23 downto 0);
		variable sumMulResult: signed(27 downto 0);
	begin
		if reset = '1' then
			curr_state := waiting;
			for i in 7 downto 0 loop
				if i = unsigned(noteIdx0) or i = unsigned(noteIdx1) or i = unsigned(noteIdx2) then
					curr_dir(i) := to_signed(-1, curr_dir(i)'length);
					cnt(i) := 0;
				else
					curr_dir(i) := to_signed(0, curr_dir(i)'length);
				end if;
			end loop;
		elsif rising_edge(clock_50) then
			-- check all SWitches for possible turn on/off
			for i in 7 downto 0 loop
				if i = unsigned(noteIdx0) or i = unsigned(noteIdx1) or i = unsigned(noteIdx2) then
					if curr_dir(i) = 0 then	-- time to turn on
						curr_dir(i) := to_signed(-1, curr_dir(i)'length);	-- begin with -ve
						cnt(i) := 0;	-- initialize cnter to 0
					end if;
				elsif curr_dir(i) /= 0 then	-- time to turn off
					curr_dir(i) := to_signed(0, curr_dir(i)'length);
				end if;
			end loop;
			
			-- fsm
			case curr_state is 
			when waiting =>
				if write_ready = '1' then
					sumAmp := curr_dir(to_integer(unsigned(noteIdx0)))+curr_dir(to_integer(unsigned(noteIdx1)))+curr_dir(to_integer(unsigned(noteIdx2)));
					sumMulResult := sumAmp*max_amplitude;
					sumSample := std_logic_vector(sumMulResult(23 downto 0));
					writedata_left <= sumSample;
					writedata_right <= sumSample;
					write_s <= '1';
					curr_state := draining;
						
					-- update cnter
					for i in 7 downto 0 loop
						if curr_dir(i) /= 0 and cnt(i) < max_note_cnt(i) then
						  cnt(i) := cnt(i) + 1;
						elsif curr_dir(i) = -1 then
							cnt(i) := 0;
							curr_dir(i) := to_signed(1, curr_dir(i)'length);
						elsif curr_dir(i) = 1 then
							cnt(i) := 0;
							curr_dir(i) := to_signed(-1, curr_dir(i)'length);
						end if;
					end loop;
				else
					curr_state := waiting;
				end if;

			when draining =>
				if write_ready = '0' then
					write_s <= '0';
					curr_state := waiting;
				else
					curr_state := draining;
				end if;
			end case;
		end if;
	end process;
end Behavior;