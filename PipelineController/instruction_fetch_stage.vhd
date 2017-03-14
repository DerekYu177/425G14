library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity instruction_fetch_stage is
  port(
  clock : in std_logic;
  reset : in std_logic;

  -- instruction memory interface --
  read_instruction_address : out integer;
  read_instruction : out std_logic;
  instruction_in : in std_logic_vector(31 downto 0);
  wait_request : in std_logic;

  -- pipeline interface --
  jump_program_counter : in integer;
  jump_taken : in std_logic;
  instruction_out : out std_logic_vector(31 downto 0);
  updated_program_counter : out integer;
  program_counter_valid : out std_logic
  );
end instruction_fetch_stage;

architecture arch of instruction_fetch_stage is
  begin
    async_reset : process(reset)
    begin
      if (reset = '1') then
        read_instruction <= '0';
        read_instruction_address <= '0';
        updated_program_counter <= 0;
        program_counter_valid <= '0';
      end if;
    end process;

    pc_incrementer : process(clock, jump_taken)
    begin
      if (clock'event and clock = '1') then
        if (jump_taken = '1') then
          updated_program_counter <= jump_program_counter;
          program_counter_valid <= '1';
        else
          updated_program_counter <= program_counter + 4;
          program_counter_valid <= '1';
        end if;
      end if;
    end process;

    read_instruction <= '1';
    read_instruction_address <= program_counter;

    fetch_instruction : process(wait_request)
    begin
      if (wait_request'event) then
        instruction_out <= instruction_in;
        read_instruction <= '0';
      end if;
    end process;

end architecture;
