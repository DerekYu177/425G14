library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity instruction_memory is
	generic(
		ram_size : integer := 4096;
		mem_delay : time := 10 ns;
		clock_period : time := 1 ns
	);
	port(
		clock : in std_logic;
		reset : in std_logic;
		program_in_finished : in std_logic;
		writedata : in std_logic_vector(31 downto 0);

		write_address : in std_logic_vector(31 downto 0);
		read_address : in std_logic_vector(31 downto 0);
		memwrite : in std_logic;
		memread : in std_logic;
		readdata : out std_logic_vector(31 downto 0);
		waitrequest : out std_logic
	);
end instruction_memory;

architecture behavior of instruction_memory is

	type mem is array(ram_size-1 downto 0) of std_logic_vector(7 downto 0);
	signal mem_block: mem;
	signal read_address_reg: integer := 0;
	signal write_waitreq_reg: std_logic := '0';
	signal read_waitreq_reg: std_logic := '0';

begin
	mem_process : process(clock)
	begin
		if reset = '1' then
			for i in 0 to ram_size-1 loop
				mem_block(i) <= std_logic_vector(to_unsigned(0, 8));
			end loop;
		elsif memwrite = '1' and program_in_finished = '0' then
			mem_block(to_integer(unsigned(write_address))) <= writedata(31 downto 24);
			mem_block(to_integer(unsigned(write_address))+1) <= writedata(23 downto 16);
			mem_block(to_integer(unsigned(write_address))+2) <= writedata(15 downto 8);
			mem_block(to_integer(unsigned(write_address))+3) <= writedata(7 downto 0);
		elsif clock'event and clock = '0' then
			read_address_reg <= to_integer(unsigned(read_address));
		end if;
	end process;

	readdata <= mem_block(read_address_reg)
		& mem_block(read_address_reg + 1)
		& mem_block(read_address_reg + 2)
		& mem_block(read_address_reg + 3);

	waitreq_w_proc: process(memwrite)
	begin
		if memwrite'event and memwrite = '1' then
			write_waitreq_reg <= '0' after mem_delay, '1' after mem_delay + clock_period;
		end if;
	end process;

	waitreq_r_proc: process(memread)
	begin
		if memread'event and memread = '1' then
			read_waitreq_reg <= '0' after mem_delay, '1' after mem_delay + clock_period;
		end if;
	end process;
	waitrequest <= write_waitreq_reg and read_waitreq_reg;

end behavior;
