library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

ENTITY instruction_fetch_stage_tb IS
END instruction_fetch_stage_tb;

ARCHITECTURE behaviour of instruction_fetch_stage_tb is

COMPONENT instruction_fetch_stage is
  PORT(
  clock : in std_logic;
  reset : in std_logic;

  -- instruction memory interface --
  read_instruction_address : out integer;
  read_instruction : out std_logic;
  instruction_in : in std_logic_vector(31 downto 0);
  wait_request : in std_logic;

  -- pipeline interface --
  jump_program_counter : in integer;
  jump_taken : in std_logic;
  instruction_out : out std_logic_vector(31 downto 0);
  updated_program_counter : out integer;
  program_counter_valid : out std_logic
  );

end COMPONENT;

--SIGNALS 

-- ASSIGN PROGRAM COUNTER TO 0
 signal program_counter : integer; -- this will keep track of the PC
 signal clock :  std_logic ;
 signal reset : std_logic ;
 signal read_instruction_address : integer;
 signal read_instruction : std_logic;
 signal instruction_in : std_logic_vector(31 downto 0);
 signal wait_request : std_logic;
 signal jump_program_counter : integer;
 signal jump_taken : std_logic;
 signal instruction_out : std_logic_vector(31 downto 0);
 signal updated_program_counter : integer;
 signal program_counter_valid : std_logic;
 constant clk_period : time := 1ns ; 
 constant funct_add: std_logic_vector(5 downto 0) := "100000";
 constant funct_mult: std_logic_vector(5 downto 0):= "011000";
 constant funct_xor: std_logic_vector(5 downto 0) := "100110";
 constant I_type_op_addi: std_logic_vector(5 downto 0) := "001000";
 constant J_type_op_j: std_logic_vector(5 downto 0) := "000010";
constant R_type_general_op_code: std_logic_vector(5 downto 0) := "000000";
 
 -- Instruction in will be equal to instruction out we will assert this
 --
BEGIN 
dut : instruction_fetch_stage
PORT MAP(clock , reset ,read_instruction_address,read_instruction,instruction_in,wait_request,jump_program_counter,jump_taken,instruction_out,updated_program_counter,program_counter_valid);
clk_process : PROCESS
BEGIN
	clock <= '0';
	WAIT FOR clk_period/2;
	clock <= '1';
	WAIT FOR clk_period/2;
END PROCESS;
tb : PROCESS
 begin
 
 	--if(clock'event and clock = '1') then 
 		if(( read_instruction = '1') and (program_counter = jump_program_counter)) then 
 		
 		 -- ADD R3 R1 R2 
  		instruction_in <= (R_type_general_op_code)&("00001")&("00010")&("00011")&("00000")&(funct_add);
 		ASSERT (instruction_out = instruction_in);
 		ASSERT ( updated_program_counter = program_counter);
 		program_counter <= program_counter+4;
 		
 		-- MULT R4 R5  
   		instruction_in <= (R_type_general_op_code)&("00100")&("00101")&("0000000000")&(funct_mult);
   		ASSERT (instruction_out = instruction_in); 
   		ASSERT (updated_program_counter = program_counter);
   		program_counter <= program_counter+4;
   		
   		-- XOR R11 R10 R9
		instruction_in <= (R_type_general_op_code)&("01010")&("01001")&("01011")&("00000")&(funct_xor);
		ASSERT(instruction_out = instruction_in); 
		ASSERT(updated_program_counter = program_counter); 
		program_counter <= program_counter+4; 
		
		-- ADDI R2 R1 3
		instruction_in <= (I_type_op_addi)&("00001")&("00010")&("0000000000000011"); 
		ASSERT(instruction_out = instruction_in); 
		ASSERT(updated_program_counter = program_counter); 
		program_counter <= program_counter+4; 
		
		--j 1000
		-- when the jump is valid
		instruction_in <= (J_type_op_j)&("00000000000000001111101000");
		ASSERT(instruction_out = instruction_in);
		ASSERT(read_instruction_address = jump_program_counter);
		program_counter <= jump_program_counter; 
		jump_taken <= '1';

		-- j 10000
		-- In this case the jump is invalid 
		instruction_in <= (J_type_op_j)&("00000000000010011100010000");
		ASSERT( instruction_out = instruction_in); 
		ASSERT(updated_program_counter = program_counter); 
		program_counter <= program_counter+4; 
		jump_taken <= '0';
		
		
		end if; 
	--end if; 
	END PROCESS;
	END;