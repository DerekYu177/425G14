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

  -- STATE DEFINITION --
  type state_type is (
    init, processor, fini
  );

  signal present_state, next_state : state_type;
  -- signal if_id, id_ex, ex_m, m_wb : std_logic_vector(31 downto 0);

  -- INTERNAL CONTROL SIGNALS --
  signal program_counter : integer := 0;
  signal global_reset : std_logic := 0;

  -- read/write control signal
  signal memory_line_counter : integer := 0;
  signal register_line_counter : integer := 0;
  signal read_write_finished : boolean := false;

  -- pipeline constants --
  constant data_size : integer := 8192;
  constant instruction_size : integer := 1024;
  constant register_size : integer := 32;

  -- PIPELINE REGISTERS --
  signal if_id : std_logic_vector(31 downto 0);
  signal id_ex_1 : std_logic_vector(31 downto 0);
  signal id_ex_2 : std_logic_vector(31 downto 0);
  signal ex_mem : std_logic_vector(31 downto 0);
  signal mem_wb : std_logic_vector(31 downto 0);

  -- pipeline registers for program counter (integer)
  signal if_id_pc : integer;
  signal id_ex_pc : integer;
  signal ex_mem_pc : integer;
  signal mem_wb_pc : integer;

  -- COMPONENT INTERNAL SIGNALS --
  signal instr_memory_writedata : std_logic_vector(31 downto 0);
  signal instr_memory_address : integer range 0 to ram_size-1;
  signal instr_memory_memwrite : std_logic;
  signal instr_memory_memread : std_logic;
  signal instr_memory_readdata : std_logic_vector(31 downto 0);
  signal instr_memory_waitrequest : std_logic;

  signal data_memory_writedata : std_logic_vector(31 downto 0);
  signal data_memory_address : integer range 0 to ram_size-1;
  signal data_memory_memwrite : std_logic;
  signal data_memory_memread : std_logic;
  signal data_memory_readdata : std_logic_vector(31 downto 0);
  signal data_memory_waitrequest : std_logic;

  signal reg_writedata : std_logic_vector(31 downto 0);
  signal reg_readreg1 : integer range 0 to 31;
  signal reg_readreg2 : integer range 0 to 31;
  signal reg_writereg : integer range 0 to 31;
  signal reg_regwrite : std_logic;
  signal reg_readdata1 : std_logic_vector(31 downto 0);
  signal reg_readdata2 : std_logic_vector(31 downto 0);

  signal ALU_reset : std_logic;
  signal ALU_instruction : std_logic_vector(31 downto 0);
  signal ALU_operand1 : std_logic_vector(31 downto 0);
  signal ALU_operand2 : std_logic_vector(31 downto 0);
  signal ALU_NPC : std_logic_vector(31 downto 0);
  signal ALU_output : std_logic_vector(31 downto 0);

  -- DECLARING COMPONENTS --

  component instruction_memory
    generic(
  		ram_size : integer := instruction_size;
  		mem_delay : time := 10 ns;
  		clock_period : time := 1 ns
  	);
  	port(
  		clock : in std_logic;
  		writedata : in std_logic_vector(31 downto 0);

  		address : in integer range 0 to ram_size-1;
  		memwrite : in std_logic;
  		memread : in std_logic;
  		readdata : out std_logic_vector(31 downto 0);
  		waitrequest : out std_logic
  	);
  end component;

  component data_memory
    generic(
      ram_size : integer := data_size;
      mem_delay : time := 10 ns;
      clock_period : time := 1 ns
    );
  	port(
  		clock : in std_logic;
  		writedata : in std_logic_vector(31 downto 0);

  		address : in integer range 0 to ram_size-1;
  		memwrite : in std_logic;
  		memread : in std_logic;
  		readdata : out std_logic_vector(31 downto 0);
  		waitrequest : out std_logic
  	);
  end component;

  component registers
    port(
      clock : in std_logic;
  		writedata : in std_logic_vector(31 downto 0);
  		readreg1 : in integer range 0 to 31;
  		readreg2 : in integer range 0 to 31;
  		writereg : in integer range 0 to 31;

  		regwrite : in std_logic;
  		readdata1 : out std_logic_vector(31 downto 0);
  		readdata2 : out std_logic_vector(31 downto 0)
    );
  end component;

  component ALU is
    port(
      clock : in std_logic;
      reset : in std_logic;
      ALU_instruction : in std_logic_vector(31 downto 0);
      ALU_operand1 : in std_logic_vector(31 downto 0);
      ALU_operand2 : in std_logic_vector(31 downto 0);
      ALU_NPC : in std_logic_vector(31 downto 0);
      ALU_output : out std_logic_vector(31 downto 0)
    );
  end component;

  -- DECLARING PIPELINE COMPONENTS --

  component instruction_fetch_stage is
    port(
      clock : in std_logic;
      reset : in std_logic;

      -- IO to satisfy instruction memory interface --
      wait_request : in std_logic;
      instruction : in std_logic_vector(31 downto 0);
      read_instruction_address : out std_logic_vector(31 downto 0);
      read_instruction : out std_logic;

      -- pipeline interface --
      id_if : out std_logic_vector(31 downto 0)
    );
  end component;

  component instruction_decode_stage is
    port(
      clock : in std_logic;
      reset : in std_logic;

      -- pipeline interface --
      if_id : in std_logic_vector(31 downto 0);
      id_ex_reg_1 : out std_logic_vector(31 downto 0);
      id_ex_reg_2 : out std_logic_vector(31 downto 0)
    );
  end component;

  component execute_stage is
    port(
      clock : in std_logic;
      reset : in std_logic;

      -- pipeline interface --
      id_ex : in std_logic_vector(31 downto 0);
      ex_mem : out std_logic_vector(31 downto 0)
    );
  end component;

  component memory_stage is
    port(
      clock : in std_logic;
      reset : in std_logic;

      -- component specific interface requirements --

      -- pipeline interface --
      ex_mem : in std_logic_vector(31 downto 0);
      mem_wb : out std_logic_vector(31 downto 0)
    );
  end component;

  component write_back_stage is
    port(
      clock : in std_logic;
      reset : in std_logic;

      -- component specific interface requirements --
      writedata : in std_logic_vector(31 downto 0);

      -- interface specific components --
      waitrequest : in std_logic;
      write_address : out integer range 0 to ram_size-1;
      memwrite : out std_logic;

      -- pipeline interface --
      ex_mem : in std_logic_vector(31 downto 0);
      mem_wb : out std_logic_vector(31 downto 0)
    );
  end component;

  begin

    -- COMPONENTS --

    instruction_memory :  instruction_memory
    port map(
      clock,
      instr_memory_writedata,
      instr_memory_address,
      instr_memory_memwrite,
      instr_memory_memread,
      instr_memory_readdata,
      instr_memory_waitrequest
    );

    data_memory : data_memory
    port map(
      clock,
      data_memory_writedata,
      data_memory_address,
      data_memory_memwrite,
      data_memory_memread,
      data_memory_readdata,
      data_memory_waitrequest
    );

    registers : registers
    port map(
      clock,
      reg_readreg1,
      reg_readreg2,
      reg_writereg,
      reg_regwrite,
      reg_readdata1,
      reg_readdata2
    );

    ALU : ALU
    port map(
      clock,
      ALU_reset,
      ALU_instruction,
      ALU_operand1,
      ALU_operand2,
      ALU_NPC,
      ALU_output
    );

    -- BEGIN PROCESSES --

    async_operation : process(clock, reset)
    begin
      if reset = '1' then
        present_state <= init;
      elsif (clock'event and clock = '1') then
        present_state <= next_state;
      end if;
    end process;

    pipeline_state_logic : process (clock, reset, present_state, program_in_finished)
    begin
      case present_state is
        when init =>
          if program_in_finished = '1' then
            next_state <= processor;
          else
            next_state <= init;
          end if;

        when processor =>
          -- this is where forwarding and hazard detection will take place --

          if (program_counter = 1) then
            program_execution_finished <= '1';
            next_state <= fini;
          else
            -- what should the next state be here?
            next_state <= processor;
          end if;
          null;

        when fini =>
          if (not read_write_finished) then
            next_state <= fini;
          else
            memory_out_finished <= '1';
            register_out_finished <= '1';
            next_state <= ready;
          end if;

      end case;
    end process;

    pipeline_functional_logic : process (clock, reset, present_state, program_in)
    begin
      case present_state is
        when init =>
          if clock'event and clock = '1' then
            -- TODO : feed line by line into the instruction memory and the data memory
          end if;

          -- reset all components
          global_reset <= '1';

          -- initialize PC counter
          program_counter <= 0;

        when fini =>
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
          null;
      end case;
    end process;

end arch;
