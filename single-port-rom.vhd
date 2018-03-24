-- Filename: single-port-rom.vhd
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity single_port_rom is
	port
	(
		-- addr	: in natural range 0 to 255;
		clk		: in std_logic;		-- clk is 50MHz
		q0		: out std_logic_vector(14 downto 0);
		q1		: out std_logic_vector(14 downto 0);
		q2		: out std_logic_vector(14 downto 0)
	);
	
end entity;

architecture rtl of single_port_rom is
	constant NOTE_COUNT : integer := 78;
	-- Build a 2-D array type for the RoM
	subtype word_t is std_logic_vector(14 downto 0);
	type memory_t is array(NOTE_COUNT-1 downto 0) of word_t;
	
	type notearr is array(0 to NOTE_COUNT-1) of integer range 0 to 14;
	constant notes : notearr := (5, 3, 1, 6, 4, 2, 7, 5, 3, 6, 4, 2, 5, 3, 1, 5, 3, 1, 5, 3, 1, 6, 4, 2, 6, 4, 2, 6, 4, 2, 5, 3, 1, 10, 8, 6, 10, 8, 6, 5, 3, 1, 6, 4, 2, 7, 5, 3, 6, 4, 2, 5, 3, 1, 5, 3, 1, 5, 3, 1, 5, 3, 1, 6, 4, 2, 6, 4, 2, 5, 3, 1, 6, 4, 2, 7, 5, 3);
	
	function init_rom
		return memory_t is
		variable tmp : memory_t := (others => (others => '0'));
		begin
			
			for addr_pos in 0 to NOTE_COUNT-1 loop
				-- Initialize each address with the correct notes
				tmp(addr_pos) := std_logic_vector(to_unsigned(notes(addr_pos), tmp(addr_pos)'length));
			end loop;
		return tmp;
	end init_rom;
	
	-- Declare the ROM signal and specify a default value.	Quartus II
	-- will create a memory initialization file (.mif) based on the 
	-- default value.
	signal rom : memory_t := init_rom;
	
begin
	
	process(clk)
	variable cnt : integer range 0 to 25000000 := 0;
	variable addr : integer range 0 to NOTE_COUNT-2 := 0;	-- max_addr - 1
	begin
		-- every single 0.5s
		if(rising_edge(clk)) then
			if cnt < 25000000 then	-- slow clk to 2Hz
				cnt := cnt + 3;
			else
				if addr < NOTE_COUNT-2 then
					q0 <= rom(addr);
					q1 <= rom(addr+1);
					q2 <= rom(addr+2);
					addr := addr + 1;
				else
					addr := 0;
					q0 <= rom(addr);
					q1 <= rom(addr+1);
					q2 <= rom(addr+2);			
				end if;
				cnt := 0;
			end if;
		end if;
	end process;
		
end rtl;
