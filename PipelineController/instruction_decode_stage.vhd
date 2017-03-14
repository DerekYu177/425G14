library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity instruction_decode_stage is
  port(
    clock : in std_logic;
    reset : in std_logic;

    -- interface with the register memory --
    read_1_address : out integer range 0 to 31;
    read_2_address : out integer range 0 to 31;
    register_1 : in std_logic_vector(31 downto 0);
    register_2 : in std_logic_vector(31 downto 0);

    -- main pipeline interface --
    instruction : in std_logic_vector(31 downto 0);
    id_ex_reg_1 : out std_logic_vector(31 downto 0);
    id_ex_reg_2 : out std_logic_vector(31 downto 0);

    -- pipeline data store address --
    load_store_address : out integer; -- still unused!
    load_store_address_valid : out std_logic; -- still unused!
    load_memory_valid : out std_logic;
    store_memory_valid : out std_logic;
    store_register : out std_logic
  );
end instruction_decode_stage;

architecture arch of instruction_decode_stage is

  -- internal control signals --
  signal reg_1_set : std_logic := '0';
  signal reg_2_set : std_logic := '0';

  -- General op code
  signal op_code: std_logic_vector(5 downto 0) := instruction(31 downto 26);

	-- R-type decomposition
  signal rtype_rs: integer := to_integer(unsigned(instruction(25 downto 21)));
  signal rtype_rt: integer := to_integer(unsigned(instruction(20 downto 16)));
  signal rtype_rd: integer := to_integer(unsigned(instruction(15 downto 11)));
  signal shamt: std_logic_vector(4 downto 0) := instruction(10 downto 6);
  signal funct: std_logic_vector(5 downto 0) := instruction(5 downto 0);

	-- I-type decomposition
  signal itype_rs: integer := to_integer(unsigned(instruction(25 downto 21)));
  signal itype_rt: integer := to_integer(unsigned(instruction(20 downto 16)));
  signal immediate: std_logic_vector(15 downto 0) := instruction(15 downto 0);
  signal blank_immediate_header : std_logic_vector(15 downto 0) := (others => '0');
  signal extended_immediate: std_logic_vector(31 downto 0);
  signal extended_immediate_shifted: std_logic_vector(31 downto 0);

  -- J-type decomposition
  signal jump_address_offset: std_logic_vector(25 downto 0) := instruction(25 downto 0);

	-- FUNCT constants for R-type instructions
	-------------------------------------------------
  constant R_type_general_op_code: std_logic_vector(5 downto 0) := "000000";

	-- Reg arithmetic
  constant funct_add: std_logic_vector(5 downto 0) := "100000";
  constant funct_sub: std_logic_vector(5 downto 0) := "100010";
  constant funct_mult: std_logic_vector(5 downto 0):= "011000";
  constant funct_div: std_logic_vector(5 downto 0) := "011010";
  constant funct_slt: std_logic_vector(5 downto 0) := "101010";
	-- Logical
  constant funct_and: std_logic_vector(5 downto 0) := "100100";
  constant funct_or: std_logic_vector(5 downto 0)  := "100101";
  constant funct_nor: std_logic_vector(5 downto 0) := "100111";
  constant funct_xor: std_logic_vector(5 downto 0) := "100110";
	-- Transfer
  constant funct_mfhi: std_logic_vector(5 downto 0):= "010000";
  constant funct_mflo: std_logic_vector(5 downto 0):= "010010";
	-- Shift
  constant funct_sll: std_logic_vector(5 downto 0) := "000000";
  constant funct_srl: std_logic_vector(5 downto 0) := "000010";
  constant funct_sra: std_logic_vector(5 downto 0) := "000011";
	-- Register jump_address_offset
	-- CAREFUL! jr is not a J type...
  constant funct_jr: std_logic_vector(5 downto 0)  := "001000";

	-- OPCODE constants for I-type instructions
	----------------------------------------------
	-- Imm arithmetic
  constant I_type_op_addi: std_logic_vector(5 downto 0) := "001000";
  constant I_type_op_slti: std_logic_vector(5 downto 0) := "001010";
	-- Imm Logical
  constant I_type_op_andi: std_logic_vector(5 downto 0) := "001100";
  constant I_type_op_ori: std_logic_vector(5 downto 0)  := "001101";
  constant I_type_op_xori: std_logic_vector(5 downto 0) := "001110";
	-- load imm / lw & sw
  constant I_type_op_lui: std_logic_vector(5 downto 0):= "001111";
  constant I_type_op_lw: std_logic_vector(5 downto 0) := "100011";
  constant I_type_op_sw: std_logic_vector(5 downto 0) := "101011";
	-- Control
  constant I_type_op_beq: std_logic_vector(5 downto 0) := "000100";
  constant I_type_op_bne: std_logic_vector(5 downto 0) := "000101";

	-- OPCODE constants for J-type instructions
	----------------------------------------------
  constant J_type_op_j: std_logic_vector(5 downto 0) := "000010";
  constant J_type_op_jal: std_logic_vector(5 downto 0) := "000011";

	-- OTHERS
  constant shamt_int_value: integer := to_integer(unsigned(shamt));

  begin

  -- For sw/lw
  extended_immediate <= (31 downto 16 => immediate(15)) & immediate;

  -- For bne/beq
  extended_immediate_shifted <= (31 downto 18 => immediate(15)) & immediate & "00";

  -- TODO: add load/store logic here so we know how to approach the register file

  async_reset : process(clock, reset)
  begin
    if reset = '1' then
      valid <= '0';
    end if;
  end process;

  case op_code is
    when R_type_general_op_code =>

      --All R-type operations
      case funct is
        when funct_add | funct_sub | funct_mult | funct_div | funct_slt | funct_and | funct_or | funct_nor | funct_xor =>
          read_1_address <= to_integer(unsigned(rtype_rs));
          read_2_address <= to_integer(unsigned(rtype_rt));
          store_register <= '1';
          load_memory_valid <= '0';
          store_memory_valid <= '0';
          load_store_address_valid <= '0';

        when funct_mfhi | funct_mflo=>
          null; -- performed in WB

        when funct_sll | funct_srl | funct_sra =>
          read_1_address <= to_integer(unsigned(rtype_rt));
          store_register <= '1';
          load_memory_valid <= '0';
          store_memory_valid <= '0';
          load_store_address_valid <= '0';

        when funct_jr =>
          read_1_address <= to_integer(unsigned(rtype_rs));
          store_register <= '1';
          load_memory_valid <= '0';
          store_memory_valid <= '0';
          load_store_address_valid <= '0';

        when others =>
          null;

      end case;

    --All I-type operations
    when I_type_op_addi | I_type_op_andi | I_type_op_ori | I_type_op_xori =>
      read_1_address <= to_integer(unsigned(itype_rs));
      reg_2_set <= '1';
      id_ex_reg_2 <= blank_immediate_header & immediate;
      store_register <= '1';
      load_memory_valid <= '0';
      store_memory_valid <= '0';
      load_store_address_valid <= '0';

    when I_type_op_slti =>
      read_1_address <= to_integer(unsigned(itype_rs));
      reg_2_set <= '1';
      id_ex_reg_2 <= extended_immediate;
      store_register <= '1';
      load_memory_valid <= '0';
      store_memory_valid <= '0';
      load_store_address_valid <= '0';

    when I_type_op_lui =>
      null; -- Handled within ALU, no need to do anything here

    when I_type_op_lw =>
      read_1_address <= to_integer(unsigned(itype_rs));
      reg_2_set <= '1';
      id_ex_reg_2 <= extended_immediate;
      store_register <= '0';
      load_memory_valid <= '1';
      store_memory_valid <= '0';
      load_store_address_valid <= '1'; -- but where is the address of the register??

    when I_type_op_sw =>
      read_1_address <= to_integer(unsigned(itype_rs));
      reg_2_set <= '1';
      id_ex_reg_2 <= extended_immediate;
      store_register <= '0';
      load_memory_valid <= '0';
      store_memory_valid <= '1';
      load_store_address_valid <= '1'; -- but where is the address of the register?? 

    when I_type_op_beq | I_type_op_bne =>
      read_1_address <= to_integer(unsigned(itype_rs));
      reg_2_set <= '1';
      id_ex_reg_2 <= to_integer(unsigned(itype_rt));
      store_register <= '0';
      load_memory_valid <= '0';
      store_memory_valid <= '0';
      load_store_address_valid <= '0';

    --All J-type operations
    -- handled within ALU? Or can we resolve them here?
    when J_type_op_j | J_type_op_jal =>
      null;

    when others =>
      null;
  end case;

  if reg_1_set = '0' then
    id_ex_reg_1 <= register_1;
  end if;

  if reg_2_set = '0' then
    id_ex_reg_2 <= register_2;
  end if;

end arch;
