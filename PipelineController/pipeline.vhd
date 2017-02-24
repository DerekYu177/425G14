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
    ready, initializing, finished,
    instruction_fetch, instruction_decode, execute, memory, writeback
  );

  signal present_state, next_state : state_type;
  -- signal if_id, id_ex, ex_m, m_wb : std_logic_vector(31 downto 0);

  signal program_counter : integer := 0;

  begin

    async_operation : process(clock, reset)
    begin
      if reset = '1' then
        next_state <= initializing;
      elsif (clock'event and clock = '1') then
        present_state <= next_state;
      end if;
    end process;

    pipeline_setup_teardown : process(clock, reset, present_state, program_in, memory_in, program_in_finished, memory_in_finished)
    begin
      case present_state is
        when initializing =>
          if (clock'event and clock = '1') then
            -- TODO : feed line by line into the instruction memory and the data memory
          end if;
        when others =>
          if program_in_finished = '0' and memory_in_finished = '0' then
            next_state <= initializing;
          end if;
      end case;
    end process;

    pipeline_state_logic : process(clock, present_state)
    begin
      case present_state is
        when initializing =>
          if program_in_finished = '1' and memory_in_finished = '1' then
            next_state <= ready;
          end if;
          -- else we stay in initializing according to the pipeline_initialize process
          -- TODO: can we make this better?

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

          -- if the program is finished, then we need to go to finished
          if (program_counter = 1) then
            next_state <= finished;
          end if;

          -- what should the next state be here?
          next_state <= ready;

        when finished =>
          next_state <= ready;

      end case;
    end process;

end arch;
