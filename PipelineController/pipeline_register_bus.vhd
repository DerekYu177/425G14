library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pipeline_register_bus is
  port (
    clock : in std_logic;
    reset : in std_logic;

    stage_1_data_1 : in std_logic_vector(31 downto 0);
    stage_1_data_2 : in std_logic_vector(31 downto 0);
    stage_1_scratch : in std_logic_vector(31 downto 0);
    stage_1_hi_data : in std_logic_vector(31 downto 0);
    stage_1_lo_data : in std_logic_vector(31 downto 0);
    stage_1_pc_value : in integer;
    stage_1_address_value : in integer;
    stage_1_pc_valid : in std_logic;
    stage_1_address_valid : in std_logic;
    stage_1_load_memory_valid : in std_logic;
    stage_1_store_memory_valid : in std_logic;
    stage_1_store_register : in std_logic;
    stage_1_hi_store : in std_logic;
    stage_1_lo_store : in std_logic;

    stage_2_data_1 : out std_logic_vector(31 downto 0);
    stage_2_data_2 : out std_logic_vector(31 downto 0);
    stage_2_scratch : out std_logic_vector(31 downto 0);
    stage_2_hi_data : out std_logic_vector(31 downto 0);
    stage_2_lo_data : out std_logic_vector(31 downto 0);
    stage_2_pc_value : out integer;
    stage_2_address_value : out integer;
    stage_2_pc_valid : out std_logic;
    stage_2_address_valid : out std_logic;
    stage_2_load_memory_valid : out std_logic;
    stage_2_store_memory_valid : out std_logic;
    stage_2_store_register : out std_logic
    stage_2_hi_store : out std_logic;
    stage_2_lo_store : out std_logic
  );
end pipeline_register_bus;

architecture arch of pipeline_register_bus is
begin
  process (clock, reset)
  begin
    if reset = '1' then
      stage_2_data_1 <= (others => '0');
      stage_2_data_2 <= (others => '0');
      stage_2_hi_store <= (others => '0');
      stage_2_lo_store <= (others => '0');
      stage_2_scratch <= (others => '0');
      stage_2_pc_value <= 0;
      stage_2_address_value <= 0;
      stage_2_pc_valid <= '0';
      stage_2_address_valid <= '0';
      stage_2_load_memory_valid <= '0';
      stage_2_store_memory_valid <= '0';
      stage_2_store_register <= '0';
      stage_2_hi_store <= '0';
      stage_2_lo_store <= '0';
    elsif clock'event and clock = '1' then
      stage_2_data_1 <= stage_1_data_1;
      stage_2_data_2 <= stage_1_data_2;
      stage_2_scratch <= stage_1_scratch;
      stage_2_hi_data <= stage_1_hi_data;
      stage_2_lo_data <= stage_1_lo_data;
      stage_2_pc_value <= stage_1_pc_value;
      stage_2_address_value <= stage_1_address_value;
      stage_2_pc_valid <= stage_1_pc_valid;
      stage_2_address_valid <= stage_1_address_valid;
      stage_2_load_memory_valid <= stage_1_load_memory_valid;
      stage_2_store_memory_valid <= stage_1_store_memory_valid;
      stage_2_store_register <= stage_1_store_register;
      stage_2_hi_store <= stage_1_hi_store;
      stage_2_lo_store <= stage_1_lo_store;
    end if;
  end process;
end arch;
