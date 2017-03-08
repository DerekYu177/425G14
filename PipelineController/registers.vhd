library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity registers is
	port(
		clock : in std_logic;
		writedata : in std_logic_vector(31 downto 0);
		readreg1 : in integer range 0 to 31;
		readreg2 : in integer range 0 to 31;
		writereg : in integer range 0 to 31;
		
		regwrite : in std_logic;
		readdata1 : out std_logic_vector(31 downto 0);
		readdata2 : out std_logic_vector(31 downto 0)
	);
end registers;

architecture behavior of registers is
	
	type mem is array(31 downto 0) of std_logic_vector(31 downto 0);
	signal mem_block: mem;
	signal read_address_reg1: integer range 0 to 31;
	signal read_address_reg2 : integer range 0 to 31;
	
begin
	mem_process : process(clock)
	begin
		if(now < 1 ps) then
			for i in 0 to 31 loop
				mem_block(i) <= std_logic_vector(to_unsigned(0, 32));
			end loop;
		end if;
		
		if clock'event and clock = '1' then
			if regwrite = '1' then
				if writereg = 0 then
					mem_block(0) <= std_logic_vector(to_unsigned(0, 32)); --hard wire r0 to 0
				else
					mem_block(writereg) <= writedata;
				end if;
			end if;
		read_address_reg1 <= readreg1;
		read_address_reg2 <= readreg2;
		end if;
	end process;
	readdata1 <= mem_block(read_address_reg1);
	readdata2 <= mem_block(read_address_reg2);
	
end behavior;