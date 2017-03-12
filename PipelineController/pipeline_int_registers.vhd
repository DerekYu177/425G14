library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pipeline_int_register is
  port (
    clock : in std_logic;
    reset : in std_logic;

    pc_in : in integer;
    pc_out : out integer
  );
end pipeline_int_register;

architecture arch of pipeline_int_register is
begin
  process (clock, reset)
  begin
    if reset = '1' then
      pc_in <= 0;
    elsif clock'event and clock = '1' then
      pc_out <= pc_in;
    end if;
  end process;
end arch;
