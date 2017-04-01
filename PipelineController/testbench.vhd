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

-- Input control signals
file program : text;
signal input_initalize_flag : std_logic := '0';
signal r_line_content_1 : std_logic_vector(31 downto 0);
signal r_line_content_2 : std_logic_vector(31 downto 0);

-- input FSM --
type input_state_type is (
  input_initialize,
  read_1, read_2,
  end_read
);

signal present_state, next_state : input_state_type;

-- Output control signals
file register_file, memory : text;
signal register_open_file : std_logic := '0';
signal memory_open_file : std_logic := '0';
signal output_initialize_flag : std_logic := '0';
constant c_width : natural := 32;
constant b_width : natural := 8;

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

  read_program_state_logic : process(clock, present_state)
  begin
    case present_state is
      when input_initialize =>
        next_state <= read_1;

      when read_1 =>
        if endfile(program) then
          next_state <= end_read;
        else
          next_state <= read_2;
        end if;

      when read_2 =>
        next_state <= read_1;

      when end_read =>
        null;

    end case;

    if clock'event and clock = '1' then
      present_state <= next_state;
    end if;

  end process read_program_state_logic;

  read_program_functional_logic : process(present_state)
    variable v_program_line_1, v_program_line_2 : line;
    variable v_line_content_1, v_line_content_2 : std_logic_vector(31 downto 0);
  begin
    case present_state is
      when input_initialize =>
        reset <= '1';
        file_open(program, "program.txt", read_mode);

      when read_1 =>
        reset <= '0';

        if not endfile(program) then
          readline(program, v_program_line_1);
          read(v_program_line_1, v_line_content_1);
          r_line_content_1 <= v_line_content_1;
        end if;

        if input_initalize_flag = '1' then
          program_in <= r_line_content_2;
        else
          input_initalize_flag <= '1';
        end if;

      when read_2 =>
        program_in <= r_line_content_1;

        if not endfile(program) then
          readline(program, v_program_line_2);
          read(v_program_line_2, v_line_content_2);
          r_line_content_2 <= v_line_content_2;
        end if;

      when end_read =>
        program_in <= r_line_content_1;
        file_close(program);
        program_in_finished <= '1';

    end case;
  end process read_program_functional_logic;

  write_register_files : process(program_execution_finished, clock)
    -- Based on https://www.nandland.com/vhdl/examples/example-file-io.html
    variable v_register_line, v_memory_line : line;

  begin

    if program_execution_finished = '1' then

      if register_open_file = '0' and output_initialize_flag = '0' then
        register_open_file <= '1';
        memory_open_file <= '1';
        output_initialize_flag <= '1';
        file_open(register_file, "register_file.txt", write_mode);
        file_open(memory, "memory.txt", write_mode);
      end if;

      if clock'event and clock = '1' then

        if register_out_finished = '0' then
          write(v_register_line, register_out, right, c_width);
          writeline(register_file, v_register_line);
        end if;

        if memory_out_finished = '0' then
          write (v_memory_line, memory_out, right, b_width);
          writeline(memory, v_memory_line);
        end if;

      end if;

      if register_open_file = '1' and register_out_finished = '1' then
        register_open_file <= '0';
        file_close(register_file);
      end if;

      if memory_open_file = '1' and memory_out_finished = '1' then
        memory_open_file <= '0';
        file_close(memory);
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
