library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

ENTITY instruction_decode_stage_tb IS
END instrcution_decode_stage_tb;

ARCHITECTURE behaviour of instruction_decode_stage_tb is 

COMPONENT instruction_decode_stage is
  PORT(
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
end component;

-- INITIALISING THE INPUT WITH THE INITIAL VALUES 
-- NOT COMPLETELTY INITIALISED THE VALUES  
SIGNAL clock, reset : STD_LOGIC := '0';


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
  
  --SIGNALS 
  

 
 
 begin
 
 	clock <= '0';
 	reset <='0';
	
 
 -- R TYPE INSTRCUTIONS
 -- ADD R3 R1 R2 
  instruction <= (R_type_general_op_code)&("00001")&("00010")&("00011")&("00000")&(funct_add);
  
-- MULT R4 R5  
   instruction <= (R_type_general_op_code)&("00100")&("00101")&("0000000000")&(funct_mult);
   
-- SLT R8 R6 R7
	instruction <= (R_type_general_op_code)&("00110")&("00111")&("01000")&("00000")&(funct_slt);
	
-- XOR R11 R10 R9
	instruction <= (R_type_general_op_code)&("01010")&("01001")&("01011")&("00000")&(funct_xor);
	
-- MDHI R12
	instruction <= (R_type_general_op_code)&("00000")&("00000")&("01100")&("00000")&(funct_mfhi);
	
-- MFLO R13
	instruction <= (R_type_general_op_code)&("00000")&("00000")&("01101")&("00000")&(funct_mflo);
	
-- jr R14
	instruction <= (R_type_general_op_code)&("01110")&("00000")&("00000")&("00000")&(funct_jr); 
	
-- IMMEDIATE INSTRUCTIONS 
-- ADDI R2 R1 3
	instruction <= (I_type_op_addi)&("00001")&("00010")&("0000000000000011"); 
	
-- ORI R3 R4 3
	instruction <= (I_type_op_ori)&("00100")&("00011")&("0000000000000011"); 
	
-- LUI R5 3
	instruction <= (I_type_op_lui)&("00000")&("00101")&("0000000000000011"); 
	
-- LW R6 R7 
	instruction <= (I_type_op_lw)&("00111")&("00110")&("0000000000000000"); 
	
-- SB R8 Offset(r9)
	instruction <= (I_type_op_sw)&("01001")&("01000")&("0000000000000000");
	
--  BEQ R10 R11 3
	instruction <= (I_type_op_beq)&("01010")&("01011")&("0000000000000011");
	
	end; 
	
	

 
 
 