library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ALU is
port(
clock, reset: in std_logic;
ALU_operation, ALU_operand1, ALU_operand2: in std_logic_vector(31 downto 0);
ALU_PC: in std_logic_vector(31 downto 0);
ALU_output: out std_logic_vector(31 downto 0)
-- Maybe additional control signals that tells the ALU operands are valid?
);
end ALU;

architecture arch of ALU is
----------------------
-- DECLARATION SECTION
----------------------

-- General op code
SIGNAL op_code: std_logic_vector(5 downto 0) := ALU_operation(31 downto 26);

-- R-type decomposition
SIGNAL shamt: std_logic_vector(4 downto 0) := ALU_operation(10 downto 6);
SIGNAL funct: std_logic_vector(5 downto 0) := ALU_operation(5 downto 0);

-- I-type decomposition
SIGNAL immediate: std_logic_vector(15 downto 0) := ALU_operation(15 downto 0);

-- J-type decomposition
SIGNAL jump_adress_offset: std_logic_vector(25 downto 0) := ALU_operation(25 downto 0);

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
-- Bitwise
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


-- OPCODE constants for I-type instructions
----------------------------------------------
-- Imm arithmetic
CONSTANT I_type_op_addi: std_logic_vector(5 downto 0) := "001000";
CONSTANT I_type_op_slti: std_logic_vector(5 downto 0) := "001010";
-- Imm bitwise
CONSTANT I_type_op_andi: std_logic_vector(5 downto 0) := "001100";
CONSTANT I_type_op_ori: std_logic_vector(5 downto 0)  := "001101";
CONSTANT I_type_op_xori: std_logic_vector(5 downto 0) := "001110";
-- load imm / lw & sw
CONSTANT I_type_op_lui: std_logic_vector(5 downto 0):= "001000";
CONSTANT I_type_op_lw: std_logic_vector(5 downto 0) := "100011";
CONSTANT I_type_op_sw: std_logic_vector(5 downto 0) := "101011";
-- Control
CONSTANT I_type_op_beq: std_logic_vector(5 downto 0) := "000100";
CONSTANT I_type_op_bne: std_logic_vector(5 downto 0) := "000101";

-- OPCODE constants for J-type instructions
----------------------------------------------
CONSTANT J_type_op_j: std_logic_vector(5 downto 0) := "000010";
CONSTANT J_type_op_jr: std_logic_vector(5 downto 0) := "000000"; -- THIS CONFLICTS WITH R-TYPE GENERAL OPCODE -> to be fixed with extra conditions
CONSTANT J_type_op_jal: std_logic_vector(5 downto 0) := "000011";


BEGIN
	ALU_process:process(clock, reset)
	begin
		if reset = '1' then
			-- Output initiated to all 0's
			ALU_output <= (others => '0');

		elsif (Clock'EVENT AND Clock = '1') then
			CASE op_code is
				--All R-type operations
				when R_type_general_op_code =>
					CASE funct is
						when funct_add =>
							ALU_output <= std_logic_vector((signed(ALU_operand1) + signed(ALU_operand2));
						when funct_sub =>
							ALU_output <= std_logic_vector((signed(ALU_operand1) - signed(ALU_operand2));
						when funct_mult =>
							ALU_output <= std_logic_vector((signed(ALU_operand1) * signed(ALU_operand2));
						when funct_div =>
							ALU_output <= std_logic_vector((signed(ALU_operand1) / signed(ALU_operand2));
						when funct_slt =>
							if (signed(ALU_operand1) < signed(ALU_operand2)) then
								ALU_output <= (0=> '1', others => '0');
							else
								ALU_output <= (others => '0');
							end if;
						when funct_and =>
							ALU_output <= ALU_operand1 AND ALU_operand2;
						when funct_or =>
							ALU_output <= ALU_operand1 OR ALU_operand2;
						when funct_nor =>
							ALU_output <= ALU_operand1 NOR ALU_operand2;
						when funct_xor =>
							ALU_output <= ALU_operand1 XOR ALU_operand2;
						when funct_mfhi =>
						when funct_mflo =>
						when funct_sll =>
						-- Do we shift operand2 or operand1? Not sure...
							ALU_output <= ALU_operand2 sll to_integer(unsigned(shamt));
						when funct_srl =>
							ALU_output <= ALU_operand2 srl to_integer(unsigned(shamt));
						when funct_sra =>
							ALU_output <= ALU_operand2 sra to_integer(unsigned(shamt));
					end CASE;
				--All I-type operations
				--We still refer the immediate field as 'Operand 2', since the sign extension should be done by other control during the DECODE stage
				when I_type_op_addi =>
					ALU_output <= std_logic_vector(signed(ALU_operand1) + signed(ALU_operand2)); 
				when I_type_op_slti =>
					if (signed(ALU_operand1) < signed(ALU_operand2)) then
						ALU_output <= (0=> '1', others => '0');
					else
						ALU_output <= (others => '0');
					end if;
				when I_type_op_andi =>
					ALU_output <= ALU_operand1 AND ALU_operand2;
				when I_type_op_ori =>
					ALU_output <= ALU_operand1 OR ALU_operand2;
				when I_type_op_xori =>
					ALU_output <= ALU_operand1 XOR ALU_operand2;
				when I_type_op_lui =>
					ALU_output <= immediate sll 16;
				when I_type_op_lw =>
					-- Address formed is the same as ADDI
					-- The first operand is converted as unsigned because it represents an address...not sure though, to be comfirmed
					ALU_output <= std_logic_vector(unsigned(ALU_operand1) + signed(ALU_operand2)); 
				when I_type_op_sw =>
					ALU_output <= std_logic_vector(unsigned(ALU_operand1) + signed(ALU_operand2));
				when I_type_op_beq =>
					if (unsigned(ALU_operand1) = unsigned(ALU_operand2))then
						-- New value of PC (assuming it comes from operand 1) + Imm << 2
						ALU_output <= unsigned(ALU_operand1) + 
				when I_type_op_bne =>
				--All J-type operations
				when J_type_op_j =>
				--TODO: when J_type_op_jr =>
				when J_type_op_jal =>
			end CASE;
		end if;
	end process;

end architecture;