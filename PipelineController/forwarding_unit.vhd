library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity forwarding_unit is
  port(
  clock : in std_logic;
  reset : in std_logic;
  
  -- Instruction signal of current instruction
  current_instruction_ID_EX: in std_logic_vector(31 downto 0); -- Instruction that is about to be started in EX(comes from ID_EX register output side)
  current_rs_data: in std_logic_vector(31 downto 0);
  current_rt_data: in std_logic_vector(31 downto 0);
  
  -- Instruction signal from previous instructions, and hence later in stage
  previous_instruction_EX_MEM: in std_logic_vector(31 downto 0); -- Instruction that is about to be finished in EX (comes from EX_MEM register input side)
  previous2_instruction_MEM_WB: in std_logic_vector(31 downto 0); -- Instruction that is about to be finished in EX (comes from EX_MEM register input side)
  
  -- Same as above, but for data
  previous_data_EX_MEM: in std_logic_vector(31 downto 0);
  previous2_data_MEM_WB: in std_logic_vector(31 downto 0);
  
  -- Chosen outputs
  fwd_result_rs: out std_logic_vector(31 downto 0);
  fwd_result_rt: out std_logic_vector(31 downto 0);
  
  -- Special lines for HI and LO
  
  fwd_HI_EX_MEM: in std_logic_vector(31 downto 0);
  fwd_LO_EX_MEM: in std_logic_vector(31 downto 0);
  
  fwd_HI_MEM_WB: in std_logic_vector(31 downto 0);
  fwd_LO_MEM_WB: in std_logic_vector(31 downto 0)
  );
end forwarding_unit;


architecture arch of forwarding_unit is
------------------------------
-- SIGNALS DECLARATION SECTION
------------------------------
-- Instruction code decomposition
signal current_instruction_opcode: std_logic_vector(5 downto 0);
signal current_instruction_funct: std_logic_vector(5 downto 0);

signal previous_instruction_opcode: std_logic_vector(5 downto 0);
signal previous_instruction_funct: std_logic_vector(5 downto 0);

signal previous2_instruction_opcode: std_logic_vector(5 downto 0);
signal previous2_instruction_funct: std_logic_vector(5 downto 0);

-- Source register(s) of current instruction
signal rtype_current_rs: std_logic_vector(4 downto 0);
signal rtype_current_rt: std_logic_vector(4 downto 0);

signal itype_current_rs: std_logic_vector(4 downto 0);

-- Destination register of previous instruction
signal rtype_previous_rd: std_logic_vector(4 downto 0);
signal itype_previous_rt: std_logic_vector(4 downto 0);

-- Destination register of previousprevious instruction
signal rtype_previous2_rd: std_logic_vector(4 downto 0);
signal itype_previous2_rt: std_logic_vector(4 downto 0);

-- Other internal signals
signal forwarding_taken: std_logic;

--------------------------------
-- CONSTANTS DECLARATION SECTION
--------------------------------

-- FUNCT constants for R-type instructions
------------------------------------------
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
-- Jum register
constant funct_jr: std_logic_vector(5 downto 0)  := "001000";

-- OPCODE constants for I-type instructions
-------------------------------------------
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
begin

	-- SIGNAL ASSIGNMENTS
	rtype_current_rs <= current_instruction_ID_EX(25 downto 21);
	rtype_current_rt <= current_instruction_ID_EX(20 downto 16);

	itype_current_rs <= current_instruction_ID_EX(25 downto 21);

	-- Destination register of previous instruction
	rtype_previous_rd <= previous_instruction_EX_MEM(15 downto 11);
	itype_previous_rt <= previous_instruction_EX_MEM(20 downto 16);

	-- Destination register of previousprevious instruction
	rtype_previous2_rd <= previous2_instruction_MEM_WB(15 downto 11);
	itype_previous2_rt <= previous2_instruction_MEM_WB(20 downto 16);
	
	-- Opcode and funct decomposition
	current_instruction_opcode <= current_instruction_ID_EX(31 downto 26);
	current_instruction_funct <= current_instruction_ID_EX(5 downto 0);

	previous_instruction_opcode <= previous_instruction_EX_MEM(31 downto 26);
	previous_instruction_funct <= previous_instruction_EX_MEM(5 downto 0);

	previous2_instruction_opcode <= previous2_instruction_MEM_WB(31 downto 26);
	previous2_instruction_funct <= previous2_instruction_MEM_WB(5 downto 0);

	process(clock, reset)
	begin
		if reset = '1' then
	
			forwarding_taken <= '0';
			fwd_result_rs <= (others => '0');
			fwd_result_rt <= (others => '0');

		else
			if (current_instruction_opcode = r_type_general_op_code) and not(current_instruction_funct = funct_mfhi) and not(current_instruction_funct = funct_mflo) then
				
			-- Current instruction: R-type instructions without MFHI and MFLO
			report "current instruction is R-type, but not mfhi nor mflo";
				
				if(previous_instruction_opcode = r_type_general_op_code) then -- previous: rtype
				report "previous instruction is R-type";
					if rtype_current_rs = rtype_previous_rd then
						forwarding_taken <= '1';
						fwd_result_rs <= previous_data_EX_MEM;
						fwd_result_rt <= current_rt_data;
					end if;
					if rtype_current_rt = rtype_previous_rd then
						forwarding_taken <= '1';
						fwd_result_rs <= current_rs_data;
						fwd_result_rt <= previous_data_EX_MEM;
					end if;
				end if;
				
				if (previous_instruction_opcode = r_type_general_op_code) and not(rtype_current_rs = rtype_previous_rd) and not(rtype_current_rt = rtype_previous_rd ) then
				report "no data dependency with (previous=r-type), now checking previous previous instruction";
				
					if previous2_instruction_opcode = r_type_general_op_code then --previous previous: rtype
					report "previous previous is R-type";
						if rtype_current_rs = rtype_previous2_rd then
							forwarding_taken <= '1';
							fwd_result_rs <= previous2_data_MEM_WB;
							fwd_result_rt <= current_rt_data;
						end if;
						if rtype_current_rt = rtype_previous_rd then
							forwarding_taken <= '1';
							fwd_result_rs <= current_rs_data;
							fwd_result_rt <= previous2_data_MEM_WB;
						end if;
					
					elsif to_integer(unsigned(previous2_instruction_opcode)) > 3 then --previous previous: itype
					report "previous previous instruction is I-type";
						if rtype_current_rs = itype_previous2_rt then
							forwarding_taken <= '1';
							fwd_result_rs <= previous2_data_MEM_WB;
							fwd_result_rt <= current_rt_data;
						end if;
						if rtype_current_rt <= itype_previous2_rt then
							forwarding_taken <= '1';
							fwd_result_rs <= current_rs_data;
							fwd_result_rt <= previous2_data_MEM_WB;
						end if;
					else 
					report "all (previous=rtype, previous previous=all) dependencies checked, no forwarding";
						forwarding_taken <= '0';
						fwd_result_rs <= current_rs_data;
						fwd_result_rt <= current_rt_data;
					end if;
				end if;
				
				if to_integer(unsigned(previous_instruction_opcode)) > 3 then -- previous: itype
				report "previous instruction is I-type";
					if rtype_current_rs = itype_previous_rt then
						forwarding_taken <= '1';
						fwd_result_rs <= previous_data_EX_MEM;
						fwd_result_rt <= current_rt_data;
					end if;
					if rtype_current_rt = itype_previous_rt then
						forwarding_taken <= '1';
						fwd_result_rs <= current_rs_data;
						fwd_result_rt <= previous_data_EX_MEM;
					end if;
				end if;
				
				if to_integer(unsigned(previous_instruction_opcode)) > 3 and not(rtype_current_rs = itype_previous_rt) and not(rtype_current_rt = itype_previous_rt) then
				report "no data dependency with (previous=i-type), now checking previous previous instruction";
				
					if previous2_instruction_opcode = r_type_general_op_code then --previous previous: rtype
					report "previous previous is R-type";
						if rtype_current_rs = rtype_previous2_rd then
							forwarding_taken <= '1';
							fwd_result_rs <= previous2_data_MEM_WB;
							fwd_result_rt <= current_rt_data;
						end if;
						if rtype_current_rt = rtype_previous_rd then
							forwarding_taken <= '1';
							fwd_result_rs <= current_rs_data;
							fwd_result_rt <= previous2_data_MEM_WB;
						end if;
					
					elsif to_integer(unsigned(previous2_instruction_opcode)) > 3 then --previous previous: itype
					report "previous previous instruction is I-type";
						if rtype_current_rs = itype_previous2_rt then
							forwarding_taken <= '1';
							fwd_result_rs <= previous2_data_MEM_WB;
							fwd_result_rt <= current_rt_data;
						end if;
						if rtype_current_rt <= itype_previous2_rt then
							forwarding_taken <= '1';
							fwd_result_rs <= current_rs_data;
							fwd_result_rt <= previous2_data_MEM_WB;
						end if;
					else 
					report "all (previous=itype, previous previous=all) dependencies checked, no forwarding";
						forwarding_taken <= '0';
						fwd_result_rs <= current_rs_data;
						fwd_result_rt <= current_rt_data;
					end if;
				end if;
				
			elsif to_integer(unsigned(current_instruction_opcode)) > 3 then
				-- Current instruction: I-type instructions
			report "current instruction is I-type";
				
				if(previous_instruction_opcode = r_type_general_op_code) then -- previous: rtype
				report "previous instruction is R-type";
					if itype_current_rs = rtype_previous_rd then
						forwarding_taken <= '1';
						fwd_result_rs <= previous_data_EX_MEM;
						fwd_result_rt <= current_rt_data;
					end if;
				end if;
				
				if (previous_instruction_opcode = r_type_general_op_code) and not(itype_current_rs = rtype_previous_rd) then
				report "no data dependency with (previous=r-type), now checking previous previous instruction";
				
					if previous2_instruction_opcode = r_type_general_op_code then --previous previous: rtype
					report "previous previous is R-type";
						if itype_current_rs = rtype_previous2_rd then
							forwarding_taken <= '1';
							fwd_result_rs <= previous2_data_MEM_WB;
							fwd_result_rt <= current_rt_data;
						end if;
					
					elsif to_integer(unsigned(previous2_instruction_opcode)) > 3 then --previous previous: itype
					report "previous previous instruction is I-type";
						if itype_current_rs = itype_previous2_rt then
							forwarding_taken <= '1';
							fwd_result_rs <= previous2_data_MEM_WB;
							fwd_result_rt <= current_rt_data;
						end if;
					else 
					report "all (previous=rtype, previous previous=all) dependencies checked, no forwarding";
						forwarding_taken <= '0';
						fwd_result_rs <= current_rs_data;
						fwd_result_rt <= current_rt_data;
					end if;
				end if;
				
				if to_integer(unsigned(previous_instruction_opcode)) > 3 then -- previous: itype
				report "previous instruction is I-type";
					if itype_current_rs = itype_previous_rt then
						forwarding_taken <= '1';
						fwd_result_rs <= previous_data_EX_MEM;
						fwd_result_rt <= current_rt_data;
					end if;
				end if;
				
				if to_integer(unsigned(previous_instruction_opcode)) > 3 and not(itype_current_rs = itype_previous_rt) then
				report "no data dependency with (previous=i-type), now checking previous previous instruction";
				
					if previous2_instruction_opcode = r_type_general_op_code then --previous previous: rtype
					report "previous previous is R-type";
						if itype_current_rs = rtype_previous2_rd then
							forwarding_taken <= '1';
							fwd_result_rs <= previous2_data_MEM_WB;
							fwd_result_rt <= current_rt_data;
						end if;
					
					elsif to_integer(unsigned(previous2_instruction_opcode)) > 3 then --previous previous: itype
					report "previous previous instruction is I-type";
						if itype_current_rs = itype_previous2_rt then
							forwarding_taken <= '1';
							fwd_result_rs <= previous2_data_MEM_WB;
							fwd_result_rt <= current_rt_data;
						end if;
					else 
					report "all (previous=itype, previous previous=all) dependencies checked, no forwarding";
						forwarding_taken <= '0';
						fwd_result_rs <= current_rs_data;
						fwd_result_rt <= current_rt_data;
					end if;
				end if;
					
			elsif current_instruction_funct = funct_mfhi then
			-- Special cases of MFHI and MFLO
				null;
			elsif current_instruction_funct = funct_mflo then
				null;
			
			else
				report "Current instruction is neither a R-type nor an I-type, no forwarding needed";
						forwarding_taken <= '0';
						fwd_result_rs <= current_rs_data;
						fwd_result_rt <= current_rt_data;
			end if;				
		end if;
	end process;
end architecture;
