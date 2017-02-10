library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache is
generic(
	ram_size : INTEGER := 32768;
	cache_size: INTEGER := 512; -- 32 x 4 = 128 words, or 512 addressable bytes in cache
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
SIGNAL s_addr_unused_offset: std_LOGIC_VECTOR(1 downto 0) := s_addr(1 downto 0);
SIGNAL s_addr_offsetw: std_LOGIC_VECTOR(1 downto 0) := s_addr(3 downto 2);
SIGNAL s_addr_index: std_LOGIC_VECTOR(4 downto 0):= s_addr(8 downto 4);
SIGNAL s_addr_tag: std_LOGIC_VECTOR(5 downto 0) := s_addr(14 downto 9);
SIGNAL s_addr_unused_MSB: std_LOGIC_VECTOR(16 downto 0) := s_addr(31 downto 15);
SIGNAL s_indexed_block_number: INTEGER := to_integer(unsigned(s_addr_index));
SIGNAL s_word_offset_int: INTEGER :=to_integer(unsigned(s_addr_offsetw));

SIGNAL s_current_full_addr: integer := to_integer(unsigned(s_addr_unused_MSB))+ to_integer(unsigned(tag_block(s_indexed_block_number))) + to_integer(unsigned(s_addr_index)) + 
to_integer(unsigned(s_addr_offsetw)) + to_integer(unsigned(s_addr_unused_offset));

--FSM states declarations
TYPE State_type IS (
idle_state,
s_read_wreq_asserted, s_read_wreq_deasserted,
s_write_wreq_deasserted, s_write_wreq_asserted,
s_read_hit, s_read_miss, s_read_miss_flush,
s_write_hit, s_write_miss, s_write_miss_flush,
load0, load1, load2, load3,
flush0, flush1, flush2, flush3);

SIGNAL present_state, next_state: State_type;

--Other signals
SIGNAL read_hit: std_logic;
SIGNAL write_hit: std_logic;


--BEGINNING OF ARCHITECTURE
---------------------------
BEGIN

read_hit <= '0';
write_hit <= '0';

	--This is the main section of the SRAM model
	mem_process: PROCESS (clock)
	BEGIN
		--This is a cheap trick to initialize the SRAM in simulation
		IF(now < 1 ps)THEN
			For i in 0 to ((cache_size-1)/2) -1 LOOP
				data_byte_block(i) <= std_logic_vector(to_unsigned(i,8));
				--From byte address 0 to 255, set data to whatever the address is (as binary representation)
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
				--Initiate all dirty and valid bit to 0
				--Initiate all tags (6 MSB of effective address) as 0
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
				
			-- Different case handling
			when s_read_hit =>
				if m_waitrequest = '0' then
					if (s_read = '1') then
						next_state <= s_read_wreq_asserted;
					elsif (s_write = '1') then
						next_state <= s_write_wreq_asserted;
					else
						next_state <= idle_state;
					end if;
				else
					--stall if m_waitrequest is still high
					next_state <= s_read_hit;
				end if;
				
			when s_read_miss =>
				if m_waitrequest = '0' then
					next_state <= load0;
				else
					next_state <= s_read_miss;
				end if;
				
			when load0 =>
				next_state <= load1;
			when load1 =>
				next_state <= load2;
			when load2 =>
				next_state <= load3;
			when load3 =>
				if m_waitrequest = '0' then
					if (s_read = '1') then
						next_state <= s_read_wreq_asserted;
					elsif (s_write = '1') then
						next_state <= s_write_wreq_asserted;
					else
						next_state <= idle_state;
					end if;
				else
					next_state <= load3;
				end if;
				
			when s_read_miss_flush =>
				if m_waitrequest = '0' then
					next_state <= flush0;
				else
					next_state <= s_read_miss_flush;
				end if;
			when flush0 =>
				next_state <= flush1;
			when flush1 =>
				next_state <= flush2;
			when flush2 =>
				next_state <= flush3;
			when flush3 =>
				if m_waitrequest = '0' then
					next_state <= load0;
				else
					next_state <= flush3;
				end if;
			
			-- WRITING SEQUENCE
			when s_write_wreq_asserted =>
				next_state <= s_read_wreq_deasserted;
				
			when s_write_wreq_deasserted =>
				-- Cases where data = valid, tag = equal, dirty = 1: WRITE HIT, set dirty bit high if not, dirty bit stays high if already high
				if(s_addr_tag = tag_block(s_indexed_block_number)) and (valid_block(s_indexed_block_number) = '1') and (dirty_block(s_indexed_block_number) = '0') then
					next_state <= s_write_hit;
				-- Cases where data = invalid, don't care about tag, dont care about dirty bit: WRITE MISS, no flushing, replace, mark dirty
				elsif valid_block(s_indexed_block_number) = '0' then
					next_state <= s_write_miss;
				-- Cases where data = valid, tag = unequal, dirty = 1: WRITE MISS, FLUSH, replace, mark dirty
				elsif not(s_addr_tag = tag_block(s_indexed_block_number)) and (valid_block(s_indexed_block_number) = '1') and (dirty_block(s_indexed_block_number) = '1') then
					next_state <= s_write_miss_flush;
				-- Cases where data = valid, tag = unequal, dirty = 1: WRITE MISS, NO FLUSH (since not dirty, MM up to date), replace, mark dirty
				elsif not(s_addr_tag = tag_block(s_indexed_block_number)) and (valid_block(s_indexed_block_number) = '1') and (dirty_block(s_indexed_block_number) = '0') then
					next_state <= s_write_miss;
				else
					null;
				end if;
				
			when s_write_hit =>
				if m_waitrequest = '0' then
					if (s_read = '1') then
						next_state <= s_read_wreq_asserted;
					elsif (s_write = '1') then
						next_state <= s_write_wreq_asserted;
					else
						next_state <= idle_state;
					end if;
				else
					--stall if m_waitrequest is still high
					next_state <= s_write_hit;
				end if;
			when s_write_miss =>
				if m_waitrequest = '0' then
					next_state <= load0;
				else
					next_state <= s_write_miss;
				end if;
			when s_write_miss_flush =>
				if m_waitrequest = '0' then
					next_state <= flush0;
				else
					next_state <= s_write_miss_flush;
				end if;
			when others => -- SEVERAL MORE STATES NEED TO BE ADDED
				null;
		end CASE;		
	END PROCESS;
	
	
	output_logic:process(present_state)
	begin
		CASE present_state is
			when idle_state =>
				s_waitrequest <= '1';
				m_read <= '0';
				m_write <= '0';
				m_addr <= 0;
			when s_read_wreq_asserted =>
				s_waitrequest <= '1';
				m_read <= '0';
				m_write <= '0';
			when s_read_wreq_deasserted =>
				s_waitrequest <= '0';
				m_read <= '0';
				m_write <= '0';
			when s_write_wreq_asserted =>
				s_waitrequest <= '1';
				m_read <= '0';
				m_write <= '0';
			when s_write_wreq_deasserted =>
				s_waitrequest <= '0';
				m_read <= '0';
				m_write <= '0';
			
			-- READ OUTPUT CASES
			when s_read_hit =>
				-- Read hit, load data on data bus, no need to change valid/dirty bit
				read_hit <= '1';
				
				-- Get the complete word out, via concatenation of 4 adjacent bytes
				s_readdata <= data_byte_block(s_indexed_block_number*16 + s_word_offset_int*4)&
				data_byte_block(s_indexed_block_number*16 + s_word_offset_int*4 +1)
				&data_byte_block(s_indexed_block_number*16 + s_word_offset_int*4 +2)
				&data_byte_block(s_indexed_block_number*16 + s_word_offset_int*4 +3);
			
			when s_read_miss =>
				-- make valid if not
				-- cases matched to 's_read_miss' either have invalid data or have dirty bit = 0, hence no flushing and dirty bit stays as is
				read_hit <= '0';
				valid_block(s_indexed_block_number) <= '1';
				tag_block(s_indexed_block_number) <= s_addr_tag;
				-- FETCH CORRECT BLOCK
				m_read <= '1';
				m_write <= '0';
				
			when load0 =>
				m_addr <= to_integer(unsigned(s_addr));
				data_byte_block(s_indexed_block_number*16 + s_word_offset_int*4) <= m_readdata;
				
			when load1 =>
				m_addr <= to_integer(unsigned(s_addr))+1;
				data_byte_block(s_indexed_block_number*16 + s_word_offset_int*4 +1) <= m_readdata;
				
			when load2 =>
				m_addr <= to_integer(unsigned(s_addr))+2;
				data_byte_block(s_indexed_block_number*16 + s_word_offset_int*4 +2) <= m_readdata;
				
			when load3 =>
				m_addr <= to_integer(unsigned(s_addr))+3;
				data_byte_block(s_indexed_block_number*16 + s_word_offset_int*4 +3) <= m_readdata;
				
				-- loading complete, now change the tag, if haven't done, to the tag of the newly brought in block
				tag_block(s_indexed_block_number) <= s_addr_tag;
				
			when s_read_miss_flush =>
				-- TAG UNMATCHED yet dirty, FLUSH
				-- Since we flushed the dirty block and fetched a new one, CLEAR the dirty bit!
				read_hit <= '0';
				valid_block(s_indexed_block_number) <= '1';
				dirty_block(s_indexed_block_number) <= '0';
				tag_block(s_indexed_block_number) <= s_addr_tag;
				-- FLUSH TO MM FIRST
				m_read <= '0';
				m_write <= '1';
				
			
			-- WRITE OUTPUT CASES
			when s_write_hit =>
				-- write hit, update cache storage with data on the data bus
				data_byte_block(s_indexed_block_number*16 + s_word_offset_int*4) <= s_writedata(31 downto 24);
				data_byte_block(s_indexed_block_number*16 + s_word_offset_int*4 + 1) <= s_writedata(23 downto 16);
				data_byte_block(s_indexed_block_number*16 + s_word_offset_int*4 + 2) <= s_writedata(15 downto 8);
				data_byte_block(s_indexed_block_number*16 + s_word_offset_int*4 + 3) <= s_writedata(7 downto 0);

				-- write hit, mark dirty no matter what
				write_hit <= '1';
				dirty_block(s_indexed_block_number) <= '1';
				
			when s_write_miss =>
				write_hit <= '0';
				valid_block(s_indexed_block_number) <= '1';
				dirty_block(s_indexed_block_number) <= '1';
				
				-- FETCH CORRECT BLOCK
				m_read <= '1';
				m_write <= '0';
				
			when s_write_miss_flush =>
				write_hit <= '0';
				valid_block(s_indexed_block_number) <= '1';
				dirty_block(s_indexed_block_number) <= '1';
				
				-- FLUSH TO MM FIRST
				m_read <= '0';
				m_write <= '1';
				
			when flush0 =>
				--flush things of the CURRENTLY INDEXED ADDRESS back to MM
				m_addr <= s_current_full_addr;
				m_writedata <= data_byte_block(s_indexed_block_number*16 + s_word_offset_int*4);
				
			when flush1 =>
				m_addr <= s_current_full_addr+1;
				m_writedata <= data_byte_block(s_indexed_block_number*16 + s_word_offset_int*4 +1);
				
			when flush2 =>
				m_addr <= s_current_full_addr+2;
				m_writedata <= data_byte_block(s_indexed_block_number*16 + s_word_offset_int*4 +2);
				
			when flush3 =>
				m_addr <= s_current_full_addr+3;
				m_writedata <= data_byte_block(s_indexed_block_number*16 + s_word_offset_int*4 +3);
				
				-- At the end of flushing, prepare for loading new data from MM
				m_read <= '1';
				m_write <= '0';
								
			
				
				
			
				
			when others =>
				null;
		end CASE;
	end process;
	
	state_update:process(clock, reset)
	begin
		if reset = '1' then 
			present_state <= idle_state;
		elsif (Clock'EVENT AND Clock = '1') then
			present_state <= next_state;
		end if;
	end process;

end arch;
