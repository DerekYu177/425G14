library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity instruction_decode is
  port(
    clock : in std_logic;
    reset : in std_logic;

    -- interface with the register memory --
    reg_readreg1 : out std_logic_vector(31 downto 0);
    reg_readreg2 : out std_logic_vector(31 downto 0);

    -- inputs --
    if_id : in std_logic_vector(31 downto 0);

    -- outputs --
    id_ex : out std_logic_vector(31 downto 0)
  );
end instruction_decode;

architecture arch of instruction_decode is
  -- INSTRUCTION RELATED SIGNALS AND COMPONENTS --
  -- (Copied from ALU)

  -- General op code
  signal op_code: std_logic_vector(5 downto 0) := if_id(31 downto 26);

	-- R-type decomposition
  signal rtype_rs: integer := to_integer(unsigned (if_id(25 downto 21)));
  signal rtype_rt: integer := to_integer(unsigned (if_id(20 downto 16)));
  signal rtype_rd: integer := to_integer(unsigned (if_id(15 downto 11)));

  signal shamt: std_logic_vector(4 downto 0) := if_id(10 downto 6);
  signal funct: std_logic_vector(5 downto 0) := if_id(5 downto 0);

	-- I-type decomposition
  signal itype_rs: integer := to_integer(unsigned (if_id(25 downto 21)));
  signal itype_rt: integer := to_integer(unsigned (if_id(20 downto 16)));

  signal immediate: std_logic_vector(15 downto 0) := if_id(15 downto 0);
  signal extended_immediate: std_logic_vector(31 downto 0);
  signal extended_immediate_shifted: std_logic_vector(31 downto 0);
	-- J-type decomposition
  signal jump_address_offset: std_logic_vector(25 downto 0) := if_id(25 downto 0);

	-- Comments: notice that the register fields are omitted on purpose, since it's the controller's job to feed in the correct operand as input; the ALU just performs the operation

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

  -- SIGNAL --
  -- For sw/lw
  extended_immediate <= (31 downto 16 => immediate(15)) & immediate;
  -- For bne/beq
  extended_immediate_shifted <= (31 downto 18 => immediate(15)) & immediate & "00";


      -- TODO: add load/store logic here so we know how to approach the register file

      -- TODO: translate the register location to an integer range
   -- NEW CODE 10/03/2017--

   case op_code is
    when R_type_general_op_code =>
    --All R-type operations
    -----------------------
      case funct is
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
      end case;

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
  end case;


end arch;
