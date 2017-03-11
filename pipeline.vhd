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

  -- INSTRUCTION RELATED SIGNALS AND COMPONENTS --
  -- (Copied from ALU)
  
  -- General op code
	SIGNAL op_code: std_logic_vector(5 downto 0) := if_id(31 downto 26);

	-- R-type decomposition
	SIGNAL rtype_rs: integer := to_integer(unsigned (if_id(25 downto 21)));
	SIGNAL rtype_rt: integer := to_integer(unsigned (if_id(20 downto 16)));
	SIGNAL rtype_rd: integer := to_integer(unsigned (if_id(15 downto 11)));
	
	SIGNAL shamt: std_logic_vector(4 downto 0) := if_id(10 downto 6);
	SIGNAL funct: std_logic_vector(5 downto 0) := if_id(5 downto 0);

	-- I-type decomposition
	SIGNAL itype_rs: integer := to_integer(unsigned (if_id(25 downto 21)));
	SIGNAL itype_rt: integer := to_integer(unsigned (if_id(20 downto 16)));
	
	SIGNAL immediate: std_logic_vector(15 downto 0) := if_id(15 downto 0);
	SIGNAL extended_immediate: std_logic_vector(31 downto 0);
	SIGNAL extended_immediate_shifted: std_logic_vector(31 downto 0);
	-- J-type decomposition
	SIGNAL jump_address_offset: std_logic_vector(25 downto 0) := if_id(25 downto 0);

	-- Comments: notice that the register fields are omitted on purpose, since it's the controller's job to feed in the correct operand as input; the ALU just performs the operation

	-- FUNCT constants for R-type instructions
	-------------------------------------------------
	CONSTANT R_type_general_op_code: std_logic_vector(5 downto 0) := "000000";

	-- Reg arithmetic
	CONSTANT funct_add: std_logic_vector(5 downto 0) := "100000";
	CONSTANT funct_sub: std_logic_vector(5 downto 0) := "100010";
	CONSTANT funct_mult: std_logic_vector(5 downto 0):= "011000";
	CONSTANT funct_div: std_logic_vector(5 downto 0) := "011010";
	CONSTANT funct_slt: std_logic_vector(5 downto 0) := "101010";
	-- Logical
	CONSTANT funct_and: std_logic_vector(5 downto 0) := "100100";
	CONSTANT funct_or: std_logic_vector(5 downto 0)  := "100101";
	CONSTANT funct_nor: std_logic_vector(5 downto 0) := "100111";
	CONSTANT funct_xor: std_logic_vector(5 downto 0) := "100110";
	-- Transfer
	CONSTANT funct_mfhi: std_logic_vector(5 downto 0):= "010000";
	CONSTANT funct_mflo: std_logic_vector(5 downto 0):= "010010";
	-- Shift
	CONSTANT funct_sll: std_logic_vector(5 downto 0) := "000000";
	CONSTANT funct_srl: std_logic_vector(5 downto 0) := "000010";
	CONSTANT funct_sra: std_logic_vector(5 downto 0) := "000011";
	-- Register jump_address_offset
	-- CAREFUL! jr is not a J type...
	CONSTANT funct_jr: std_logic_vector(5 downto 0)  := "001000";


	-- OPCODE constants for I-type instructions
	----------------------------------------------
	-- Imm arithmetic
	CONSTANT I_type_op_addi: std_logic_vector(5 downto 0) := "001000";
	CONSTANT I_type_op_slti: std_logic_vector(5 downto 0) := "001010";
	-- Imm Logical
	CONSTANT I_type_op_andi: std_logic_vector(5 downto 0) := "001100";
	CONSTANT I_type_op_ori: std_logic_vector(5 downto 0)  := "001101";
	CONSTANT I_type_op_xori: std_logic_vector(5 downto 0) := "001110";
	-- load imm / lw & sw
	CONSTANT I_type_op_lui: std_logic_vector(5 downto 0):= "001111";
	CONSTANT I_type_op_lw: std_logic_vector(5 downto 0) := "100011";
	CONSTANT I_type_op_sw: std_logic_vector(5 downto 0) := "101011";
	-- Control
	CONSTANT I_type_op_beq: std_logic_vector(5 downto 0) := "000100";
	CONSTANT I_type_op_bne: std_logic_vector(5 downto 0) := "000101";

	-- OPCODE constants for J-type instructions
	----------------------------------------------
	CONSTANT J_type_op_j: std_logic_vector(5 downto 0) := "000010";
	CONSTANT J_type_op_jal: std_logic_vector(5 downto 0) := "000011";

	-- OTHERS
	CONSTANT shamt_int_value: integer := to_integer(unsigned(shamt));

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
	-- SIGNAL --
	-- For sw/lw
	extended_immediate <= (31 downto 16 => immediate(15)) & immediate;
	-- For bne/beq
	extended_immediate_shifted <= (31 downto 18 => immediate(15)) & immediate & "00";
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
			 -- NEW CODE 10/03/2017--
			 
			 
			 
			 CASE op_code is
				when R_type_general_op_code =>
				--All R-type operations
				-----------------------
					CASE funct is
						when funct_add =>
							reg_readreg1 <= rtype_rs;
							reg_readreg2 <= rtype_rt;
						when funct_sub =>
							reg_readreg1 <= rtype_rs;
							reg_readreg2 <= rtype_rt;
						when funct_mult =>
							reg_readreg1 <= rtype_rs;
							reg_readreg2 <= rtype_rt;
						when funct_div =>
							reg_readreg1 <= rtype_rs;
							reg_readreg2 <= rtype_rt;
						when funct_slt =>
							reg_readreg1 <= rtype_rs;
							reg_readreg2 <= rtype_rt;
						when funct_and =>
							reg_readreg1 <= rtype_rs;
							reg_readreg2 <= rtype_rt;
						when funct_or =>
							reg_readreg1 <= rtype_rs;
							reg_readreg2 <= rtype_rt;
						when funct_nor =>
							reg_readreg1 <= rtype_rs;
							reg_readreg2 <= rtype_rt;
						when funct_xor =>
							reg_readreg1 <= rtype_rs;
							reg_readreg2 <= rtype_rt;
						-- Is there anything to do for mfhi and mflo? They just move content of HI/LO to $rd...
						-- In my opinion this should be dealt in the WB stage
						when funct_mfhi =>
							null;
						when funct_mflo =>
							null;
						when funct_sll =>
							reg_readreg1 <= rtype_rt;
						when funct_srl =>
							reg_readreg1 <= rtype_rt;
						when funct_sra =>
							reg_readreg1 <= rtype_rt;
						when funct_jr =>
							reg_readreg1 <= rtype_rs;
						when others =>
							null;
					end CASE;
				
				--All I-type operations
				-----------------------
				--We still refer the immediate field as 'Operand 2', since the sign extension should be done by other control during the DECODE stage
				when I_type_op_addi =>
					reg_readreg1 <= itype_rs;
					ALU_operand2 <= "0000000000000000"&immediate;
				when I_type_op_slti =>
					reg_readreg1 <= itype_rs;
					ALU_operand2 <= extended_immediate;
				when I_type_op_andi =>
					reg_readreg1 <= itype_rs;
					ALU_operand2 <= "0000000000000000"&immediate;
				when I_type_op_ori =>
					reg_readreg1 <= itype_rs;
					ALU_operand2 <= "0000000000000000"&immediate;
				when I_type_op_xori =>
					reg_readreg1 <= itype_rs;
					ALU_operand2 <= "0000000000000000"&immediate;
				when I_type_op_lui =>
					-- Handled within ALU, no need to do anything here
					null;
				when I_type_op_lw =>
					reg_readreg1 <= itype_rs;
					ALU_operand2 <= extended_immediate;
				when I_type_op_sw =>
					reg_readreg1 <= itype_rs;
					ALU_operand2 <= extended_immediate;
				when I_type_op_beq =>
					reg_readreg1 <= itype_rs;
					reg_readreg2 <= itype_rt;
				when I_type_op_bne =>
					reg_readreg1 <= itype_rs;
					reg_readreg2 <= itype_rt;
					
				--All J-type operations
				-----------------------
				-- Both handled within ALU
				-- Question though...should they be handled within ALU? Or can we resolve them here?
				when J_type_op_j =>
					null;
				when J_type_op_jal =>
					null;
				when others =>
					ALU_output <= (others => '0');
			end CASE;
			 
			 
			 
			 
			 
			 
			 
			 
			 
			 
			 
			 
			 

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
