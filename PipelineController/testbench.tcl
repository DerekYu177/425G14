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
constant data_size : integer := 32;
constant memory_size : integer := 8192;
constant register_size : integer := 32;
constant memory_line_counter : integer := 0;
constant register_line_counter : integer := 0;

-- binary logic vectors for reading text to std_logic_vector
signal program_binary_data : std_logic_vector(31 downto 0) := (others => '0');

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
signal register_out : std_logic_vector(31 downto 0);

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

  read_program : process (reset)
    file program : TEXT is in "program.txt";
    variable line_number : LINE;
    variable line_content : REAL;
    variable i : integer := '0';
    variable char : character := '0';
  begin
    if reset = '1' then
      while (not endfile(program)) loop
        wait until clock'event and clock = '1';
        readline(program, line_number);
        read(line_number, line_content);

        -- for each text character in the line_content
        -- convert into std_logic vector to be sent
        for i in 1 to data_size loop
          char := line_content(i);
          if (char = '0') then
            program_binary_data(data_size - i) <= '0';
          else
            program_binary_data(data_size - i) <= '1';
          end if;
        end loop;

        program_in <= program_binary_data;
      end loop;
    end if;
    wait;
  end process read_program;

  write_register_file : process (program_execution_finished)
    file register_file : TEXT is out "register_file.txt";
    variable outline : LINE;
  begin
    if program_execution_finished = '1' then
      wait until clock'event and clock = '1';
      write(outline, register_out); -- do we require field(width) and digits(natural)?
      writeline(register_file, outline);
      -- plenty of conditions here
      -- increment counter
      -- if counter = counter_max_value, stop
    end if;
  end process write_register_file;

  write_memory_file : process (program_execution_finished)
    file memory : TEXT is out "memory.txt";
    variable outline : LINE;
  begin
      if program_execution_finished = '1' then
      wait until clock'event and clock = '1';
      write(outline, memory_out); -- do we require field(width) and digits(natural)?
      writeline(memory, outline);
      -- plenty of conditions here
      -- increment counter
      -- if counter = counter_max_value, stop
    end if;
  end process write_memory_file;

end architecture behavior;
