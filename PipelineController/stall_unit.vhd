library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity stall_unit is
  port(
  clock : in std_logic;
  reset : in std_logic;

  -- Instruction signals
  if_id_out: in std_logic_vector(31 downto 0);  -- Instruction that is about to be started in ID(comes from IF_ID register output side)
  id_ex_out: in std_logic_vector(31 downto 0); -- Instruction that is about to be started in EX(comes from ID_EX register output side)
  instruction_chosen: out std_logic_vector(31 downto 0);
  -- Control signal towards IF stage
  stall: out std_logic
  );
end stall_unit;

architecture arch of stall_unit is
------------------------------
-- SIGNALS DECLARATION SECTION
------------------------------
-- Instruction code decomposition
signal instruction_ID_opcode: std_logic_vector(5 downto 0);
signal instruction_EX_opcode: std_logic_vector(5 downto 0);

-- Source register(s) of instruction in ID
signal rtype_ID_rs: std_logic_vector(4 downto 0); -- Same as itype_ID_rs, doesn't really matter
signal rtype_ID_rt: std_logic_vector(4 downto 0);

-- Destination register of instruction in EX, assuming that it's a load (the only case that a stall might be needed)
signal load_EX_rt: std_logic_vector(4 downto 0);
-- In case of a stall, need to keep the stalled instruction as a internal signal
signal stalled_instruction: std_logic_vector(31 downto 0);
-- Control signal
signal stall_evicted: std_logic:='1';

--------------------------------
-- CONSTANTS DECLARATION SECTION
--------------------------------
-- All R type opcode
constant R_type_general_op_code: std_logic_vector(5 downto 0) := "000000";
-- LW opcode
constant I_type_op_lw: std_logic_vector(5 downto 0) := "100011";
-- Hard coded stall_instruction ADD R0 R0 R0
constant stall_instruction: std_logic_vector(31 downto 0) := R_type_general_op_code & "00000" & "00000" & "00000" & "00000" & "100000";

begin

	-- SIGNAL ASSIGNMENTS
  -- Source registers of ID instruction
	rtype_ID_rs <= if_id_out(25 downto 21); -- Same as itype_ID_rs, doesn't really matter
	rtype_ID_rt <= if_id_out(20 downto 16);

	-- Destination register of EX's ID, assuming it's a load instruction
	load_EX_rt <= id_ex_out(20 downto 16);

	-- Opcode
	instruction_ID_opcode <= if_id_out(31 downto 26);
	instruction_EX_opcode <= id_ex_out(31 downto 26);

	process(clock, reset)
	begin
		if reset = '1' then

			stall_evicted <= '1';
      stall <= '0';
      instruction_chosen <= (others => '0');
      stalled_instruction <= (others => '0');

		else
			if stall_evicted = '0' then -- there is a stalled instruction, must evict it no matter what
      -- Note: this also means that just prior to this situation, a stall has been issued, hence the previous instruction is for sure a ADD $0 $0 $0
      -- IF was previously forbidden from issuing new instruction into ID as well
          report "Stalled instruction exists, STALL EVICTION in action";
          instruction_chosen <= stalled_instruction;
          stalled_instruction <= (others => '0');

          -- put the flag down to allow IF to pass in next instruction
          stall <= '0';
          -- indicate that the stalled instruction has been evicted
          stall_evicted <= '1';
      else -- stall slot is empty
        if instruction_ID_opcode = R_type_general_op_code or to_integer(unsigned(instruction_ID_opcode)) > 3 then -- ID instruction is either R type or I type
          if instruction_EX_opcode = I_type_op_lw and (load_EX_rt = rtype_ID_rt or load_EX_rt = rtype_ID_rs) then-- if instruction about to be processed in EX is a load whose dest matches source of inst in ID
            report "The instruction in EX is a load whose destination reg matches a source register of the instruction in ID -- STALL in action";
            instruction_chosen <= stall_instruction; -- ADD $0 $0 $0
            stalled_instruction <= if_id_out;

            -- put the flag up to forbid IF to pass in next instruction
            stall <= '1';
            -- indicate that the stalled slot is now occupied
            stall_evicted <= '0';
          else
            report "Either EX instruction is not a load, either it is but its destination does not match a source register of the ID instruction -- NO STALL";
            instruction_chosen <= if_id_out;
            stalled_instruction <= (others => '0');
            stall <= '0';
            stall_evicted <= '1';
          end if;
        else
          report "ID instruction neither a R tyoe or an I type -- NOT STALL";
          instruction_chosen <= if_id_out;
          stalled_instruction <= (others => '0');
          stall <= '0';
          stall_evicted <= '1';
        end if;

      end if;
		end if;
	end process;
end architecture;
