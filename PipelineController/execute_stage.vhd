library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity execute_stage is
	port(
		clock, reset: in std_logic;
		ALU_instruction, ALU_operand1, ALU_operand2: in std_logic_vector(31 downto 0);
		ALU_next_pc : in integer; -- for branching
		ALU_next_pc_valid : in std_logic;
		load_store_address : in integer;
		load_store_address_valid : in std_logic;
		jump_address : out integer;
		jump_taken : out std_logic;

		-- ALU_output is only used for arithmetic actions, corresponding to non - load/store or jump instructions.
		-- If an addresss for jump is being calculated, it goes onto jump_address with an asserted jump_taken.
		-- If an address for load/store is being calculated, it goes onto load_store_address with an asserted load_store_address_valid
		ALU_output: out std_logic_vector(31 downto 0)
	);
end execute_stage;

architecture arch of execute_stage is
----------------------
-- DECLARATION SECTION
----------------------

alias ALU_NPC : conv_std_logic_vector(ALU_next_pc, 32);

-- General op code
signal op_code: std_logic_vector(5 downto 0) := ALU_instruction(31 downto 26);

-- R-type decomposition
signal shamt: std_logic_vector(4 downto 0) := ALU_instruction(10 downto 6);
signal funct: std_logic_vector(5 downto 0) := ALU_instruction(5 downto 0);

-- I-type decomposition
signal immediate: std_logic_vector(15 downto 0) := ALU_instruction(15 downto 0);
signal extended_immediate: std_logic_vector(31 downto 0);

-- J-type decomposition
signal jump_address_offset: std_logic_vector(25 downto 0) := ALU_instruction(25 downto 0);

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
-- Register jump_address_offset -  CAREFUL! jr is not a J type...
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
extended_immediate <= (31 downto 16 => immediate(15))&immediate;

	ALU_process:process(clock, reset)
	begin
		if reset = '1' then
			-- Output initiated to all 0's
			ALU_output <= (others => '0');

		elsif (clock'event and clock = '1') then
			case op_code is
				when R_type_general_op_code =>

					case funct is -- R-type
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
							ALU_output <= ALU_operand1 and ALU_operand2;
						when funct_or =>
							ALU_output <= ALU_operand1 or ALU_operand2;
						when funct_nor =>
							ALU_output <= ALU_operand1 NOR ALU_operand2;
						when funct_xor =>
							ALU_output <= ALU_operand1 xor ALU_operand2;
						when funct_mfhi | funct_mflo =>
							null; -- handled in WB
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
							jump_address <= ALU_operand1;
							jump_taken <= '1';
							-- ALU_output <= ALU_operand1;
						when others =>
							null;
					end case;

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
					ALU_output <= ALU_operand1 and ALU_operand2;
				when I_type_op_ori =>
					ALU_output <= ALU_operand1 or ALU_operand2;
				when I_type_op_xori =>
					ALU_output <= ALU_operand1 xor ALU_operand2;
				when I_type_op_lui =>
					ALU_output(31 downto 16) <= immediate(15 downto 0);
					ALU_output(15 downto 0) <= (others => '0');
				when I_type_op_lw | I_type_op_sw =>
					-- Address formed in similar way as ADDI
					load_store_address <= std_logic_vector(signed(ALU_operand1) + signed(ALU_operand2));
					load_store_address_valid <= '1';
					-- ALU_output <= std_logic_vector(signed(ALU_operand1) + signed(ALU_operand2));
				when I_type_op_beq =>
					if (ALU_operand1 = ALU_operand2) then
						jump_taken <= '1';
						jump_address <= ALU_next_pc + signed(extended_immediate));
						-- ALU_output <= std_logic_vector(ALU_next_pc + signed(extended_immediate)));
					else
						jump_taken <= '0';
					end if;
				when I_type_op_bne =>
					if (ALU_operand1 != ALU_operand2) then
						jump_taken <= '1';
						jump_address <= ALU_next_pc + signed(extended_immediate));
						-- ALU_output <= std_logic_vector(ALU_next_pc + signed(extended_immediate)));
					else
						jump_taken <= '0';
					end if;


				-- TODO : TURN THIS INTO INT AND OUTPOUT TO jump_address and assert jump_address_valid
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
			end case;
		end if;
	end process;

end architecture;
