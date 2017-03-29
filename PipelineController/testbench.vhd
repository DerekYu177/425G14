library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

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
constant byte_size : integer := 8;

-- read/write
file register_file, memory : text;
signal open_file : std_logic := '0';
signal initialization : std_logic := '0';
constant c_width : natural := 32;
constant opening_line : std_logic_vector(c_width-1 downto 0) := (others => '1');

-- input port map signals
signal clock : std_logic := '0';
signal reset : std_logic := '0';
signal program_in : std_logic_vector(31 downto 0);
signal program_in_finished : std_logic := '0';

-- output port map signals
signal program_execution_finished : std_logic := '0';
signal memory_out_finished : std_logic := '0';
signal register_out_finished : std_logic := '0';
signal memory_out : std_logic_vector(31 downto 0);
signal register_out : std_logic_vector(31 downto 0);

begin

  P : PIPELINE port map (
    clock,
    reset,
    program_in,
    program_in_finished,

    program_execution_finished,
    memory_out_finished,
    register_out_finished,
    memory_out,
    register_out
  );

  clock_process : process
  begin
    clock <= '0';
    wait for clock_period / 2;
    clock <= '1';
    wait for clock_period / 2;
  end process;

  read_program : process
    file program : text; -- open read_mode is "program.txt"
    variable line_number : line;
    variable line_content : std_logic_vector(31 downto 0);
  begin
    reset <= '1';

    report "opening program";
    file_open(program, "program.txt", READ_MODE);

    report "endfile? : " & boolean'image(endfile(program));
    while (not endfile(program)) loop
      wait until clock'event and clock = '1';

      report "reading line from program";
      readline(program, line_number);
      read(line_number, line_content);

      report "writing program line to pipeline";
      program_in <= line_content;

      wait for clock_period;

    end loop;

    report "end of file";
    file_close(program);
    reset <= '0';
    program_in_finished <= '1';
    wait;
  end process read_program;

  -- write_register_memory_files : process(program_execution_finished, clock)
  --     -- Based on https://www.nandland.com/vhdl/examples/example-file-io.html
  --     variable v_register_line, v_memory_line : line;
  --
  -- begin
  --   if program_execution_finished = '1' then
  --
  --     if open_file = '0' then
  --       open_file <= '1';
  --       file_open(register_file, "register_file.txt", write_mode);
  --       file_open(memory, "memory.txt", write_mode);
  --     end if;
  --
  --     if clock'event and clock = '1' then
  --
  --       if (register_out_finished = '0') then
  --         write(v_register_line, register_out);
  --         writeline(register_file, v_register_line);
  --       end if;
  --
  --       if (memory_out_finished = '0') then
  --         write(v_memory_line, memory_out);
  --         writeline(memory, v_memory_line);
  --       end if;
  --     end if;
  --
  --     if open_file = '1' and memory_out_finished = '1' and register_out_finished = '1' then
  --       file_close(memory);
  --       file_close(register_file);
  --     end if;
  --
  --   end if;
  -- end process write_register_memory_files;

  write_register_files : process(program_execution_finished, clock)
      -- Based on https://www.nandland.com/vhdl/examples/example-file-io.html
      variable v_register_line, v_memory_line : line;

  begin
    if program_execution_finished = '1' then

      if open_file = '0' and initialization = '0' then
        open_file <= '1';
        initialization <= '1';
        file_open(register_file, "register_file.txt", write_mode);

        write(v_register_line, opening_line, right, c_width);
        writeline(register_file, v_register_line);
      end if;

      if clock'event and clock = '1' then

        if register_out_finished = '0' then
          write(v_register_line, register_out, right, c_width);
          writeline(register_file, v_register_line);
        end if;

      end if;

      if open_file = '1' and register_out_finished = '1' then
        write(v_register_line, opening_line, right, c_width);
        writeline(register_file, v_register_line);

        open_file <= '0';
        file_close(register_file);
      end if;

    end if;
  end process write_register_files;

  test_process : process
  begin
    report "simulation starting";
    -- first try reading from a program with a single line of text
    -- wait the appropriate amount of clock cycles for program to be sent
    wait until program_in_finished = '1';
    -- wait until the pipeline is finished with it's calculation
    wait until program_execution_finished = '1';
    -- we'll have to manually check the file?
    end process;

end architecture behavior;
