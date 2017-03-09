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
    ready, initializing, finishing,
    instruction_fetch, instruction_decode, execute, memory, writeback
  );

  signal present_state, next_state : state_type;
  -- signal if_id, id_ex, ex_m, m_wb : std_logic_vector(31 downto 0);

  -- INTERNAL CONTROL SIGNALS --
  signal program_counter : integer := 0;

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
         program_counter <= 0;

         -- ensuring that pipeline registers are clear
         if_id <= (others => '0');
         id_ex_1 <= (others => '0');
         id_ex_2 <= (others => '0');
         ex_mem <= (others => '0');
         mem_wb <= (others => '0');

        when instruction_fetch =>
          instr_memory_memread <= '1';
          instr_memory_address <= program_counter;

          -- wait for the instruction memory to be finished
          if waitrequest'event and waitrequest = '0' then
            if_id <= instr_memory_readdata;
          end if;

          program_counter <= program_counter + 4;
          next_state <= instruction_decode;

        when instruction_decode =>
          -- TODO: add load/store logic here so we know how to approach the register file

          -- TODO: translate the register location to an integer range


          if load = '1' then

            -- read from register file
            reg_writereg <= '0';
            reg_readreg1 <= to_integer(unsigned(if_id));

            -- put register file output onto pipeline register
            id_ex_1 <= reg_readdata1;


          elsif store = '1' then

            -- write to register file
            reg_writereg <= '1';
            reg_readreg1 <= to_integer(unsigned(if_id));

          end if;

          next_state <= execute;

        when execute =>
          next_state <= memory;

        when memory =>
          next_state <= writeback;

        when writeback =>

          -- if the program as completed execution
          if (program_counter = 1) then
            program_execution_finished <= '1';
            next_state <= finishing;
          else
            -- what should the next state be here?
            next_state <= ready;
          end if;

        when finishing =>
          if (not read_write_finished) then
            next_state <= finishing;
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
