library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pipeline_logic_register is
  port (
    clock : in std_logic;
    reset : in std_logic;

    data : in std_logic_vector(1 downto 0);
    data_out : out std_logic_vector(1 downto 0)
  );
end pipeline_logic_register;

architecture arch of pipeline_logic_register is
begin
  process (clock, reset)
  begin
    if reset = '1' then
      data <= (others => '0');
    elsif clock'event and clock = '1' then
      data_out <= data;
    end if;
  end process;
end arch;
