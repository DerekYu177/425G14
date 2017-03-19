library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity instruction_fetch_stage is
  port(
  clock : in std_logic;
  reset : in std_logic;
  initializing : in std_logic;

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
  program_counter_valid : out std_logic
  );
end instruction_fetch_stage;

architecture arch of instruction_fetch_stage is

  signal program_counter : std_logic_vector(31 downto 0) := (others => '0');

  begin
    async_reset : process(reset, clock, jump_taken)
    begin
      if (reset = '1') then
        read_instruction <= '0';
        updated_program_counter <= (others => '0');
        program_counter <= (others => '0');
        program_counter_valid <= '0';
      elsif (initializing = '0' and clock'event and clock = '1') then
        if (jump_taken = '1') then
          program_counter <= jump_program_counter;
        else
          program_counter <= std_logic_vector(to_unsigned(to_integer(unsigned(program_counter)) + 4, 32));
        end if;

        program_counter_valid <= '1';
        read_instruction <= '1';
        updated_program_counter <= program_counter;
      end if;
    end process;

  read_instruction_address <= program_counter;
  instruction_out <= instruction_in;

end architecture;
