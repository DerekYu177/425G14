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

-- constant declaration
constant BLOCK_NUMBER : integer := 32;

-- signal declaration
alias given_block_offset is s_addr(3 downto 1);
alias given_index is s_addr(8 downto 3);
alias given_tag is s_addr(14 downto 8);
signal tag : std_logic_vector(7 downto 0);
signal row_location : integer;
signal dirty : std_logic;
signal valid : std_logic;
signal tag_equal : std_logic;

-- data transfer signal declaration
signal read_data is std_logic_vector(BLOCK_NUMBER-1 downto 0);
signal store_cache_data is std_logic_vector(BLOCK_NUMBER-1 downto 0);

-- debug signal definition
signal hit : std_logic;
signal miss : std_logic;
signal NA : std_logic;
signal FOO : std_logic;

-- 2D data array declaration
-- declare as an array with 32 rows and 128 bits per row (4 words = 32b)
-- to modify say the data bits in the second row:
-- cache_array(1)(BLOCK_NUMBER-1 downto 0) <= std_logic_vector( __new_data__ )
type cache_data_type is array (natural range BLOCK_NUMBER-1 downto 0) of std_logic_vector(127 downto 0);
signal cache_data : cache_data_type := (others => (others => '0'));

-- 2D tag array declaration
-- 5 bit tags x 4 words/block = 20 bits per block
type cache_tag_type is array (natural range BLOCK_NUMBER-1 downto 0) of std_logic_vector(19 downto 0);
signal cache_tag : cache_tag_type := (others => (others => '0'));

-- 2D valid/dirty array declaration
type cache_valid_dirty_type is array (natural range BLOCK_NUMBER-1 downto 0) of std_logic_vector(2 downto 0);
signal cache_valid_dirty : cache_valid_dirty_type := (others => (others => '0'));

-- control signal definition
signal command_read : std_logic;
signal command_write : std_logic;

-- FSM definition
type state_type is (WAIT_READ_FROM_USER, FIND_COMPARE, READ_READY, READ_FINISHED, WRITE_DATA, READ_MISS, LOAD_1, LOAD_2, LOAD_3, LOAD_FINISHED, WRITE_MISS, STORE_1, STORE_2, STORE_3, STORE_FINISHED);
signal state : state_type;
signal next_state : state_type;

-- Async Operation
process (clk, reset)
begin
	if reset = '1' then

		-- clear cache
		For i in BLOCK_NUMBER-1 downto 0 loop
			cache_array(i)(127 downto 0) <= (others => '0');
			cache_tag(i)(19 downto 0) <= (others => '0');
			cache_valid_dirty(i)(1 downto 0) <= (others => '0');
		end loop;

		-- clear debug signals
		hit <= '0';
		miss <= '0';
		NA <= '0';
		FOO <= '0';

		-- clear control signals
		command_read <= (others => '0');
		command_write <= (others => '0');

		-- clear data transfer signal
		read_data <= (others => '0');

		-- clear internal signals
		tag <= (others => '0');
		row_location <= 0;
		dirty <= '0';
		valid <= '0';
		tag_equal <= '0';

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
			s_waitrequest <= '1';

			-- transitional logic
			if (s_read == '1' or s_write == '1') then
				next_state <= FIND_COMPARE;
			end if;

			next_state <= WAIT_READ_FROM_USER;

		when FIND_COMPARE =>
			row_location <= to_integer(unsigned(given_index));
			valid <= cache_valid_dirty(row_location)(1);
			dirty <= cache_valid_dirty(row_location)(0);
			command_read <= s_read;
			command_write <= s_write;

			case given_block_offset is
				-- prefetch the data at that location if we think it is the correct one
				when "00" =>
					tag <= cache_tag(row_location)(19 downto 14);
					read_data <= cache_data(row_location)(127 downto 95);
				when "01" =>
					tag <= cache_tag(row_location)(14 downto 9);
					read_data <= cache_data(row_location)(95 downto 63);
				when "10" =>
					tag <= cache_tag(row_location)(9 downto 4);
					read_data <= cache_data(row_location)(63 downto 31);
				when others =>
					-- this includes "11"
					tag <= cache_tag(row_location)(4 downto 0);
					read_data <= cache_data(row_location)(31 downto 0);
			end case;

			if tag == given_tag then
				tag_equal <= '1'
			end if;

			-- transitional logic
			if command_read == '1' then
				if tag_equal == '1' and valid == '1' then
					hit <= '1';
					next_state <= READ_READY;
				elsif valid == '0' and dirty == '1' then
					NA <= '1';
					next_state <= WAIT_READ_FROM_USER;
				else
					miss <= '1';
					next_state <= READ_MISS;
				end if;

			elsif command_write == '1' then
				if tag_equal == '1' and valid == '1' then
					hit <= '1';
					cache_valid_dirty(row_location)(0) <= '1'; -- write dirty bit
					next_state <= WRITE_DATA;
				elsif valid == '0' and dirty == '1' then
					NA <= '1';
					next_state <= WAIT_READ_FROM_USER;
				else
					miss <= '1';
					next_state <= WRITE_MISS;
				end if;

			else
				FOO <= '1';
			end if;

		when READ_READY =>
			s_waitrequest <= '0';

			-- at this point, the data should be loaded into read_data already
			s_readdata <= read_data;

			next_state <= READ_FINISHED;

		when READ_FINISHED
			-- cleanup to prepare to return to nominal state
			hit <= '0';
			miss <= '0';
			NA <= '0';
			FOO <= '0';

			s_waitrequest <= '1';
			next_state <= WAIT_READ_FROM_USER;

		when READ_MISS =>
		    m_addr <= to_integer(unsigned(s_addr));
		    m_read <= '1';
		    m_write <= '0';
		    next_state <= LOAD_1;

		when LOAD_1 =>
		  if m_waitrequest == '0' then
		    -- we assume a mapping of left->right in cache to top->down in memory
		    read_data(31 downto 23) <= m_writedata;
		    m_addr <= to_integer(unsigned(s_addr) + 1);
		    next_state <= LOAD_2;
		  else
		    next_state <= LOAD_1;
		  end if;

		when LOAD_2 =>
		  if m_waitrequest == '0' then
		    read_data(23 downto 15) <= m_writedata;
		    m_addr <= to_integer(unsigned(s_addr) + 2);
		    next_state <= LOAD_3;
		  else
		    next_state <= LOAD_2;
		  end if;

		when LOAD_3 =>
		  if m_waitrequest == '0' then
		    read_data(15 downto 7) <= m_writedata;
		    m_addr <= to_integer(unsigned(s_addr) + 3);
		    next_state <= LOAD_FINISHED;
		  else
		    next_state <= LOAD_3;
		  end if;

		when LOAD_FINISHED =>
		  if m_waitrequest == '0' then
		    m_read <= '0';
		    read_data(7 downto 0) <= m_writedata;
		    -- we want to use the same process for reads AND writes
		    if command_read == '1' then
		      next_state <= READ_READY;
		    else -- write
		      next_state <= WRITE_MISS;
		    end if;
		  else
		    next_state <= LOAD_FINISHED;
		  end if;


		when WRITE_DATA =>
			-- write into the cache
			cache_array(row_location)(BLOCK_NUMBER-1 downto 0) <= s_writedata;

			-- transitional logic
			s_waitrequest <= '0'; -- no longer busy
			next_state <= WAIT_READ_FROM_USER;

		when WRITE_MISS =>
		  -- implement write allocate here
		  -- write the value to main memory
		  -- write the block into the cache

		  if dirty == '1' then
				-- pull dirty memory
		    store_cache_data <= cache_array(row_location)(BLOCK_NUMBER-1 downto 0);
		    -- store dirty memory into main memory
		    m_addr <= to_integer(unsigned(s_addr));
		    m_read <= '0';
		    m_write <= '1';
		    m_writedata <= store_cache_data(31 downto 23);
		    next_state <= STORE_1;
		  end if;

		  -- set dirty bit
		  cache_valid_dirty(row_location)(0) <= '1';

		  -- try the cache again
		  next_state <= FIND_COMPARE;

		when STORE_1 =>
		  if m_waitrequest == '0' then
		    m_write <= '0';
		    m_addr <= to_integer(unsigned(s_addr) + 1);
		    m_writedata <= store_cache_data(23 downto 15);

		    m_write <= '1';
		    next_state <= STORE_2;
		  else
		    next_state <= STORE_1;
		  end if;

		when STORE_2 =>
		  if m_waitrequest == '0' then
		    m_write <= '0';
		    m_addr <= to_integer(unsigned(s_addr) + 2);
		    m_writedata <= store_cache_data(15 downto 7);

		    m_write <= '1';
		    next_state <= STORE_3;
		  else
		    next_state <= STORE_2;
		  end if;

		when STORE_3 =>
		  if m_waitrequest == '0' then
		    m_write <= '0';
		    m_addr <= to_integer(unsigned(s_addr) + 2);
		    m_writedata <= store_cache_data(7 downto 0);

		    m_write <= '1';
		    next_state <= STORE_FINISHED;
		  else
		    next_state <= STORE_3;
		  end if;

		when STORE_FINISHED =>
		  if m_waitrequest == '0' then
		    m_write <= '0';

		    -- TODO : Anything here?
		    next_state <= FIND_COMPARE;
		  else
		    next_state <= STORE_FINISHED;
		  end if;

	end case;
end process;
end arch;
