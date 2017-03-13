library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pipeline_register_bus is
  port (
    clock : in std_logic;
    reset : in std_logic;

    stage_1_data_1 : in std_logic_vector(31 downto 0);
    stage_1_data_2 : in std_logic_vector(31 downto 0);
    stage_1_pc_address : in integer;
    stage_1_pc_valid : in std_logic;
    stage_1_address_valid : in std_logic;
    stage_1_load_memory_valid : in std_logic;
    stage_1_store_memory_valid : in std_logic;
    stage_1_store_register : in std_logic;


    stage_2_data_1 : out std_logic_vector(31 downto 0);
    stage_2_data_2 : out std_logic_vector(31 downto 0);
    stage_2_pc_address : out integer;
    stage_2_pc_valid : out std_logic;
    stage_2_address_valid : out std_logic;
    stage_2_load_memory_valid : out std_logic;
    stage_2_store_memory_valid : out std_logic;
    stage_2_store_register : out std_logic
  );
end pipeline_register_bus;

architecture arch of pipeline_register_bus is
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
