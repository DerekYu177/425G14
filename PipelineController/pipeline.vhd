library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pipeline is
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
end pipeline;

architecture arch of pipeline is
  type state_type is (
    ready, initializing, finishing,
    instruction_fetch, instruction_decode, execute, memory, writeback
  );

  signal present_state, next_state : state_type;
  -- signal if_id, id_ex, ex_m, m_wb : std_logic_vector(31 downto 0);

  signal program_counter : integer := 0;

  -- read/write control signal
  constant memory_size : integer := 8192;
  constant register_size : integer := 32;
  signal memory_line_counter : integer := 0;
  signal register_line_counter : integer := 0;
  signal read_write_finished : boolean := false;

  begin

    async_operation : process(clock, reset)
    begin
      if reset = '1' then
        present_state <= initializing;
      elsif (clock'event and clock = '1') then
        present_state <= next_state;
      end if;
    end process;

    pipeline_state_logic : process (clock, reset, present_state, program_in_finished)
    begin
      case present_state is
        when initializing =>

          if program_in_finished = '1' then
            next_state <= ready;
          else
            next_state <= initializing;
          end if;

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

          -- if the program as completed execution
          if (program_counter = 1) then
            next_state <= finishing;
          else
            -- what should the next state be here?
            next_state <= ready;
          end if;

        when finishing =>
          if (not read_write_finished) then
            next_state <= finishing;
          else
            next_state <= ready;
          end if;

      end case;
    end process;

    pipeline_functional_logic : process (clock, reset, present_state, program_in)
    begin
      case present_state is
        when initializing =>
          if clock'event and clock = '1' then
            -- TODO : feed line by line into the instruction memory and the data memory
          end if;

        when finishing =>
          if (clock'event and clock = '1') then
            -- TODO : feed line by line into output for both memory and register
            memory_line_counter <= memory_line_counter + 1;
            register_line_counter <= register_line_counter + 1;
            if (memory_line_counter = memory_size and register_line_counter > register_size) then
              read_write_finished <= true;
            end if;
          end if;
        
        when others =>
          -- TODO : this.
      end case;
    end process;

end arch;
