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

-- signal declaration
alias given_block_offset is s_addr(3 downto 1);
alias given_index is s_addr(8 downto 3);
alias given_tag is s_addr(14 downto 8);
signal tag : std_logic_vector(7 downto 0);
signal row_location : integer;
signal dirty : std_logic;
signal valid : std_logic;

-- data transfer signal declaration
signal read_data is std_logic_vector(31 downto 0);

-- 2D data array declaration
-- declare as an array with 32 rows and 128 bits per row (4 words = 32b)
-- to modify say the data bits in the second row:
-- cache_array(1)(31 downto 0) <= std_logic_vector( __new_data__ )
type cache_data_type is array (natural range 31 downto 0) of std_logic_vector(127 downto 0);
signal cache_data : cache_data_type := (others => (others => '0'));

-- 2D tag array declaration
-- 5 bit tags x 4 words/block = 20 bits per block
type cache_tag_type is array (natural range 31 downto 0) of std_logic_vector(19 downto 0);
signal cache_tag : cache_tag_type := (others => (others => '0'));

-- 2D valid/dirty array declaration
type cache_valid_dirty_type is array (natural range 31 downto 0) of std_logic_vector(2 downto 0);
signal cache_valid_dirty : cache_valid_dirty_type := (others => (others => '0'));

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

		-- cache_array initialization, clears
		For i in 0 to 31 loop
			cache_array(i)(31 downto 0) <= (others => '0');
		end loop;

		-- returns to nominal state
		state <= WAIT_READ_FROM_USER;
	elsif (clk'event and clk = '1') then
		state <= next_state;
	end if;
end process;

-- State transitions
process (given_block_offset, given_tag, given_index, s_read, s_write, s_writedata, m_readdata, m_waitrequest)
begin
	case state is

		-- nominal state
		when WAIT_READ_FROM_USER =>

			-- transitional logic
			if (s_read == '1' or s_write == '1') then
				next_state <= FIND_COMPARE;
			end if;

		when FIND_COMPARE =>
			row_location <= to_integer(unsigned(given_index));
			valid <= cache_valid_dirty(row_location)(1);
			dirty <= cache_valid_dirty(row_location)(0);

			case given_block_offset is
				when "00" =>
					tag <= cache_tag(row_location)(19 downto 14);
				when "01" =>
					tag <= cache_tag(row_location)(14 downto 9);
				when "10" =>
					tag <= cache_tag(row_location)(9 downto 4);
				when others =>
					-- this includes "11"
					tag <= cache_tag(row_location)(4 downto 0);
			end case;

			command_read <= s_read;
			command_write <= s_write;

			-- transitional logic
			if hit == '1' and command_read == '1' then
				next_state <= READ_TO_USER;
			elsif hit == '1' and command_write == '1' then
				next_state <= WRITE_DATA;
			elsif miss == '1' then
				next_state <= GO_TO_MM;
			end if;

		when READ_TO_USER =>

			-- transitional logic
			if operation_finished == '1' then
				next_state <= WAIT_READ_FROM_USER;
			end if;

		when WRITE_DATA =>

			-- transitional logic
			if operation_finished == '1' then
				next_state <= WAIT_READ_FROM_USER;
			end if;

		when GO_TO_MM =>

		-- transitional logic
		-- we assume here that a waitrequest means that data is being processed.
		-- we wait until the waitrequest 1 -> 0
			if falling_edge(m_waitrequest) and command_read == '1' then
				next_state <= WAIT_READ_FROM_USER
			end if;
	end case;
end process;
end arch;
