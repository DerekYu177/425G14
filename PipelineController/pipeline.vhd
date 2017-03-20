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
    clear, init, instruction_load, instruction_load_increment, processor, fini, register_save, register_save_increment, memory_save, memory_save_increment, terminate
  );

  signal present_state, next_state : state_type;

  -- INTERNAL CONTROL SIGNALS --
  signal jump_taken : std_logic := '0';
  signal global_reset : std_logic := '0';
  signal initializing : std_logic := '1';

  -- read/write control signal
  signal instruction_line_in_counter : integer := 0;
  signal memory_line_counter : integer := 0;
  signal register_line_counter : integer := 0;

  -- pipeline constants --
  constant data_size : integer := 8192;
  constant instruction_size : integer := 1024;
  constant register_size : integer := 32;


  -- pipeline main register IO --
  signal if_id_data_1_in : std_logic_vector(31 downto 0) := (others => '0');
  signal if_id_data_2_in : std_logic_vector(31 downto 0) := (others => '0');
  signal if_id_scratch_in : std_logic_vector(31 downto 0) := (others => '0');
  signal if_id_hi_data_in : std_logic_vector(31 downto 0) := (others => '0');
  signal if_id_lo_data_in : std_logic_vector(31 downto 0) := (others => '0');
  signal if_id_pc_value_in : std_logic_vector(31 downto 0) := (others => '0');
  signal if_id_address_value_in : std_logic_vector(31 downto 0) := (others => '0');
  signal if_id_pc_valid_in : std_logic := '0';
  signal if_id_address_valid_in : std_logic := '0';
  signal if_id_load_memory_valid_in : std_logic := '0';
  signal if_id_store_memory_valid_in : std_logic := '0';
  signal if_id_store_register_in : std_logic := '0';
  signal if_id_hi_store_in : std_logic := '0';
  signal if_id_lo_store_in : std_logic := '0';

  signal if_id_data_1_out : std_logic_vector(31 downto 0) := (others => '0');
  signal if_id_data_2_out : std_logic_vector(31 downto 0) := (others => '0');
  signal if_id_scratch_out : std_logic_vector(31 downto 0) := (others => '0');
  signal if_id_hi_data_out : std_logic_vector(31 downto 0) := (others => '0');
  signal if_id_lo_data_out : std_logic_vector(31 downto 0) := (others => '0');
  signal if_id_pc_value_out : std_logic_vector(31 downto 0) := (others => '0');
  signal if_id_address_value_out : std_logic_vector(31 downto 0) := (others => '0');
  signal if_id_pc_valid_out : std_logic := '0';
  signal if_id_address_valid_out : std_logic := '0';
  signal if_id_load_memory_valid_out : std_logic := '0';
  signal if_id_store_memory_valid_out : std_logic := '0';
  signal if_id_store_register_out : std_logic := '0';
  signal if_id_hi_store_out : std_logic := '0';
  signal if_id_lo_store_out : std_logic := '0';

  signal id_ex_data_1_in : std_logic_vector(31 downto 0) := (others => '0');
  signal id_ex_data_2_in : std_logic_vector(31 downto 0) := (others => '0');
  signal id_ex_scratch_in : std_logic_vector(31 downto 0) := (others => '0');
  signal id_ex_hi_data_in : std_logic_vector(31 downto 0) := (others => '0');
  signal id_ex_lo_data_in : std_logic_vector(31 downto 0) := (others => '0');
  signal id_ex_pc_value_in : std_logic_vector(31 downto 0) := (others => '0');
  signal id_ex_address_value_in : std_logic_vector(31 downto 0) := (others => '0');
  signal id_ex_pc_valid_in : std_logic := '0';
  signal id_ex_address_valid_in : std_logic := '0';
  signal id_ex_load_memory_valid_in : std_logic := '0';
  signal id_ex_store_memory_valid_in : std_logic := '0';
  signal id_ex_store_register_in : std_logic := '0';
  signal id_ex_hi_store_in : std_logic := '0';
  signal id_ex_lo_store_in : std_logic := '0';

  signal id_ex_data_1_out : std_logic_vector(31 downto 0) := (others => '0');
  signal id_ex_data_2_out : std_logic_vector(31 downto 0) := (others => '0');
  signal id_ex_scratch_out : std_logic_vector(31 downto 0) := (others => '0');
  signal id_ex_hi_data_out : std_logic_vector(31 downto 0) := (others => '0');
  signal id_ex_lo_data_out : std_logic_vector(31 downto 0) := (others => '0');
  signal id_ex_pc_value_out : std_logic_vector(31 downto 0) := (others => '0');
  signal id_ex_address_value_out : std_logic_vector(31 downto 0) := (others => '0');
  signal id_ex_pc_valid_out : std_logic := '0';
  signal id_ex_address_valid_out : std_logic := '0';
  signal id_ex_load_memory_valid_out : std_logic := '0';
  signal id_ex_store_memory_valid_out : std_logic := '0';
  signal id_ex_store_register_out : std_logic := '0';
  signal id_ex_hi_store_out : std_logic := '0';
  signal id_ex_lo_store_out : std_logic := '0';

  signal ex_mem_data_1_in : std_logic_vector(31 downto 0) := (others => '0');
  signal ex_mem_data_2_in : std_logic_vector(31 downto 0) := (others => '0');
  signal ex_mem_scratch_in : std_logic_vector(31 downto 0) := (others => '0');
  signal ex_mem_hi_data_in : std_logic_vector(31 downto 0) := (others => '0');
  signal ex_mem_lo_data_in : std_logic_vector(31 downto 0) := (others => '0');
  signal ex_mem_pc_value_in : std_logic_vector(31 downto 0) := (others => '0');
  signal ex_mem_address_value_in : std_logic_vector(31 downto 0) := (others => '0');
  signal ex_mem_pc_valid_in : std_logic := '0';
  signal ex_mem_address_valid_in : std_logic := '0';
  signal ex_mem_load_memory_valid_in : std_logic := '0';
  signal ex_mem_store_memory_valid_in : std_logic := '0';
  signal ex_mem_store_register_in : std_logic := '0';
  signal ex_mem_hi_store_in : std_logic := '0';
  signal ex_mem_lo_store_in : std_logic := '0';

  signal ex_mem_data_1_out : std_logic_vector(31 downto 0) := (others => '0');
  signal ex_mem_data_2_out : std_logic_vector(31 downto 0) := (others => '0');
  signal ex_mem_scratch_out : std_logic_vector(31 downto 0) := (others => '0');
  signal ex_mem_hi_data_out : std_logic_vector(31 downto 0) := (others => '0');
  signal ex_mem_lo_data_out : std_logic_vector(31 downto 0) := (others => '0');
  signal ex_mem_pc_value_out : std_logic_vector(31 downto 0) := (others => '0');
  signal ex_mem_address_value_out : std_logic_vector(31 downto 0) := (others => '0');
  signal ex_mem_pc_valid_out : std_logic := '0';
  signal ex_mem_address_valid_out : std_logic := '0';
  signal ex_mem_load_memory_valid_out : std_logic := '0';
  signal ex_mem_store_memory_valid_out : std_logic := '0';
  signal ex_mem_store_register_out : std_logic := '0';
  signal ex_mem_hi_store_out : std_logic := '0';
  signal ex_mem_lo_store_out : std_logic := '0';

  signal mem_wb_data_1_in : std_logic_vector(31 downto 0) := (others => '0');
  signal mem_wb_data_2_in : std_logic_vector(31 downto 0) := (others => '0');
  signal mem_wb_scratch_in : std_logic_vector(31 downto 0) := (others => '0');
  signal mem_wb_hi_data_in : std_logic_vector(31 downto 0) := (others => '0');
  signal mem_wb_lo_data_in : std_logic_vector(31 downto 0) := (others => '0');
  signal mem_wb_pc_value_in : std_logic_vector(31 downto 0) := (others => '0');
  signal mem_wb_address_value_in : std_logic_vector(31 downto 0) := (others => '0');
  signal mem_wb_pc_valid_in : std_logic := '0';
  signal mem_wb_address_valid_in : std_logic := '0';
  signal mem_wb_load_memory_valid_in : std_logic := '0';
  signal mem_wb_store_memory_valid_in : std_logic := '0';
  signal mem_wb_store_register_in : std_logic := '0';
  signal mem_wb_hi_store_in : std_logic := '0';
  signal mem_wb_lo_store_in : std_logic := '0';

  signal mem_wb_data_1_out : std_logic_vector(31 downto 0) := (others => '0');
  signal mem_wb_data_2_out : std_logic_vector(31 downto 0) := (others => '0');
  signal mem_wb_scratch_out : std_logic_vector(31 downto 0) := (others => '0');
  signal mem_wb_hi_data_out : std_logic_vector(31 downto 0) := (others => '0');
  signal mem_wb_lo_data_out : std_logic_vector(31 downto 0) := (others => '0');
  signal mem_wb_pc_value_out : std_logic_vector(31 downto 0) := (others => '0');
  signal mem_wb_address_value_out : std_logic_vector(31 downto 0) := (others => '0');
  signal mem_wb_pc_valid_out : std_logic := '0';
  signal mem_wb_address_valid_out : std_logic := '0';
  signal mem_wb_load_memory_valid_out : std_logic := '0';
  signal mem_wb_store_memory_valid_out : std_logic := '0';
  signal mem_wb_store_register_out : std_logic := '0';
  signal mem_wb_hi_store_out : std_logic := '0';
  signal mem_wb_lo_store_out : std_logic := '0';

  -- COMPONENT INTERNAL SIGNALS --
  signal instr_memory_writedata : std_logic_vector(31 downto 0) := (others => '0');
  signal instr_memory_write_address : std_logic_vector(31 downto 0) := (others => '0');
  signal instr_memory_read_address : std_logic_vector(31 downto 0) := (others => '0');
  signal instr_memory_memwrite : std_logic := '0';
  signal instr_memory_memread : std_logic := '0';
  signal instr_memory_readdata : std_logic_vector(31 downto 0) := (others => '0');
  signal instr_memory_waitrequest : std_logic := '0';

  signal data_memory_writedata : std_logic_vector(31 downto 0) := (others => '0');
  signal data_memory_address : std_logic_vector(31 downto 0) := (others => '0');
  signal data_memory_address_fini : std_logic_vector(31 downto 0) := (others => '0');
  signal data_memory_memwrite : std_logic := '0';
  signal data_memory_memread : std_logic := '0';
  signal data_memory_readdata : std_logic_vector(31 downto 0) := (others => '0');
  signal data_memory_readdata_fini : std_logic_vector(31 downto 0) := (others => '0');
  signal data_memory_waitrequest : std_logic := '0';

  signal reg_writedata : std_logic_vector(31 downto 0);
  signal reg_readreg1 : std_logic_vector(31 downto 0);
  signal reg_readreg2 : std_logic_vector(31 downto 0);
  signal reg_readreg_fini : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_writereg : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_data_in_hi : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_data_in_lo : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_write_hi : std_logic := '0';
  signal reg_write_lo : std_logic := '0';
  signal reg_regwrite : std_logic := '0';
  signal reg_readdata1 : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_readdata2 : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_readdata_fini : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_data_out_hi : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_data_out_lo : std_logic_vector(31 downto 0) := (others => '0');

  component instruction_memory
    generic(
  		ram_size : integer := 1024;
  		mem_delay : time := 10 ns;
  		clock_period : time := 1 ns
  	);
  	port(
  		clock : in std_logic;
      reset : in std_logic;
  		writedata : in std_logic_vector(31 downto 0);

  		write_address : in std_logic_vector(31 downto 0);
      read_address : in std_logic_vector(31 downto 0);
  		memwrite : in std_logic;
  		memread : in std_logic;
  		readdata : out std_logic_vector(31 downto 0);
  		waitrequest : out std_logic
  	);
  end component;

  component data_memory
    generic(
      ram_size : integer := 8192;
      mem_delay : time := 10 ns;
      clock_period : time := 1 ns
    );
  	port(
  		clock : in std_logic;
      reset : in std_logic;
  		writedata : in std_logic_vector(31 downto 0);

  		address : in std_logic_vector(31 downto 0);
      address_read_fini : in std_logic_vector(31 downto 0);
  		memwrite : in std_logic;
  		memread : in std_logic;
  		readdata : out std_logic_vector(31 downto 0);
      readdata_fini : out std_logic_vector(31 downto 0);
  		waitrequest : out std_logic
  	);
  end component;

  component registers
    port(
      clock : in std_logic;
      reset : in std_logic;
  		writedata : in std_logic_vector(31 downto 0);
  		readreg1 : in std_logic_vector(31 downto 0);
  		readreg2 : in std_logic_vector(31 downto 0);
  		readreg_fini : in std_logic_vector(31 downto 0);
  		writereg : in std_logic_vector(31 downto 0);
  		data_in_hi : in std_logic_vector(31 downto 0);
  		data_in_lo : in std_logic_vector(31 downto 0);
  		write_hi : in std_logic;
  		write_lo : in std_logic;

  		regwrite : in std_logic;
  		readdata1 : out std_logic_vector(31 downto 0);
  		readdata2 : out std_logic_vector(31 downto 0);
  		readdata_fini : out std_logic_vector(31 downto 0);
  		data_out_hi : out std_logic_vector(31 downto 0);
  		data_out_lo : out std_logic_vector(31 downto 0)
    );
  end component;

  -- DECLARING PIPELINE COMPONENTS --

  component instruction_fetch_stage is
    port(
      clock : in std_logic;
      reset : in std_logic;
      initializing : in std_logic;

      -- instruction memory interface --
      read_instruction_address : out std_logic_vector(31 downto 0);
      read_instruction : out std_logic;
      instruction_in : in std_logic_vector(31 downto 0);
      wait_request : in std_logic;

      -- pipeline interface --
      jump_program_counter : in std_logic_vector(31 downto 0);
      jump_taken : in std_logic;
      instruction_out : out std_logic_vector(31 downto 0);
      updated_program_counter : out std_logic_vector(31 downto 0);
      program_counter_valid : out std_logic
    );
  end component;

  component instruction_decode_stage is
    port(
      clock : in std_logic;
      reset : in std_logic;

      -- register interface --
      read_1_address : out std_logic_vector(31 downto 0);
      read_2_address : out std_logic_vector(31 downto 0);
      register_1 : in std_logic_vector(31 downto 0);
      register_2 : in std_logic_vector(31 downto 0);
      register_hi : in std_logic_vector(31 downto 0);
      register_lo : in std_logic_vector(31 downto 0);

      -- pipeline interface --
      instruction : in std_logic_vector(31 downto 0);
      id_ex_reg_1 : out std_logic_vector(31 downto 0);
      id_ex_reg_2 : out std_logic_vector(31 downto 0);
      load_store_address : out std_logic_vector(31 downto 0);
      load_store_address_valid : out std_logic;
      load_memory_valid : out std_logic;
      store_memory_valid : out std_logic;
      store_register : out std_logic
    );
  end component;

  component execute_stage is
    port(
      clock : in std_logic;
      reset: in std_logic;

      -- pipeline interface --
  		ALU_instruction : in std_logic_vector(31 downto 0);
      ALU_operand1 : in std_logic_vector(31 downto 0);
      ALU_operand2 : in std_logic_vector(31 downto 0);
  		ALU_next_pc : in std_logic_vector(31 downto 0); -- for branching
      ALU_next_pc_valid : in std_logic;
      load_store_address_in: in std_logic_vector(31 downto 0);
  		load_store_address_out: out std_logic_vector(31 downto 0);
  		load_store_address_valid : out std_logic;
  		jump_address : out std_logic_vector(31 downto 0);
  		jump_taken : out std_logic;

  		ALU_output: out std_logic_vector(31 downto 0);
  		ALU_LO_out: out std_logic_vector(31 downto 0);
  		ALU_HI_out: out std_logic_vector(31 downto 0);
  		ALU_LO_store_out: out std_logic;
  		ALU_HI_store_out: out std_logic
    );
  end component;

  component memory_stage is
    port(
      clock : in std_logic;
      reset : in std_logic;

      -- data memory interface --
      data_memory_writedata : out std_logic_vector(31 downto 0);
      data_memory_address : out std_logic_vector(31 downto 0);
      data_memory_memwrite : out std_logic;
      data_memory_memread : out std_logic;
      data_memory_readdata : in std_logic_vector(31 downto 0);
      data_memory_waitrequest : in std_logic;

      -- pipeline interface --
      data_in : in std_logic_vector(31 downto 0);
      data_in_address : in std_logic_vector(31 downto 0);
      data_in_address_valid : in std_logic;
      data_out : out std_logic_vector(31 downto 0);
      data_out_address : out std_logic_vector(31 downto 0);
      data_out_address_valid : out std_logic;
      load_memory_valid : in std_logic;
      store_memory_valid : in std_logic
    );
  end component;

  component write_back_stage is
    port(
      clock : in std_logic;
      reset : in std_logic;

      -- interface with register --
      reg_writedata : out std_logic_vector(31 downto 0);
      reg_writereg_address : out std_logic_vector(31 downto 0);
      reg_regwrite : out std_logic;
      write_hi_data : out std_logic_vector(31 downto 0);
      write_lo_data : out std_logic_vector(31 downto 0);
      write_hi : out std_logic;
      write_lo : out std_logic;

      -- pipeline interface --
      write_data : in std_logic_vector(31 downto 0);
      write_address : in std_logic_vector(31 downto 0);
      write_address_valid : in std_logic;
      store_register : in std_logic;

      -- pipeline interface for HI/LO --
      hi_data : in std_logic_vector(31 downto 0);
      lo_data : in std_logic_vector(31 downto 0);
      hi_store : in std_logic;
      lo_store : in std_logic
    );
  end component;

  component pipeline_register_bus is
    port (
    clock : in std_logic;
    reset : in std_logic;

    stage_1_data_1 : in std_logic_vector(31 downto 0);
    stage_1_data_2 : in std_logic_vector(31 downto 0);
    stage_1_scratch : in std_logic_vector(31 downto 0);
    stage_1_hi_data : in std_logic_vector(31 downto 0);
    stage_1_lo_data : in std_logic_vector(31 downto 0);
    stage_1_pc_value : in std_logic_vector(31 downto 0);
    stage_1_address_value : in std_logic_vector(31 downto 0);
    stage_1_pc_valid : in std_logic;
    stage_1_address_valid : in std_logic;
    stage_1_load_memory_valid : in std_logic;
    stage_1_store_memory_valid : in std_logic;
    stage_1_store_register : in std_logic;
    stage_1_hi_store : in std_logic;
    stage_1_lo_store : in std_logic;

    stage_2_data_1 : out std_logic_vector(31 downto 0);
    stage_2_data_2 : out std_logic_vector(31 downto 0);
    stage_2_scratch : out std_logic_vector(31 downto 0);
    stage_2_hi_data : out std_logic_vector(31 downto 0);
    stage_2_lo_data : out std_logic_vector(31 downto 0);
    stage_2_pc_value : out std_logic_vector(31 downto 0);
    stage_2_address_value : out std_logic_vector(31 downto 0);
    stage_2_pc_valid : out std_logic;
    stage_2_address_valid : out std_logic;
    stage_2_load_memory_valid : out std_logic;
    stage_2_store_memory_valid : out std_logic;
    stage_2_store_register : out std_logic;
    stage_2_hi_store : out std_logic;
    stage_2_lo_store : out std_logic
    );
  end component;

  begin

    -- COMPONENTS --

    instruction_memory_module :  instruction_memory
    port map(
      clock,
      global_reset,
      instr_memory_writedata,
      instr_memory_write_address,
      instr_memory_read_address,
      instr_memory_memwrite,
      instr_memory_memread,
      instr_memory_readdata,
      instr_memory_waitrequest
    );

    data_memory_module : data_memory
    port map(
      clock,
      global_reset,
      data_memory_writedata,
      data_memory_address,
      data_memory_address_fini,
      data_memory_memwrite,
      data_memory_memread,
      data_memory_readdata,
      data_memory_readdata_fini,
      data_memory_waitrequest
    );

    registers_module : registers
    port map(
      clock,
      global_reset,
      reg_writedata,
      reg_readreg1,
      reg_readreg2,
      reg_readreg_fini,
      reg_writereg,
      reg_data_in_hi,
      reg_data_in_lo,
      reg_write_hi,
      reg_write_lo,
      reg_regwrite,
      reg_readdata1,
      reg_readdata2,
      reg_readdata_fini,
      reg_data_out_hi,
      reg_data_out_lo
    );

    if_id_pipeline_bus : pipeline_register_bus
    port map(
      clock,
      global_reset,

      if_id_data_1_in,
      if_id_data_2_in,
      if_id_scratch_in,
      if_id_hi_data_in,
      if_id_lo_data_in,
      if_id_pc_value_in,
      if_id_address_value_in,
      if_id_pc_valid_in,
      if_id_address_valid_in,
      if_id_load_memory_valid_in,
      if_id_store_memory_valid_in,
      if_id_store_register_in,
      if_id_hi_store_in,
      if_id_lo_store_in,

      if_id_data_1_out,
      if_id_data_2_out,
      if_id_scratch_out,
      if_id_hi_data_out,
      if_id_lo_data_out,
      if_id_pc_value_out,
      if_id_address_value_out,
      if_id_pc_valid_out,
      if_id_address_valid_out,
      if_id_load_memory_valid_out,
      if_id_store_memory_valid_out,
      if_id_store_register_out,
      if_id_hi_store_out,
      if_id_lo_store_out
    );

    id_ex_pipeline_bus : pipeline_register_bus
    port map(
      clock,
      global_reset,

      id_ex_data_1_in,
      id_ex_data_2_in,
      id_ex_scratch_in,
      id_ex_hi_data_in,
      id_ex_lo_data_in,
      id_ex_pc_value_in,
      id_ex_address_value_in,
      id_ex_pc_valid_in,
      id_ex_address_valid_in,
      id_ex_load_memory_valid_in,
      id_ex_store_memory_valid_in,
      id_ex_store_register_in,
      id_ex_hi_store_in,
      id_ex_lo_store_in,

      id_ex_data_1_out,
      id_ex_data_2_out,
      id_ex_scratch_out,
      id_ex_hi_data_out,
      id_ex_lo_data_out,
      id_ex_pc_value_out,
      id_ex_address_value_out,
      id_ex_pc_valid_out,
      id_ex_address_valid_out,
      id_ex_load_memory_valid_out,
      id_ex_store_memory_valid_out,
      id_ex_store_register_out,
      id_ex_hi_store_out,
      id_ex_lo_store_out
    );

    ex_mem_pipeline_bus : pipeline_register_bus
    port map(
      clock,
      global_reset,

      ex_mem_data_1_in,
      ex_mem_data_2_in,
      ex_mem_scratch_in,
      ex_mem_hi_data_in,
      ex_mem_lo_data_in,
      ex_mem_pc_value_in,
      ex_mem_address_value_in,
      ex_mem_pc_valid_in,
      ex_mem_address_valid_in,
      ex_mem_load_memory_valid_in,
      ex_mem_store_memory_valid_in,
      ex_mem_store_register_in,
      ex_mem_hi_store_in,
      ex_mem_lo_store_in,

      ex_mem_data_1_out,
      ex_mem_data_2_out,
      ex_mem_scratch_out,
      ex_mem_hi_data_out,
      ex_mem_lo_data_out,
      ex_mem_pc_value_out,
      ex_mem_address_value_out,
      ex_mem_pc_valid_out,
      ex_mem_address_valid_out,
      ex_mem_load_memory_valid_out,
      ex_mem_store_memory_valid_out,
      ex_mem_store_register_out,
      ex_mem_hi_store_out,
      ex_mem_lo_store_out
    );

    mem_wb_pipeline_bus : pipeline_register_bus
    port map(
      clock,
      global_reset,

      mem_wb_data_1_in,
      mem_wb_data_2_in,
      mem_wb_scratch_in,
      mem_wb_hi_data_in,
      mem_wb_lo_data_in,
      mem_wb_pc_value_in,
      mem_wb_address_value_in,
      mem_wb_pc_valid_in,
      mem_wb_address_valid_in,
      mem_wb_load_memory_valid_in,
      mem_wb_store_memory_valid_in,
      mem_wb_store_register_in,
      mem_wb_hi_store_in,
      mem_wb_lo_store_in,

      mem_wb_data_1_out,
      mem_wb_data_2_out,
      mem_wb_scratch_out,
      mem_wb_hi_data_out,
      mem_wb_lo_data_out,
      mem_wb_pc_value_out,
      mem_wb_address_value_out,
      mem_wb_pc_valid_out,
      mem_wb_address_valid_out,
      mem_wb_load_memory_valid_out,
      mem_wb_store_memory_valid_out,
      mem_wb_store_register_out,
      mem_wb_hi_store_out,
      mem_wb_lo_store_out
    );

    instruction_fetch_module : instruction_fetch_stage
    port map(
      clock => clock,
      reset => global_reset,
      initializing => initializing,
      read_instruction_address => instr_memory_read_address,
      read_instruction => instr_memory_memread,
      instruction_in => instr_memory_readdata,
      wait_request => instr_memory_waitrequest,

      jump_program_counter => ex_mem_pc_value_in,
      jump_taken => ex_mem_pc_valid_in,
      instruction_out => if_id_scratch_in,
      updated_program_counter => if_id_pc_value_in,
      program_counter_valid => if_id_pc_valid_in
    );

    instruction_decode_module : instruction_decode_stage
    port map(
      clock => clock,
      reset => global_reset,
      read_1_address => reg_readreg1,
      read_2_address => reg_readreg2,
      register_1 => reg_readdata1,
      register_2 => reg_readdata2,
      register_hi => reg_data_out_hi,
      register_lo => reg_data_out_lo,

      instruction => if_id_scratch_out,
      id_ex_reg_1 => id_ex_data_1_in,
      id_ex_reg_2 => id_ex_data_2_in,
      load_store_address => id_ex_address_value_in,
      load_store_address_valid => id_ex_address_valid_in,
      load_memory_valid => id_ex_load_memory_valid_in,
      store_memory_valid => id_ex_store_memory_valid_in,
      store_register => id_ex_store_register_in
    );

    execute_module : execute_stage
    port map(
      clock => clock,
      reset => global_reset,
      ALU_instruction => id_ex_scratch_out,
      ALU_operand1 => id_ex_data_1_out,
      ALU_operand2 => id_ex_data_2_out,
      ALU_next_pc => id_ex_pc_value_out,
      ALU_next_pc_valid => id_ex_pc_valid_out,
      load_store_address_in => id_ex_address_value_out,
      load_store_address_out => ex_mem_address_value_in,
      load_store_address_valid => ex_mem_address_valid_in,
      jump_address => ex_mem_pc_value_in,
      jump_taken => ex_mem_pc_valid_in,
      ALU_output => ex_mem_data_1_in,
      ALU_LO_out => ex_mem_lo_data_in,
      ALU_HI_out => ex_mem_hi_data_in,
  		ALU_LO_store_out => ex_mem_lo_store_in,
  		ALU_HI_store_out => ex_mem_hi_store_in
    );

    memory_module : memory_stage
    port map(
      clock => clock,
      reset => global_reset,
      data_memory_writedata => data_memory_writedata,
      data_memory_address => data_memory_address,
      data_memory_memwrite => data_memory_memwrite,
      data_memory_memread => data_memory_memread,
      data_memory_readdata => data_memory_readdata,
      data_memory_waitrequest => data_memory_waitrequest,

      data_in => ex_mem_data_1_out,
      data_in_address => ex_mem_address_value_out,
      data_in_address_valid => ex_mem_address_valid_out,
      data_out => mem_wb_data_1_in,
      data_out_address => mem_wb_address_value_in,
      data_out_address_valid => mem_wb_address_valid_in,
      load_memory_valid => ex_mem_load_memory_valid_out,
      store_memory_valid => ex_mem_store_memory_valid_out
    );

    write_back_module : write_back_stage
    port map(
      clock => clock,
      reset => global_reset,
      reg_writedata => reg_writedata,
      reg_writereg_address => reg_writereg,
      reg_regwrite => reg_regwrite,
      write_hi_data => reg_data_in_hi,
      write_lo_data => reg_data_in_lo,
      write_hi => reg_write_hi,
      write_lo => reg_write_lo,

      write_data => mem_wb_data_1_out,
      write_address => mem_wb_address_value_out,
      write_address_valid => mem_wb_address_valid_out,
      store_register => mem_wb_store_register_out,

      hi_data => mem_wb_hi_data_out,
      lo_data => mem_wb_lo_data_out,
      hi_store => mem_wb_hi_store_out,
      lo_store => mem_wb_lo_store_out
    );

    -- BEGIN PROCESSES --

    pipeline_state_logic : process (clock, reset, present_state, program_in_finished)
    begin
      case present_state is
        when clear =>
          next_state <= init;

        when init =>
          next_state <= instruction_load;

        when instruction_load =>
          if program_in_finished = '1' then
            next_state <= processor;
          else
            next_state <= instruction_load_increment;
          end if;

        when instruction_load_increment =>
          next_state <= instruction_load;

        when processor =>
          -- this is where forwarding and hazard detection will take place --

          if (to_integer(unsigned(if_id_pc_value_in)) >= 120) then
            next_state <= fini;
          else
            -- what should the next state be here?
            next_state <= processor;
          end if;
          null;

        when fini =>
          next_state <= memory_save;

        when memory_save =>
          if memory_line_counter = data_size-8 then
            memory_out_finished <= '1';
            next_state <= register_save;
          else
            next_state <= memory_save_increment;
          end if;

        when memory_save_increment =>
          next_state <= memory_save;

        when register_save =>
          if register_line_counter = register_size then
            register_out_finished <= '1';
            next_state <= terminate;
          else
            next_state <= register_save_increment;
          end if;

        when register_save_increment =>
          next_state <= register_save;

        when terminate =>
          null;

      end case;

      if clock'event and clock = '1' then
        present_state <= next_state;
      end if;

    end process;

    pipeline_functional_logic : process (clock, reset, present_state, program_in)
    begin
      case present_state is
        when clear =>
          instruction_line_in_counter <= 0;
          global_reset <= '1';
          program_execution_finished <= '0';

        when init =>
          global_reset <= '0';
          initializing <= '1';

        when instruction_load =>
          instr_memory_memwrite <= '1';
          instr_memory_write_address <= std_logic_vector(to_unsigned(instruction_line_in_counter,32));
          instr_memory_writedata <= program_in;

        when instruction_load_increment =>
          instr_memory_memwrite <= '0';
          instruction_line_in_counter <= instruction_line_in_counter + 4;

        when processor =>
          instr_memory_memwrite <= '0';
          initializing <= '0';
          -- forward from one PRB to another. NOT FORWARDING in ECSE425 sense --
          id_ex_scratch_in <= if_id_scratch_out;
          id_ex_pc_value_in <= if_id_pc_value_out;
          id_ex_pc_valid_in <= if_id_pc_valid_out;
          ex_mem_scratch_in <= id_ex_scratch_out;
          ex_mem_load_memory_valid_in <= id_ex_load_memory_valid_out;
          ex_mem_store_memory_valid_in <= id_ex_store_memory_valid_out;
          ex_mem_store_register_in <= id_ex_store_register_out;
          mem_wb_scratch_in <= ex_mem_scratch_out;
          mem_wb_store_register_in <= ex_mem_store_register_out;
          mem_wb_hi_data_in <= ex_mem_hi_data_out;
          mem_wb_lo_data_in <= ex_mem_lo_data_out;
          mem_wb_hi_store_in <= ex_mem_hi_store_out;
          mem_wb_lo_store_in <= ex_mem_lo_store_out;

        when fini =>
          program_execution_finished <= '1';
          initializing <= '1';

        when memory_save =>
          data_memory_address_fini <= std_logic_vector(to_unsigned(memory_line_counter, 32));
          memory_out <= data_memory_readdata_fini;

        when memory_save_increment =>
          memory_line_counter <= memory_line_counter + 4;

        when register_save =>
          reg_readreg_fini <= std_logic_vector(to_unsigned(register_line_counter, 32));
          register_out <= reg_readreg_fini;

        when register_save_increment =>
          register_line_counter <= register_line_counter + 1;

        when terminate =>
          null;

      end case;
    end process;

end arch;
