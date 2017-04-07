library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity instruction_fetch_stage is
  port(
  clock : in std_logic;
  reset : in std_logic;

  -- instruction memory interface --
  read_instruction_address : out std_logic_vector(31 downto 0);
  read_instruction : out std_logic;
  instruction_in : in std_logic_vector(31 downto 0);
  wait_request : in std_logic;

  -- pipeline interface --
  jump_program_counter : in std_logic_vector(31 downto 0);
  jump_taken : in std_logic;
  instruction_out : out std_logic_vector(31 downto 0);
  updated_program_counter : out std_logic_vector(31 downto 0);
  program_counter_valid : out std_logic;

  -- stall interface --
  stall : in std_logic;
  stall_instruction : in std_logic_vector(31 downto 0)
  );
end instruction_fetch_stage;

architecture arch of instruction_fetch_stage is

  signal program_counter : std_logic_vector(31 downto 0) := (others => '0');

  begin
    async_reset : process(reset, clock, jump_taken)
    begin
      if (reset = '1') then
        read_instruction <= '0';
        program_counter <= (others => '0');
        program_counter_valid <= '0';
      elsif (stall = '1') then
        null;
      elsif (stall = '0' and clock'event and clock = '0') then
        if (jump_taken = '1') then
          program_counter <= jump_program_counter;
        else
          program_counter <= std_logic_vector(to_unsigned(to_integer(unsigned(program_counter)) + 4, 32));
        end if;

        program_counter_valid <= '1';
        read_instruction <= '1';
      end if;
    end process;

  updated_program_counter <= program_counter;
  read_instruction_address <= program_counter;

  update_instruction_out : process (clock, reset)
  begin
    if reset = '1' then
      instruction_out <= (others => '0');
    elsif stall = '1' then
      instruction_out <= stall_instruction;
    else
      instruction_out <= instruction_in;
    end if;
  end process;

end architecture;
