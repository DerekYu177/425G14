library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity registers is
	port(
		clock : in std_logic;
		reset : in std_logic;
		writedata : in std_logic_vector(31 downto 0);
		readreg1 : in std_logic_vector(31 downto 0);
		readreg2 : in std_logic_vector(31 downto 0);
		readreg_fini : in std_logic_vector(31 downto 0);
		writereg : in std_logic_vector(31 downto 0);
		data_in_hi : in std_logic_vector(31 downto 0);
		data_in_lo : in std_logic_vector(31 downto 0);
		write_hi : in std_logic;
		write_lo : in std_logic;

		regwrite : in std_logic;
		readdata1 : out std_logic_vector(31 downto 0);
		readdata2 : out std_logic_vector(31 downto 0);
		readdata_fini : out std_logic_vector(31 downto 0);
		data_out_hi : out std_logic_vector(31 downto 0);
		data_out_lo : out std_logic_vector(31 downto 0)
	);
end registers;

architecture behavior of registers is

	type mem is array(31 downto 0) of std_logic_vector(31 downto 0);
	signal mem_block: mem;
	signal read_address_reg1: integer range 0 to 31;
	signal read_address_reg2 : integer range 0 to 31;
	signal read_address_reg_fini : integer range 0 to 31;

	signal hi_reg: std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(0, 32));
	signal lo_reg: std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(0, 32));

begin
	mem_process : process(clock, reset)
	begin
		if reset = '1' then
			for i in 0 to 31 loop
				mem_block(i) <= std_logic_vector(to_unsigned(0, 32));
			end loop;
			hi_reg <= std_logic_vector(to_unsigned(0, 32));
			lo_reg <= std_logic_vector(to_unsigned(0, 32));

		elsif clock'event and clock = '1' then --write on rising edge
			if regwrite = '1' then
				if writereg = 0 then
					mem_block(0) <= std_logic_vector(to_unsigned(0, 32)); --hard wire r0 to 0
				else
					mem_block(writereg) <= writedata;
				end if;
			end if;
			if write_hi = '1' then
				hi_reg <= data_in_hi;
			end if;
			if write_lo = '1' then
				lo_reg <= data_in_lo;
			end if;

		elsif clock'event and clock = '0' then --read on falling edge
			read_address_reg1 <= to_integer(unsigned(readreg1));
			read_address_reg2 <= to_integer(unsigned(readreg2));
			read_address_reg_fini <= to_integer(unsigned(readreg_fini));
		end if;
	end process;
	readdata1 <= mem_block(read_address_reg1);
	readdata2 <= mem_block(read_address_reg2);
	readdata_fini <= mem_block(read_address_reg_fini);
	data_out_hi <= hi_reg;
	data_out_lo <= lo_reg;

end behavior;
