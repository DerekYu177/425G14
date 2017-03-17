library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

ENTITY instruction_decode_stage_tb IS
END instruction_decode_stage_tb;

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
signal read_1_address :  integer range 0 to 31;
signal read_2_address : integer range 0 to 31;
signal register_1 : std_logic_vector(31 downto 0);
signal register_2 :  std_logic_vector(31 downto 0);

    -- main pipeline interface --
signal instruction : std_logic_vector(31 downto 0);
signal id_ex_reg_1 : std_logic_vector(31 downto 0);
signal id_ex_reg_2 : std_logic_vector(31 downto 0);

    -- pipeline data store address --
signal  load_store_address : integer; -- still unused!
signal  load_store_address_valid :std_logic; -- still unused!
signal  load_memory_valid : std_logic;
signal  store_memory_valid : std_logic;
signal  store_register : std_logic ;


-- FUNCT constants for R-type instructions
	-------------------------------------------------
constant R_type_general_op_code: std_logic_vector(5 downto 0) := "000000";
constant clk_period : time := 1ns ; 

	-- Reg arithmetic
  constant funct_add: std_logic_vector(5 downto 0) := "100000";
  
  constant funct_mult: std_logic_vector(5 downto 0):= "011000";
  
  constant funct_slt: std_logic_vector(5 downto 0) := "101010";
	-- Logical
  constant funct_xor: std_logic_vector(5 downto 0) := "100110";
	-- Transfer
  constant funct_mfhi: std_logic_vector(5 downto 0):= "010000";
  constant funct_mflo: std_logic_vector(5 downto 0):= "010010";
	-- Register jump_address_offset
	-- CAREFUL! jr is not a J type...
  constant funct_jr: std_logic_vector(5 downto 0)  := "001000";

	-- OPCODE constants for I-type instructions
	----------------------------------------------
	-- Imm arithmetic
  constant I_type_op_addi: std_logic_vector(5 downto 0) := "001000";
	-- Imm Logical
  constant I_type_op_ori: std_logic_vector(5 downto 0)  := "001101";
	-- load imm / lw & sw
  constant I_type_op_lui: std_logic_vector(5 downto 0):= "001111";
  constant I_type_op_lw: std_logic_vector(5 downto 0) := "100011";
  constant I_type_op_sw: std_logic_vector(5 downto 0) := "101011";
	-- Control
  constant I_type_op_beq: std_logic_vector(5 downto 0) := "000100";

BEGIN
dut : instruction_decode_stage
 PORT MAP (clock ,
    reset,
    -- interface with the register memory --
    read_1_address ,
    read_2_address ,
    register_1 ,
    register_2 ,
    -- main pipeline interface --
    instruction ,
    id_ex_reg_1 ,
    id_ex_reg_2 ,
    -- pipeline data store address --
    load_store_address ,
    load_store_address_valid ,
    load_memory_valid ,
    store_memory_valid ,
    store_register );

clk :process
BEGIN
	clock <= '0';
	WAIT FOR clk_period/2;
 	clock <='1';
	WAIT FOR clk_period/2;
END PROCESS;

tb:PROCESS
BEGIN
 -- R TYPE INSTRCUTIONS
 -- ADD R3 R1 R2 
	instruction <= (R_type_general_op_code)&("00100")&("00101")&("0000000000")&(funct_add);
  
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
	
-- SW R8 Offset(r9)
	instruction <= (I_type_op_sw)&("01001")&("01000")&("0000000000000000");
	
--  BEQ R10 R11 3
	instruction <= (I_type_op_beq)&("01010")&("01011")&("0000000000000011");
	
END PROCESS;
END; 