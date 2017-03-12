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
  instruction : in std_logic_vector(31 downto 0);
  wait_request : in std_logic;

  -- pipeline interface --
  if_id : out std_logic_vector(31 downto 0);

  -- global modifier --
  program_counter : in integer;
  jump_program_counter : in integer;
  jump_taken : in std_logic;
  updated_program_counter : out integer
  );
end instruction_fetch_stage;

architecture arch of instruction_fetch_stage is
  begin
    process
    begin
      if (jump_taken = '1') then
        updated_program_counter <= jump_program_counter;
      else
        updated_program_counter <= program_counter + 4;
      end if;
    end process;
end architecture;
