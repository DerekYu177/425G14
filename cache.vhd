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

-- internal signal declaration
-- signal index : std_logic_vector(4 downto 0);
-- signal tag : std_logic_vector(7 downto 0);
alias index is s_addr(6 downto 2);
alias tag is s_addr(14 downto 7);
signal valid : std_logic;

-- data transfer signal declaration
signal read_data is std_logic_vector(32 downto 0);

-- internal 2D array declaration
-- declare as an array with 32 rows and 46 bits per row (1 valid bit, 8 tag bits, 5 index bits, 32 data bits)
-- the bits are defined as a natural bit array
-- to modify say the data bits in the second row:
-- cache_array(1)(31 downto 0) <= std_logic_vector( __new_data__ )
type cache_type is array (natural range 32 downto 0) of std_logic_vector(45 downto 0);
signal cache_array : cache_type;

-- control signal definition
signal hit : std_logic;
signal miss : std_logic;
signal operation_finished : std_logic;
signal command_read : std_logic;
signal command_write : std_logic;

-- FSM definition
type state_type is (WAIT_READ_FROM_USER, FIND_COMPARE, READ_TO_USER, WRITE_DATA, GO_TO_MM);
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
process (s_addr, s_read, s_write, s_writedata, m_readdata, m_waitrequest)
begin
	case state is
		when WAIT_READ_FROM_USER =>
			if (s_read == '1' or s_write == '1') then
				next_state <= FIND_COMPARE;
			end if;

		when FIND_COMPARE =>
			if hit == '1' and command_read == '1' then
				next_state <= READ_TO_USER;
			elsif hit == '1' and command_write == '1' then
				next_state <= WRITE_DATA;
			elsif miss == '1' then
				next_state <= GO_TO_MM;
			end if;

		when READ_TO_USER =>
			if operation_finished == '1' then
				next_state <= WAIT_READ_FROM_USER;
			end if;

		when WRITE_DATA =>
			if operation_finished == '1' then
				next_state <= WAIT_READ_FROM_USER;
			end if;

		when GO_TO_MM =>
		-- we assume here that a waitrequest means that data is being processed.
		-- we wait until the waitrequest 1 -> 0
			if falling_edge(m_waitrequest) and command_read == '1' then
				next_state <= WAIT_READ_FROM_USER
			end if;
	end case;
end process;

end arch;
