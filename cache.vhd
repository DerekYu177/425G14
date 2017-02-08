library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache is
generic(
	ram_size : INTEGER := 32768;
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

-- internal signal declaration
signal index : std_logic_vector(4 downto 0);
signal tag : std_logic_vector(7 downto 0);
signal valid : std_logic;

-- internal 2D array declaration


-- FSM definition
type state_type is (WAIT_READ_FROM_USER, FIND_COMPARE, HIT, MISS, READ_TO_USER, WRITE_DATA);
signal state : state_type;
signal next_state : state_type;

-- Async Operation
process (clk, reset)
begin
	if reset = '1' then
		state <= WAIT_READ_FROM_USER;
	elsif (clk'event and clk = '1') then
		state <= next_state;
	end if;
end process;

-- State transitions
process ()

-- make circuits here

end arch;
