library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity pipeline_tb is
end pipeline_tb;

architecture behavior of pipeline_tb is

component PIPELINE
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

-- input port map signals
signal clock : std_logic;
signal reset : std_logic;
signal program_in : std_logic_vector(31 downto 0);
signal memory_in : std_logic_vector(31 downto 0);
signal program_in_finished : std_logic;
signal memory_in_finished : std_logic;

-- output port map signals
signal program_execution_finished : std_logic;
signal memory_out_finished : std_logic;
signal register_out_finished : std_logic;
signal memory_out : std_logic_vector(31 downto 0);
signal register_out : std_logic_vector(31 downto 0)

begin

  P : PIPELINE port map (
    clock => clock,
    reset => reset,
    program_in => program_in,
    memory_in => memory_in,
    program_in_finished => program_in_finished,
    memory_in_finished => memory_in_finished,

    program_execution_finished => program_execution_finished,
    memory_out_finished => memory_out_finished,
    register_out_finished => register_out_finished,
    memory_out => memory_out,
    register_out => register_out
  );

  clock_process : process
  begin
    clock <= '0';
    wait for clock_period / 2;
    clock <= '1';
    wait for clock_period / 2;
  end process;

  read_program : process (ready)
    file program : TEXT is in "program.txt";
    variable read_line : LINE;
    variable line_output : REAL;
  begin
    wait until clock'event and clock = '1';
    if (not endfile(program)) then
      readline(program, read_line);
      read(read_line, line_output);

      -- there is probably going to be a real -> std_logic_vector conflict here
      program_in <= line_output;
    end if;
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
