library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity pipeline is
  port(
    clock : in std_logic;
    reset : in std_logic;

    -- input is the binary file produced by the Assembler --
    instruction : in std_logic_vector (31 downto 0)

    -- output is the register file and the data file --
  );
end pipeline;
