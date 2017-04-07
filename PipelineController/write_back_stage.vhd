library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity write_back_stage is
  port(
    clock : in std_logic;
    reset : in std_logic;

    -- interface with register --
    reg_writedata : out std_logic_vector(31 downto 0);
    reg_writereg_address : out std_logic_vector(31 downto 0);
    reg_regwrite : out std_logic;
    write_hi_data : out std_logic_vector(31 downto 0);
    write_lo_data : out std_logic_vector(31 downto 0);
    write_hi : out std_logic;
    write_lo : out std_logic;

    -- pipeline interface --
    write_data : in std_logic_vector(31 downto 0);
    write_address : in std_logic_vector(31 downto 0);
    write_address_valid : in std_logic;
    store_register : in std_logic;

    -- pipeline interface for HI/LO --
    hi_data : in std_logic_vector(31 downto 0);
    lo_data : in std_logic_vector(31 downto 0);
    hi_store : in std_logic;
    lo_store : in std_logic
  );
end write_back_stage;

architecture arch of write_back_stage is
begin

  process(clock, reset)
  begin
    if reset = '1' then
      reg_regwrite <= '0';
      reg_writedata <= (others => '0');
      reg_writereg_address <= (others => '0');
    elsif clock'event and clock = '1' then
      -- write rising edge read falling edge
      if (store_register = '1' and write_address_valid = '1') then
        reg_regwrite <= '1';
        reg_writedata <= write_data;
        reg_writereg_address <= write_address;
      end if;

      if hi_store = '1' then
        write_hi <= '1';
        write_hi_data <= hi_data;
      end if;

      if lo_store = '1' then
        write_lo <= '1';
        write_lo_data <= lo_data;
      end if;
    end if;

  end process;
end arch;
