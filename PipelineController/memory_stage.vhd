entity memory_stage is
  port(
    clock : in std_logic;
    reset : in std_logic;

    -- data memory interface --
    data_memory_writedata : out std_logic_vector(31 downto 0);
    data_memory_address : out integer range 0 to ram_size-1;
    data_memory_memwrite : out std_logic;
    data_memory_memread : out std_logic;
    data_memory_readdata : in std_logic_vector(31 downto 0);
    data_memory_waitrequest : in std_logic;

    -- pipeline interface --
    data_in : in std_logic_vector(31 downto 0);
    data_in_address : in integer;
    data_in_address_valid : in std_logic;
    data_out : out std_logic_vector(31 downto 0);
    data_out_address : out integer;
    data_out_address_valid : out std_logic;
    load_memory_valid : in std_logic;
    store_memory_valid : in std_logic
  );
end memory_stage;

architecture arch of memory_stage is
begin
  process(clock, load_memory_valid, store_memory_valid, data_in_address_valid, reset)
  begin
    if reset = '1' then
      data_out_address_valid <= '0';
      data_out_address <= 0;
      data_out <= (others => '0');
    end if;

    if (load_memory_valid = '1' and data_in_address_valid = '1') then
      data_out_address <= data_in_address;
      data_out_address_valid <= '1';
      data_memory_address <= to_integer(unsigned(data_in));
      data_memory_memread <= '1';
      data_out <= data_memory_readdata;
    end if;

    if (store_memory_valid = '1' and data_in_address_valid = '1') then
      data_memory_writedata <= data_in;
      data_memory_address <= data_in_address;
      data_memory_memwrite <= '1';
    end if;

    if (data_in_address_valid = '1' and store_memory_valid = '0' and load_memory_valid = '0') then
      -- data is not meant for the MEM and is instead meant for the WB.
      data_out <= data_in;
      data_out_address <= data_in_address;
      data_out_address_valid <= data_in_address_valid;
    end if;
  end process;
end architecture;
