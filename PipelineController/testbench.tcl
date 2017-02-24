library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity pipeline_tb is
end pipeline_tb;

architecture behavior of pipeline_tb is

component pipeline is
  port(
  clock : in std_logic;
  reset : in std_logic;

  -- inputs --
  program_in : in std_logic_vector(31 downto 0);
  memory_in : in std_logic_vector(31 downto 0);
  program_in_finished : in std_logic;
  memory_in_finished : in std_logic;

  -- outputs --
  program_execution_finished : out std_logic;
  memory_out_finished : out std_logic;
  register_out_finished : out std_logic;
  memory_out : out std_logic_vector(31 downto 0);
  register_out : out std_logic_vector(31 downto 0)
  );
end component;

-- constants
constant clock_period : time := 1 ns;
constant memory_size : integer range 0 to 8191;

-- these are high level control signals
signal PROGRAM_INITIALIZE : std_logic;
signal PROGRAM_INITIALIZE_FINISHED : std_logic;
signal PROGRAM_COUNTER : integer;
signal PROGRAM_FINISHED : std_logic;

begin

  clock_process : process
  begin
    clock <= '0';
    wait for clock_period / 2;
    clock <= '1';
    wait for clock_period / 2;
  end process;

  read_program : process (ready)
    file program : TEXT open READ_MODE is "program.txt";
    variable read_line : LINE;
    variable line_output : LINE;
  begin
    loop
      if ready = '1' then
        exit when endfile(program);
        readline(program, line_output);
        -- do something here with our value in line_output
      end if;
    end loop;
    wait;
  end process read_program;

  write_register_file : process (PROGRAM_FINISHED)
    file register_file : TEXT open WRITE_MODE is "register_file.txt";
    variable write_line : LINE;
    variable line_input : LINE;
  begin
    if PROGRAM_FINISHED = '1' then
      -- plenty of conditions here
    end if;
  end process write_register_file;

  --TODO: read/write methods to the memory file "memory.txt"
  initialize_memory_file : process (PROGRAM_INITIALIZE)
    file memory_file : TEXT open WRITE_MODE is "memory.txt";
    variable write_line : LINE;
    variable line_input : LINE;
  begin
    if PROGRAM_INITIALIZE = '1' then
        for write_line in memory_size loop
          write( )
        end loop;
        PROGRAM_INITIALIZE_FINISHED <= '1';
    end if;
    -- ensure we close the memory file so that we can read from it in the future
  end process initialize_memory_file;

end architecture behavior;
