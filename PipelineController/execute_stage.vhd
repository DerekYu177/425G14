library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity execute_stage is
	port(
		clock, reset: in std_logic;
		ALU_instruction, ALU_operand1, ALU_operand2: in std_logic_vector(31 downto 0);
		ALU_next_pc : in std_logic_vector(31 downto 0); -- for branching
		ALU_next_pc_valid : in std_logic;
		load_store_address_in: in std_logic_vector(31 downto 0);
		load_store_address_out: out std_logic_vector(31 downto 0);
		load_store_address_valid : out std_logic;
		jump_address : out std_logic_vector(31 downto 0);
		jump_taken : out std_logic;

		-- ALU_output is only used for arithmetic actions, corresponding to non - load/store or jump instructions.
		-- If an addresss for jump is being calculated, it goes onto jump_address with an asserted jump_taken.
		-- If an address for load/store is being calculated, it goes onto load_store_address with an asserted load_store_address_valid
		ALU_output: out std_logic_vector(31 downto 0);
		ALU_LO_out: out std_logic_vector(31 downto 0);
		ALU_HI_out: out std_logic_vector(31 downto 0);
		ALU_LO_store_out: out std_logic;
		ALU_HI_store_out: out std_logic
	);
end execute_stage;

architecture arch of execute_stage is
----------------------
-- DECLARATION SECTION
----------------------

signal ALU_NPC: std_logic_vector(31 downto 0);

-- General op code
signal op_code: std_logic_vector(5 downto 0);
-- R-type decomposition
signal shamt: std_logic_vector(4 downto 0);
signal funct: std_logic_vector(5 downto 0);

-- I-type decomposition
signal immediate: std_logic_vector(15 downto 0);
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
signal shamt_int_value: integer;

begin

-- Take whatever register index in and outputs it
-- This corresponds to rd/rt in most cases


-- Decomposition assignment
extended_immediate <= (31 downto 16 => immediate(15)) & immediate;
op_code <= ALU_instruction(31 downto 26);

-- R-type decomposition
shamt <= ALU_instruction(10 downto 6);
funct <= ALU_instruction(5 downto 0);

-- I-type decomposition
immediate <= ALU_instruction(15 downto 0);
-- J-type decomposition
jump_address_offset <= ALU_instruction(25 downto 0);
shamt_int_value <= to_integer(unsigned(shamt));

ALU_NPC <= std_logic_vector(to_unsigned(to_integer(unsigned(ALU_next_pc)) + 4, 32));

	ALU_process:process(clock, reset)
	begin


	load_store_address_out <= load_store_address_in;



		if reset = '1' then
			-- Output initiated to all 0's
			ALU_output <= (others => '0');
			load_store_address_out <= (others => '0');
			load_store_address_valid <= '0';
			jump_address <= (others => '0');
			jump_taken <= '0';
			ALU_LO_out <= (others => '0');
			ALU_HI_out <= (others => '0');
			ALU_LO_store_out <= '0';
			ALU_HI_store_out <= '0';
		else
			case op_code is
				when R_type_general_op_code =>
				report "R type instruction matched";
				jump_taken <= '0';
					case funct is -- R-type
						when funct_add =>
							report"ADD matched";
							ALU_output <= std_logic_vector(signed(ALU_operand1) + signed(ALU_operand2));
							load_store_address_valid <= '1';
							ALU_LO_store_out <= '0';
							ALU_HI_store_out <= '0';
						when funct_sub =>
							ALU_output <= std_logic_vector(signed(ALU_operand1) - signed(ALU_operand2));
							load_store_address_valid <= '1';
							ALU_LO_store_out <= '0';
							ALU_HI_store_out <= '0';
						when funct_mult =>
							report"MULT matched";
							ALU_output <= (others => '0');
							ALU_LO_out <= std_logic_vector(to_signed((to_integer(signed(ALU_operand1)) * to_integer(signed(ALU_operand2))),32));
							load_store_address_valid <= '1';
							ALU_LO_store_out <= '1';
							ALU_HI_store_out <= '0';
						when funct_div =>
							 ALU_output <= (others => '0');
							 ALU_LO_out <= std_logic_vector(to_signed((to_integer(signed(ALU_operand1)) / to_integer(signed(ALU_operand2))),32));
							 ALU_HI_out <= std_logic_vector(to_signed((to_integer(signed(ALU_operand1)) mod to_integer(signed(ALU_operand2))),32));
							 load_store_address_valid <= '1';
							 ALU_LO_store_out <= '1';
							 ALU_HI_store_out <= '1';
						when funct_slt =>
						report"SLT matched";
							if (signed(ALU_operand1) < signed(ALU_operand2)) then
								ALU_output <= (0 => '1', others => '0');
								load_store_address_valid <= '1';
								ALU_LO_store_out <= '0';
								ALU_HI_store_out <= '0';
							else
								ALU_output <= (others => '0');
								load_store_address_valid <= '1';
								ALU_LO_store_out <= '0';
								ALU_HI_store_out <= '0';
							end if;
						when funct_and =>
							ALU_output <= ALU_operand1 and ALU_operand2;
							load_store_address_valid <= '1';
							ALU_LO_store_out <= '0';
							ALU_HI_store_out <= '0';
						when funct_or =>
							report"OR matched";
							ALU_output <= ALU_operand1 or ALU_operand2;
							load_store_address_valid <= '1';
							ALU_LO_store_out <= '0';
							ALU_HI_store_out <= '0';
						when funct_nor =>
							report"NOR matched";
							ALU_output <= ALU_operand1 NOR ALU_operand2;
							load_store_address_valid <= '1';
							ALU_LO_store_out <= '0';
							ALU_HI_store_out <= '0';
						when funct_xor =>
							report"XOR matched";
							ALU_output <= ALU_operand1 xor ALU_operand2;
							load_store_address_valid <= '1';
							ALU_LO_store_out <= '0';
							ALU_HI_store_out <= '0';
						when funct_mfhi =>
							report "MFHI matched";
							ALU_output <= ALU_operand1;
							load_store_address_valid <= '1';
							ALU_LO_store_out <= '0';
							ALU_HI_store_out <= '0';
						when funct_mflo =>
							report"MFLO matched";
							ALU_output <= ALU_operand1;
							load_store_address_valid <= '1';
							ALU_LO_store_out <= '0';
							ALU_HI_store_out <= '0';
						when funct_sll =>
							report "SLL matched";
						-- By convention, we shift operand2 (which should be in turn connected rt)
							ALU_output(31 downto shamt_int_value) <= ALU_operand2(31 - shamt_int_value downto 0);
							ALU_output(shamt_int_value - 1 downto 0) <= (others => '0');
							load_store_address_valid <= '1';
							ALU_LO_store_out <= '0';
							ALU_HI_store_out <= '0';
						when funct_srl =>
							report"SRL matched";
							ALU_output(31 downto (31 - shamt_int_value+1)) <= (others => '0');
							ALU_output(31 - shamt_int_value downto 0) <= ALU_operand2(31 downto shamt_int_value);
							load_store_address_valid <= '1';
							ALU_LO_store_out <= '0';
							ALU_HI_store_out <= '0';
						when funct_sra =>
							report"SRA matched";
							ALU_output(31 downto (31 - shamt_int_value + 1)) <= (others => ALU_operand2(31));
							ALU_output(31 - shamt_int_value downto 0) <= ALU_operand2(31 downto shamt_int_value);
							load_store_address_valid <= '1';
							ALU_LO_store_out <= '0';
							ALU_HI_store_out <= '0';
						when funct_jr =>
							report"JR matched";
						-- Directly jump to address contained in register
						-- Assume address contained comes from operand1
							jump_address <= ALU_operand1;
							jump_taken <= '1';
							-- ALU_output <= ALU_operand1;
							load_store_address_valid <= '1';
							ALU_LO_store_out <= '0';
							ALU_HI_store_out <= '0';
						when others =>
							report"No funct of R-type matched matched";
							ALU_output <= (others => '0');
					end case;

				--We still refer the immediate field as 'Operand 2', since the sign extension should be done by other control during the DECODE stage
				when I_type_op_addi =>
					report "ADDI matched";
					ALU_output <= std_logic_vector(signed(ALU_operand1) + signed(ALU_operand2));
					load_store_address_valid <= '1';
					ALU_LO_store_out <= '0';
					ALU_HI_store_out <= '0';
					jump_taken <= '0';
				when I_type_op_slti =>
					report "SLTI matched";
					load_store_address_valid <= '1';
					ALU_LO_store_out <= '0';
					ALU_HI_store_out <= '0';
					jump_taken <= '0';
					if (signed(ALU_operand1) < signed(ALU_operand2)) then
						ALU_output <= (0=> '1', others => '0');
					else
						ALU_output <= (others => '0');
					end if;
				when I_type_op_andi =>
					ALU_output <= ALU_operand1 and ALU_operand2;
					load_store_address_valid <= '1';
					ALU_LO_store_out <= '0';
					ALU_HI_store_out <= '0';
					jump_taken <= '0';
				when I_type_op_ori =>
					report "ORI matched";
					ALU_output <= ALU_operand1 or ALU_operand2;
					load_store_address_valid <= '1';
					ALU_LO_store_out <= '0';
					ALU_HI_store_out <= '0';
					jump_taken <= '0';
				when I_type_op_xori =>
					ALU_output <= ALU_operand1 xor ALU_operand2;
					load_store_address_valid <= '1';
					ALU_LO_store_out <= '0';
					ALU_HI_store_out <= '0';
					jump_taken <= '0';
				when I_type_op_lui =>
					report "LUI matched";
					ALU_output(31 downto 16) <= immediate(15 downto 0);
					ALU_output(15 downto 0) <= (others => '0');
					load_store_address_valid <= '1';
					ALU_LO_store_out <= '0';
					ALU_HI_store_out <= '0';
					jump_taken <= '0';
				when I_type_op_lw | I_type_op_sw =>
					report "LOAD/STORE matched";
					-- ALU outputs the effective address
					ALU_output <= std_logic_vector(signed(ALU_operand1) + signed(ALU_operand2));
					load_store_address_valid <= '1';
					-- ALU_output <= std_logic_vector(signed(ALU_operand1) + signed(ALU_operand2));
					ALU_LO_store_out <= '0';
					ALU_HI_store_out <= '0';
					jump_taken <= '0';
				when I_type_op_beq =>
					report "BEQ matched";
					load_store_address_valid <= '0';
					ALU_LO_store_out <= '0';
					ALU_HI_store_out <= '0';
					ALU_output <= (others => '0'); -- ALU_output is unused in this case, default to 0
					if (ALU_operand1 = ALU_operand2) then
						jump_taken <= '1';
						jump_address <= std_logic_vector(to_unsigned(to_integer(unsigned(ALU_next_pc)) + to_integer(signed(extended_immediate)), 32));
					else
						jump_taken <= '0';
					end if;
				when I_type_op_bne =>
					report "BNE matched";
					load_store_address_valid <= '0';
					ALU_LO_store_out <= '0';
					ALU_HI_store_out <= '0';
					ALU_output <= (others => '0');
					if not(ALU_operand1 = ALU_operand2) then
						jump_taken <= '1';
						jump_address <= std_logic_vector(to_unsigned(to_integer(unsigned(ALU_next_pc)) + to_integer(signed(extended_immediate)), 32));					else
						jump_taken <= '0';
					end if;


				-- TODO : TURN THIS INTO INT AND OUTPUT TO jump_address and assert jump_address_valid
				when J_type_op_j =>
				report "J instruction matched";
				-- [4 MSB taken from New PC] & [26 bits from jump_address_offset] & ["00"]
					--ALU_output <= (31 downto 28 => ALU_NPC(31 downto 28), 27 downto 2 => jump_address_offset(25 downto 0), others => '0');
					ALU_output(31 downto 28) <= ALU_NPC(31 downto 28);
					ALU_output(27 downto 2) <= jump_address_offset(25 downto 0);
					ALU_output(1 downto 0) <= "00";
					load_store_address_valid <= '0';
					ALU_LO_store_out <= '0';
					ALU_HI_store_out <= '0';
				when J_type_op_jal =>
				-- Address is the same as J_type_op_j, other operations need to be performed, however.
				-- Namely: store the return address in $31
					ALU_output(31 downto 28) <= ALU_NPC(31 downto 28);
					ALU_output(27 downto 2) <= jump_address_offset(25 downto 0);
					ALU_output(1 downto 0) <= "00";
					load_store_address_valid <= '0';
					ALU_LO_store_out <= '0';
					ALU_HI_store_out <= '0';
				when others =>
					report "henry owes me pho";
					load_store_address_valid <= '0';
			end case;
		end if;
	end process;

end architecture;
