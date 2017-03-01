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
  program_in_finished : in std_logic;

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

-- binary logic vectors for reading text to std_logic_vector
signal program_binary_data : std_logic_vector(31 downto 0) := (others => '0');

-- read/write control signal
signal write_finished : boolean := false;

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
    program_in_finished => program_in_finished,

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

  read_program : process
    file program : text;
    variable line_number : line;
    variable line_content : string(1 to data_size);
    variable i : integer := 0;
    variable char : character := '0';
  begin
    if reset = '1' then
      file_open(program, "program.txt", READ_MODE);
      while (not endfile(program)) loop
        wait until clock'event and clock = '1';
        readline(program, line_number);
        read(line_number, line_content);

        -- convert string to std_logic_vector
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
      file_close(program);
      program_in_finished <= '1';
    end if;
    wait;
  end process read_program;

  write_register_memory_files : process
    file register_file : text;
    file memory : text;
    variable line_number_register, line_number_memory : line;
    variable line_content_register, line_content_memory : string(1 to data_size); -- could there be a big/little endian conflict here?
    variable i,j : integer := 0;
  begin
    if program_execution_finished = '1' then
      file_open(register_file, "register_file.txt", WRITE_MODE);
      file_open(memory, "memory.txt", WRITE_MODE);
      wait until clock'event and clock = '1';
      while (not write_finished) loop

        if (register_out_finished = '0') then
          -- convert from std_logic_vector back to string
          for i in 1 to data_size loop          --
            if (register_out(i) = '0') then
              line_content_register(data_size - i) := '0';
            else
              line_content_register(data_size - i) := '1';
            end if;
          end loop;

          write(line_number_register, line_content_register);
          writeline(register_file, line_number_register);
        else
          -- register write finished
          file_close(register_file);
        end if;

        if (memory_out_finished = '0') then
          -- convert from std_logic_vector back to string
          for j in 1 to data_size loop          --
            if (memory_out(j) = '0') then
              line_content_memory(data_size - j) := '0';
            else
              line_content_memory(data_size - j) := '1';
            end if;
          end loop;

          write(line_number_memory, line_content_memory);
          writeline(memory, line_number_memory);
        else
          -- memory write finished
          file_close(memory);
        end if;

        if (register_out_finished = '1' and memory_out_finished = '1') then
          write_finished <= true;
        end if;

      end loop;
    end if;
  end process write_register_memory_files;

  test_process : process
  begin
    report "simulation starting";
    -- first try reading from a program with a single line of text
    reset <= '1';
    -- wait the appropriate amount of clock cycles for program to be sent
    wait until program_in_finished = '1';
    -- wait until the pipeline is finished with it's calculation
    wait until program_execution_finished = '1';
    -- we'll have to manually check the file?
	end process;

end architecture behavior;
