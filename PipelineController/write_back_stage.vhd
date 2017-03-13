library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity write_back_stage is
  port(
    clock : in std_logic;
    reset : in std_logic;

    -- interface with register --
    writedata : out std_logic_vector(31 downto 0);
    writereg_address : out integer;

    -- pipeline interface --
    load_store : in std_logic;
    mem_wb_address : in integer;
    mem_wb_data : in std_logic_vector(31 downto 0)
  );
end write_back_stage;

architecture arch of write_back_stage is
begin
  if (load_store = '0') then
    writedata <= mem_wb_data;
    writereg_address <= mem_wb_address;
  end if;
end arch;
