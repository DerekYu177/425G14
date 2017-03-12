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

  -- INTERNAL CONTROL SIGNALS --
  signal program_counter : integer := 0;
  signal global_reset : std_logic := 0;

  -- read/write control signal
  signal instruction_line_in_counter : integer := 0;
  signal memory_line_counter : integer := 0;
  signal register_line_counter : integer := 0;

  -- pipeline constants --
  constant data_size : integer := 8192;
  constant instruction_size : integer := 1024;
  constant register_size : integer := 32;

  -- pipeline register IO --
  signal if_id_in, if_id_out : std_logic_vector(31 downto 0);
  signal id_ex_1_in, id_ex_1_out : std_logic_vector(31 downto 0);
  signal id_ex_2_in, id_ex_2_out : std_logic_vector(31 downto 0);
  signal ex_mem_in, ex_mem_out : std_logic_vector(31 downto 0);
  signal mem_wb_in, mem_wb_out : std_logic_vector(31 downto 0);

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

      -- instruction memory interface --
      read_instruction_address : out std_logic_vector(31 downto 0);
      read_instruction : out std_logic;
      instruction : in std_logic_vector(31 downto 0);
      wait_request : in std_logic;

      -- pipeline interface --
      if_id : out std_logic_vector(31 downto 0);

      -- global output --
      updated_program_counter : out integer
    );
  end component;

  component instruction_decode_stage is
    port(
      clock : in std_logic;
      reset : in std_logic;

      -- register interface --
      read_1_address : out integer range 0 to 31;
      read_2_address : out integer range 0 to 31;
      register_1 : in std_logic_vector(31 downto 0);
      register_2 : in std_logic_vector(31 downto 0);

      -- pipeline interface --
      if_id : in std_logic_vector(31 downto 0);
      id_ex_reg_1 : out std_logic_vector(31 downto 0);
      id_ex_reg_2 : out std_logic_vector(31 downto 0)
    );
  end component;

  -- This is to be replaced by the ALU --
  component execute_stage is
    port(
      clock : in std_logic;
      reset : in std_logic;

      -- pipeline interface --
      operand_1 : in std_logic_vector(31 downto 0);
      operand_2 : in std_logic_vector(31 downto 0);
      ex_mem_1 : out std_logic_vector(31 downto 0);
      ex_mem_2 : out std_logic_vector(31 downto 0)
    );
  end component;

  component memory_stage is
    port(
      clock : in std_logic;
      reset : in std_logic;

      -- data memory interface --
      data_memory_writedata : out std_logic_vector(31 downto 0);
      data_memory_address : out integer range 0 to ram_size-1;
      data_memory_memwrite : out std_logic;
      data_memory_memread : out std_logic;
      data_memory_readdata : in std_logic_vector(31 downto 0);
      data_memory_waitrequest : in std_logic;

      -- pipeline interface --
      ex_mem : in std_logic_vector(31 downto 0);
      mem_wb : out std_logic_vector(31 downto 0)
    );
  end component;

  component write_back_stage is
    port(
      clock : in std_logic;
      reset : in std_logic;

      -- pipeline interface --
      mem_wb : in std_logic_vector(31 downto 0)
    );
  end component;

  component pipeline_register is
    port (
      clock : in std_logic;
      reset : in std_logic;

      data : in std_logic_vector(31 downto 0);
      data_out : out std_logic_vector(31 downto 0)
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

    if_id_register : pipeline_register
    port map(
      clock,
      global_reset,
      if_id_in,
      if_id_out
    );

    id_ex_1_register : pipeline_register
    port map(
      clock,
      global_reset,
      id_ex_1_in,
      id_ex_1_out
    );

    id_ex_2_register : pipeline_register
    port map(
      clock,
      global_reset,
      id_ex_2_in,
      id_ex_2_out
    );

    ex_mem_register : pipeline_register
    port map(
      clock,
      global_reset,
      ex_mem_in,
      ex_mem_out
    );

    mem_wb_register : pipeline_register
    port map(
      clock,
      global_reset,
      mem_wb_in,
      mem_wb_out
    );

    instruction_fetch_stage : instruction_fetch_stage
    port map(
      clock => clock,
      reset => global_reset,
      read_instruction_address => instr_memory_address,
      read_instruction => instr_memory_memread,
      instruction => instr_memory_readdata,
      wait_request => instr_memory_waitrequest,
      if_id => if_id_in
    );

    instruction_decode_stage : instruction_decode_stage
    port map(
      clock => clock,
      reset => global_reset,
      read_1_address => reg_readreg1,
      read_2_address => reg_readreg2,
      register_1 => reg_readdata1,
      register_2 => reg_readdata2,
      if_id => if_id_out,
      id_ex_reg_1 => id_ex_1_in,
      id_ex_reg_2 => id_ex_2_in
    );

    -- wait on Henry for this --
    execute_stage : execute_stage
    port map(
      clock => clock,
      reset => global_reset
    );

    memory_stage : memory_stage
    port map(
      clock => clock,
      reset => global_reset
      data_memory_writedata => data_memory_writedata,
      data_memory_address => data_memory_address,
      data_memory_memwrite => data_memory_memwrite,
      data_memory_memread => data_memory_memread,
      data_memory_readdata => data_memory_readdata,
      data_memory_waitrequest => data_memory_waitrequest,
      ex_mem => ex_mem_out,
      mem_wb => mem_wb_in
    );

    -- TODO --
    write_back_stage : write_back_stage
    port map(
      clock => clock,
      reset => global_reset,
      mem_wb => mem_wb_out
    );

    -- BEGIN PROCESSES --

    async_operation : process(clock, reset)
    begin
      if reset = '1' then
        instruction_line_in_counter <= '0';
        present_state <= init;
      elsif (clock'event and clock = '1') then
        program_counter <= updated_program_counter;
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

          if (program_counter >= 10,000) then
            program_execution_finished <= '1';
            next_state <= fini;
          else
            -- what should the next state be here?
            next_state <= processor;
          end if;
          null;

        when fini =>
          next_state <= fini;

      end case;
    end process;

    pipeline_functional_logic : process (clock, reset, present_state, program_in)
    begin
      case present_state is
        when init =>
          instr_memory_memwrite = '1';
          if clock'event and clock = '1' then
            instr_memory_address <= instruction_line_in_counter;
            instr_memory_writedata <= program_in;
            instr_memory_address <= instr_memory_address + 1;
          end if;
          global_reset <= '1';
          program_counter <= 0;

        when fini =>
          data_memory_memread <= '1';
          -- register does not require memread

          if (clock'event and clock = '1') then
            data_memory_address <= memory_line_counter;
            reg_readreg1 <= register_line_counter;

            memory_out <= data_memory_readdata;
            register_out <= reg_readdata1;

            memory_line_counter <= memory_line_counter + 1;
            register_line_counter <= register_line_counter + 1;

            if (memory_line_counter >= memory_size and register_line_counter >= register_size) then
              memory_out_finished <= '1';
              register_out_finished <= '1';
            end if;
          end if;

        when others =>
          -- TODO : this.
          null;
      end case;
    end process;

end arch;
