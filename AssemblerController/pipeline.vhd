library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pipeline is
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
end pipeline;

architecture arch of pipeline is
  type state_type is (
    ready,
    instruction_fetch, instruction_decode, execute, memory, writeback
  );

  signal present_state, next_state : state_type;
  -- signal if_id, id_ex, ex_m, m_wb : std_logic_vector(31 downto 0);

  begin

    async_operation : process(clock, reset)
    begin
      if reset = '1' then
        -- what conditions do we need to have in ready mode?
        state <= ready;
      elsif (clock'event and clock = '1') then
        present_state <= next_state;
      end if;
    end process;

    state_logic : process(clock, present_state, instruction)
    begin
      case present_state is
        when ready =>
         -- ready condition?

        when instruction_fetch =>
          next_state <= instruction_decode;

        when instruction_decode =>
          next_state <= execute;

        when execute =>
          next_state <= memory;

        when memory =>
          next_state <= writeback;

        when writeback =>
          -- what should the next state be here?
          next_state <= ready;

      end case;
    end process;

end arch;
