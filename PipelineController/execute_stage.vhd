library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity execute_stage is
port(
	clock, reset: in std_logic;
	ALU_instruction, ALU_operand1, ALU_operand2: in std_logic_vector(31 downto 0);
	ALU_next_pc : in integer; -- for branching
	ALU_output: out std_logic_vector(31 downto 0));
end execute_stage;

architecture arch of execute_stage is
----------------------
-- DECLARATION SECTION
----------------------

alias ALU_NPC : conv_std_logic_vector(ALU_next_pc, 32);

-- General op code
SIGNAL op_code: std_logic_vector(5 downto 0) := ALU_instruction(31 downto 26);

-- R-type decomposition
SIGNAL shamt: std_logic_vector(4 downto 0) := ALU_instruction(10 downto 6);
SIGNAL funct: std_logic_vector(5 downto 0) := ALU_instruction(5 downto 0);

-- I-type decomposition
SIGNAL immediate: std_logic_vector(15 downto 0) := ALU_instruction(15 downto 0);

SIGNAL extended_immediate: std_logic_vector(31 downto 0);
-- J-type decomposition
SIGNAL jump_address_offset: std_logic_vector(25 downto 0) := ALU_instruction(25 downto 0);

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

BEGIN
extended_immediate <= (31 downto 16 => immediate(15))&immediate;

	ALU_process:process(clock, reset)
	begin
		if reset = '1' then
			-- Output initiated to all 0's
			ALU_output <= (others => '0');

		elsif (Clock'EVENT AND Clock = '1') then
			CASE op_code is
				when R_type_general_op_code =>
				--All R-type operations
				-----------------------
					CASE funct is
						when funct_add =>
							ALU_output <= std_logic_vector(signed(ALU_operand1) + signed(ALU_operand2));
						when funct_sub =>
							ALU_output <= std_logic_vector(signed(ALU_operand1) - signed(ALU_operand2));
						when funct_mult =>
							ALU_output <= std_logic_vector(to_signed((to_integer(signed(ALU_operand1)) * to_integer(signed(ALU_operand2))),32));
						when funct_div =>
							ALU_output <= std_logic_vector(to_signed((to_integer(signed(ALU_operand1)) / to_integer(signed(ALU_operand2))),32));
						when funct_slt =>
							if (signed(ALU_operand1) < signed(ALU_operand2)) then
								ALU_output <= (0 => '1', others => '0');
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
							null;
						when funct_mflo =>
							null;
						when funct_sll =>
						-- Do we shift operand2 or operand1? Not sure...
							ALU_output(31 downto shamt_int_value) <= ALU_operand2(31-shamt_int_value downto 0);
							ALU_output(shamt_int_value-1 downto 0) <= (others => '0');
						when funct_srl =>
							ALU_output(31 downto (31-shamt_int_value+1)) <= (others => '0');
							ALU_output(31-shamt_int_value downto 0) <= ALU_operand2(31 downto shamt_int_value);
						when funct_sra =>
							ALU_output(31 downto (31-shamt_int_value+1)) <= (others => ALU_operand2(31));
							ALU_output(31-shamt_int_value downto 0) <= ALU_operand2(31 downto shamt_int_value);
						when funct_jr =>
						-- Directly jump to address contained in register
						-- Assume address contained comes from operand1
							ALU_output <= ALU_operand1;
						when others =>
							null;
					end CASE;

				--All I-type operations
				-----------------------
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
					ALU_output(31 downto 16) <= immediate(15 downto 0);
					ALU_output(15 downto 0) <= (others => '0');
				when I_type_op_lw =>
					-- Address formed in similar way as ADDI

					ALU_output <= std_logic_vector(signed(ALU_operand1) + signed(ALU_operand2));
				when I_type_op_sw =>
					-- Address formed in similar way as ADDI
					ALU_output <= std_logic_vector(signed(ALU_operand1) + signed(ALU_operand2));
				when I_type_op_beq =>
					-- We assume equality met, it is the job of control to choose PC + 4 (via a mux) in case equality is NOT met
					-- [New value of PC] (from operand 1) + [extended Imm << 2] (from operand 2)
					ALU_output <= ALU_next_pc + signed(extended_immediate));
				when I_type_op_bne =>
					-- Same logic, assume equality is met
					ALU_output <= ALU_next_pc + signed(extended_immediate));

				--All J-type operations
				-----------------------
				when J_type_op_j =>
				-- [4 MSB taken from New PC] & [26 bits from jump_address_offset] & ["00"]
					--ALU_output <= (31 downto 28 => ALU_NPC(31 downto 28), 27 downto 2 => jump_address_offset(25 downto 0), others => '0');
					ALU_output(31 downto 28) <= ALU_NPC(31 downto 28);
					ALU_output(27 downto 2) <= jump_address_offset(25 downto 0);
					ALU_output(1 downto 0) <= "00";
				when J_type_op_jal =>
				-- Address is the same as J_type_op_j, other operations need to be performed, however.
				-- Namely: store the return address in $31
					ALU_output(31 downto 28) <= ALU_NPC(31 downto 28);
					ALU_output(27 downto 2) <= jump_address_offset(25 downto 0);
					ALU_output(1 downto 0) <= "00";
				when others =>
					null;
			end CASE;
		end if;
	end process;

end architecture;
