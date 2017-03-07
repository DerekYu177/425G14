library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity registers is
	generic(
		mem_delay : time := 10 ns;
		clock_period : time := 1 ns
	);
	port(
		clock : in std_logic;
		writedata : in std_logic_vector(31 downto 0);
		regnum : in integer range 0 to 31;
		
		memwrite : in std_logic;
		memread : in std_logic;
		readdata : out std_logic_vector(31 downto 0);
		waitrequest : out std_logic
	);
end registers;

architecture behavior of registers is
	
	type mem is array(31 downto 0) of std_logic_vector(31 downto 0);
	signal mem_block: mem;
	signal read_address_reg: integer range 0 to 31;
	signal write_waitreq_reg: std_logic := '1';
	signal read_waitreq_reg: std_logic := '1';
	
begin
	mem_process : process(clock)
	begin
		if(now < 1 ps) then
			for i in 0 to 31 loop
				mem_block(i) <= std_logic_vector(to_unsigned(0, 32));
			end loop;
		end if;
		
		if clock'event and clock = '1' then
			if memwrite = '1' then
				if regnum = 0 then
					mem_block(0) <= std_logic_vector(to_unsigned(0, 31)); --hard wire r0 to 0
				else
					mem_block(regnum) <= writedata;
				end if;
			end if;
		read_address_reg <= regnum;
		end if;
	end process;
	readdata <= mem_block(read_address_reg);
	
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