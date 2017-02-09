library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache is
generic(
	ram_size : INTEGER := 32768
);
port(
	clock : in std_logic;
	reset : in std_logic;
	
	-- Avalon interface --
	s_addr : in std_logic_vector (31 downto 0);
	s_read : in std_logic;
	s_readdata : out std_logic_vector (31 downto 0);
	s_write : in std_logic;
	s_writedata : in std_logic_vector (31 downto 0);
	s_waitrequest : out std_logic; 
    
	m_addr : out integer range 0 to ram_size-1;
	m_read : out std_logic;
	m_readdata : in std_logic_vector (7 downto 0);
	m_write : out std_logic;
	m_writedata : out std_logic_vector (7 downto 0);
	m_waitrequest : in std_logic
);
end cache;

architecture arch of cache is

	type data_array is array(4 downto 0) of std_logic_vector(127 downto 0);
	type tag_array is array(4 downto 0) of std_logic_vector(6 downto 0);
	type valid_array is array(4 downto 0) of std_logic;
	type dirty_array is array(4 downto 0) of std_logic;
	
	signal data : data_array;
	signal tag : tag_array;
	signal valid : valid_array;
	signal dirty : dirty_array;
	
	signal index_in : std_logic_vector(4 downto 0); -- 32 blocks, so 5 bit index field
	signal tag_in : std_logic_vector(6 downto 0);
	signal offset_in : std_logic_vector(3 downto 0);
	
	signal index_in_int : integer;
	signal offset_in_int : integer;
-- declare signals here

begin
	tag_in <= s_addr(15 downto 9);
	index_in <= s_addr(8 downto 4);
	offset_in <= s_addr(3 downto 2) & "00"; -- ignore last 2 bits
	
	index_in_int <= to_integer(unsigned(index_in));
	offset_in_int <= to_integer(unsigned(offset_in));
	
-- make circuits here
process
begin
	wait on clock, reset, s_write, s_read;
	if reset = '1' then
		for i in 0 to 32 loop
			data(i) <= std_logic_vector(to_unsigned(i, 128));
			tag(i) <= std_logic_vector(to_unsigned(i, 7));
			valid(i) <= '0';
			dirty(i) <= '0';
		end loop;
	
	elsif s_write = '1' and rising_edge(clock) then --writing process
		s_waitrequest <= '1';
		if tag_in = tag(index_in_int) and valid(index_in_int) = '1' then --hit
		data(index_in_int)(127-32*offset_in_int downto 96-32*offset_in_int) <= s_writedata; --write to cache
		dirty(index_in_int) <= '1'; --mark dirty
		else -- not hit
			if dirty(index_in_int) = '1' then --write to memory before overwriting
				m_write <= '1';
				wait until rising_edge(clock) and m_waitrequest = '0';
				for i in 0 to 16 loop
					m_addr <= to_integer(unsigned(std_logic_vector'(s_addr(31 downto 4) & "0000")))+i;
					m_writedata <= data(index_in_int)(127-i*8 downto 120-i*8);
					wait until rising_edge(clock);
				end loop;
				m_write <= '0';
			else --not dirty, so just put in cache
				data(index_in_int)(127-32*offset_in_int downto 96-32*offset_in_int) <= s_writedata;
				dirty(index_in_int) <= '1';
				valid(index_in_int) <= '1';
				tag(index_in_int) <= tag_in;
			end if;
		end if;
		s_waitrequest <= '0';
		
	elsif s_read = '1' and rising_edge(clock) then --reading process
		s_waitrequest <= '1';
		if tag_in = tag(index_in_int) and valid(index_in_int) = '1' then --hit
			s_readdata <= data(index_in_int)(127-32*offset_in_int downto 96-32*offset_in_int); --return the value
		else --miss
			if dirty(index_in_int) = '1' then --write to memory before overwriting
				m_write <= '1';
				wait until rising_edge(clock) and m_waitrequest = '0';
				for i in 0 to 16 loop
					m_addr <= to_integer(unsigned(std_logic_vector'(s_addr(31 downto 4) & "0000")))+i;
					m_writedata <= data(index_in_int)(127-i*8 downto 120-i*8);
					wait until rising_edge(clock);
				end loop;
				m_write <= '0';
			end if;
			
			m_read <= '1'; --begin reading from memory
			wait until rising_edge(clock) and m_waitrequest = '0';
			for i in 0 to 16 loop
				m_addr <= to_integer(unsigned(std_logic_vector'(s_addr(31 downto 4) & "0000")))+i;
				data(index_in_int)(127-i*8 downto 120-i*8) <= m_readdata;
				wait until rising_edge(clock);
			end loop;
			m_read <= '0';
			
			dirty(index_in_int) <= '0';
			valid(index_in_int) <= '1';
			tag(index_in_int) <= tag_in;
		end if;
		s_waitrequest <= '0';
	end if;
end process;
end arch;