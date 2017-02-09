library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache is
generic(
	ram_size : INTEGER := 32768;
	cache_size: INTEGER := 512;
	block_number: INTEGER := 32
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
--DECLARATION SECTION 
---------------------

--Storage types declarations
TYPE MEM IS ARRAY(cache_size-1 downto 0) OF STD_LOGIC_VECTOR(7 DOWNTO 0); -- the type mem is a 512 bytes (8-bit) array
TYPE TAG IS ARRAY(block_number-1 downto 0) OF STD_LOGIC_VECTOR(5 DOWNTO 0); -- 32 6-bits tag bit array 
TYPE DIRTY IS ARRAY(block_number-1 downto 0) OF STD_LOGIC; -- 32 1-bit dirty bit array
TYPE VALID IS ARRAY(block_number-1 downto 0) OF STD_LOGIC; -- 32 1-bit valid bit array
	
--Storage signals instantiations
SIGNAL data_byte_block: MEM;
SIGNAL tag_block: TAG;
SIGNAL dirty_block: DIRTY;
SIGNAL valid_block: VALID;

--Address decomposition into fields
SIGNAL s_addr_offsetw: std_LOGIC_VECTOR(1 downto 0) := s_addr(3 downto 2);
SIGNAL s_addr_index: std_LOGIC_VECTOR(4 downto 0):= s_addr(8 downto 4);
SIGNAL s_addr_tag: std_LOGIC_VECTOR(5 downto 0) := s_addr(14 downto 9);
SIGNAL s_indexed_block_number: INTEGER := to_integer(unsigned(s_addr_index));

--FSM states declarations
TYPE State_type IS (idle_state, s_read_wreq_asserted, s_read_wreq_deasserted, s_write_wreq_deasserted, s_write_wreq_asserted, s_read_hit, s_read_miss, s_read_miss_flush, s_write_hit_clean,
s_write_hit_dirty, s_write_miss_flush, s_write_miss_invalid, s_write_miss_no_flush);
SIGNAL present_state, next_state: State_type;

--Other signals
SIGNAL hit: std_logic;

BEGIN
--BEGINNING OF ARCHITECTURE
---------------------------

	--This is the main section of the SRAM model
	mem_process: PROCESS (clock)
	BEGIN
		--This is a cheap trick to initialize the SRAM in simulation
		IF(now < 1 ps)THEN
			For i in 0 to ((cache_size-1)/2) -1 LOOP
				data_byte_block(i) <= std_logic_vector(to_unsigned(i,8));
				--From byte address 0 to 255, set data to whatever the address is
			END LOOP;
			For i in (cache_size-1)/2 to cache_size -1 LOOP
				data_byte_block(i) <= "00000000";
				--From byte address 256 to 511, set data to all zeroes
			END LOOP;
		end if;
		
		IF(now < 1 ps)THEN
		--addresses are of the form: xxxx xxxx xxxx xxxx x TTT TTTI IIII OO xx
		--where x -> don't care, T -> tag, I -> index, O -> offset
		
			For j in 0 to block_number-1 LOOP
				dirty_block(j) <= '0';
				valid_block(j) <= '0';
				tag_block(j) <= "000000"; 
				--Initiate all tags (6 MSB of effective address)  as 0
				--In this fashion, reading address in the range [0, 255] will return the value of the address
			END LOOP;
		end if;
	END PROCESS;
	
	-- make circuits here
	
	state_logic: PROCESS(s_read, s_write, s_addr, s_writedata)
	BEGIN
		CASE present_state is
			when idle_state =>
				if s_read = '1' then
					next_state <= s_read_wreq_asserted;
				elsif s_write = '1' then
					next_state <= s_write_wreq_asserted;
				else
					next_state <= idle_state;
				end if;
				
			-- READING SEQUENCE
			when s_read_wreq_asserted =>
				next_state <= s_read_wreq_deasserted;
				
			when s_read_wreq_deasserted =>
				-- Cases where data = valid, tag = equal, don't care about dirty bit: READ HIT
				if(s_addr_tag = tag_block(s_indexed_block_number) and valid_block(s_indexed_block_number) = '1') then
					next_state <= s_read_hit;
				-- Cases where data = invalid, don't care about tag, dirty bit must be low: READ MISS
				elsif (valid_block(s_indexed_block_number) = '0') then
					next_state <= s_read_miss;
				-- Case where data = valid, tag = unequal, dirty = 1: READ MISS, FLUSH, clear dirty
				elsif not(s_addr_tag = tag_block(s_indexed_block_number)) and (valid_block(s_indexed_block_number) = '1') and (dirty_block(s_indexed_block_number) = '1') then
					next_state <= s_read_miss_flush;
				-- Case where data = valid, tag = unequal, dirty = 0: READ MISS, dirty stays low
				elsif not(s_addr_tag = tag_block(s_indexed_block_number)) and (valid_block(s_indexed_block_number) = '1') and (dirty_block(s_indexed_block_number) = '0') then
					next_state <= s_read_miss;
				else
					null;
				end if;
			
			-- READING SEQUENCE
			when s_write_wreq_asserted =>
				next_state <= s_read_wreq_deasserted;
				
			when s_write_wreq_deasserted =>
				-- Cases where data = valid, tag = equal, dirty = 1: WRITE HIT, set dirty bit high
				if(s_addr_tag = tag_block(s_indexed_block_number)) and (valid_block(s_indexed_block_number) = '1') and (dirty_block(s_indexed_block_number) = '0') then
					next_state <= s_write_hit_clean;
				-- Cases where data = valid, tag = equal, dirty = 0: WRITE HIT, dirty bit stay high
				elsif(s_addr_tag = tag_block(s_indexed_block_number)) and (valid_block(s_indexed_block_number) = '1') and (dirty_block(s_indexed_block_number) = '1') then
					next_state <= s_write_hit_dirty;
				-- Cases where data = invalid, don't care about tag, dont care about dirty bit: WRITE MISS, no flushing, replace, mark dirty
				elsif valid_block(s_indexed_block_number) = '0' then
					next_state <= s_write_miss_invalid;
				-- Cases where data = valid, tag = unequal, dirty = 1: WRITE MISS, FLUSH, replace, mark dirty
				elsif not(s_addr_tag = tag_block(s_indexed_block_number)) and (valid_block(s_indexed_block_number) = '1') and (dirty_block(s_indexed_block_number) = '1') then
					next_state <= s_write_miss_flush;
				-- Cases where data = valid, tag = unequal, dirty = 1: WRITE MISS, NO FLUSH, replace, mark dirty
				elsif not(s_addr_tag = tag_block(s_indexed_block_number)) and (valid_block(s_indexed_block_number) = '1') and (dirty_block(s_indexed_block_number) = '0') then
					next_state <= s_write_miss_no_flush;
				else
					null;
				end if;
				
			when others => -- SEVERAL MORE STATES NEED TO BE ADDED
				null;
		end CASE;		
	END PROCESS;
	
	state_update:process(clock, reset)
	begin
		if reset = '1' then 
			present_state <= idle_state;
		elsif (Clock'EVENT AND Clock = '1') then
			present_state <= next_state;
		end if;
end process;


end arch;
