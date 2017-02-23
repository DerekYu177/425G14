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

    -- input is the binary file produced by the Assembler --
    instruction : in std_logic_vector (31 downto 0);

    -- output is the register file and the data file --
    done : out std_logic;
    ready : out std_logic
  );
end component;

signal PROGRAM_COUNTER : integer;

begin

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

  write_register_file : process(done)
    file rester : TEXT open WRITE_MODE is "register_file.txt";
    variable write_line : LINE;
    variable line_input : LINE;
  begin
    if done = '1' then
      -- plenty of conditions here
    end if;
  end process write_register_file;

  --TODO: read/write methods to the memory file "memory.txt"

end architecture behavior;
