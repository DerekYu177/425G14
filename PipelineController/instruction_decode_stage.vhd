library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity instruction_decode_stage is
  port(
    clock : in std_logic;
    reset : in std_logic;

    -- interface with the register memory --
    read_1_address : out std_logic_vector(31 downto 0);
    read_2_address : out std_logic_vector(31 downto 0);
    register_1 : in std_logic_vector(31 downto 0);
    register_2 : in std_logic_vector(31 downto 0);
    register_hi : in std_logic_vector(31 downto 0);
    register_lo : in std_logic_vector(31 downto 0);

    -- main pipeline interface --
    instruction : in std_logic_vector(31 downto 0);
    id_ex_reg_1 : out std_logic_vector(31 downto 0);
    id_ex_reg_2 : out std_logic_vector(31 downto 0);

    load_store_address : out std_logic_vector(31 downto 0);
    load_store_address_valid : out std_logic;
    load_memory_valid : out std_logic;
    store_memory_valid : out std_logic;
    store_register : out std_logic
  );
end instruction_decode_stage;

architecture arch of instruction_decode_stage is

  -- whenever we want to pull from register using index we set this to 1
  -- whenever we want to indicate garbage is on the read_1_address/read_0_address we set this to 0

  -- General op code
  signal op_code: std_logic_vector(5 downto 0) := instruction(31 downto 26);

  -- R-type decomposition
  signal rtype_rs: std_logic_vector(31 downto 0) := (31 downto 5 => '0') & instruction(25 downto 21);
  signal rtype_rt: std_logic_vector(31 downto 0) := (31 downto 5 => '0') & instruction(20 downto 16);
  signal rtype_rd: std_logic_vector(31 downto 0) := (31 downto 5 => '0') & instruction(15 downto 11);
  signal shamt: std_logic_vector(4 downto 0) := instruction(10 downto 6);
  signal funct: std_logic_vector(5 downto 0) := instruction(5 downto 0);

  -- I-type decomposition
  signal itype_rs: std_logic_vector(31 downto 0) := (31 downto 5 => '0') & instruction(25 downto 21);
  signal itype_rt: std_logic_vector(31 downto 0) := (31 downto 5 => '0') & instruction(20 downto 16);
  signal immediate: std_logic_vector(15 downto 0) := instruction(15 downto 0);
  signal blank_immediate_header : std_logic_vector(15 downto 0) := (others => instruction(15));
  signal extended_immediate: std_logic_vector(31 downto 0);
  signal extended_immediate_shifted: std_logic_vector(31 downto 0);

  -- J-type decomposition
  signal jump_address_offset: std_logic_vector(25 downto 0) := instruction(25 downto 0);

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

  begin
  op_code <= instruction(31 downto 26);

  -- R-type decomposition
  rtype_rs <= (31 downto 5 => '0') & instruction(25 downto 21);
  rtype_rt <= (31 downto 5 => '0') & instruction(20 downto 16);
  rtype_rd <= (31 downto 5 => '0') & instruction(15 downto 11);
  shamt <= instruction(10 downto 6);
  funct <=  instruction(5 downto 0);
  -- I-type decomposition
  itype_rs <= (31 downto 5 => '0') & instruction(25 downto 21);
  itype_rt <= (31 downto 5 => '0') & instruction(20 downto 16);
  immediate <= instruction(15 downto 0);
  blank_immediate_header <= (others => instruction(15));

  -- J-type decomposition
  -- For j and jal
  jump_address_offset <= instruction(25 downto 0);

  -- For sw/lw
  extended_immediate <= (31 downto 16 => immediate(15)) & immediate;

  -- For bne/beq
  extended_immediate_shifted <= (31 downto 18 => immediate(15)) & immediate & "00";

  -- TODO: add load/store logic here so we know how to approach the register file

  pipeline_output : process(reset, instruction)
  begin
  if reset = '1' then
    load_store_address_valid <= '0'; -- still unused!
    load_memory_valid <= '0';
    store_memory_valid <= '0';
    store_register <= '0';
  else
    case op_code is
      when R_type_general_op_code =>

        --All R-type operations
        case funct is
          when funct_add | funct_sub | funct_mult | funct_div | funct_slt | funct_and | funct_or | funct_nor | funct_xor =>
            id_ex_reg_1 <= register_1;
            id_ex_reg_2 <= register_2;
            store_register <= '1';
            load_memory_valid <= '0';
            store_memory_valid <= '0';
            load_store_address <= rtype_rd; -- rd as destination
            load_store_address_valid <= '0';

          when funct_mfhi =>
            load_store_address <= rtype_rd;
            load_store_address_valid <= '1';
            id_ex_reg_1 <= register_hi;
            id_ex_reg_2 <= std_logic_vector(to_unsigned(0, 32));
            load_memory_valid <= '0';
            store_memory_valid <= '0';
            store_register <= '1';

          when funct_mflo =>
            load_store_address <= rtype_rd;
            load_store_address_valid <= '1';
            id_ex_reg_1 <= register_lo;
            id_ex_reg_2 <= std_logic_vector(to_unsigned(0, 32));
            load_memory_valid <= '0';
            store_memory_valid <= '0';
            store_register <= '1';

          when funct_sll | funct_srl | funct_sra =>
            id_ex_reg_1 <= std_logic_vector(to_unsigned(0, 32));
            id_ex_reg_2 <= register_2;
            store_register <= '1';
            load_memory_valid <= '0';
            store_memory_valid <= '0';
            load_store_address <= rtype_rd; -- rd as destination
            load_store_address_valid <= '1';

          when funct_jr =>
            id_ex_reg_1 <= register_1;
            id_ex_reg_2 <= std_logic_vector(to_unsigned(0, 32));
            store_register <= '0'; -- We are not storing anything in register
            load_memory_valid <= '0';
            store_memory_valid <= '0';
            load_store_address <= (others => '0'); -- When not used, default it to 0
            load_store_address_valid <= '0';

          when others =>
            -- Everything defaulted to 0
            store_register <= '0';
            load_memory_valid <= '0';
            store_memory_valid <= '0';
            load_store_address <= (others => '0');
            load_store_address_valid <= '0';
            id_ex_reg_1 <= std_logic_vector(to_unsigned(0, 32));
            id_ex_reg_2 <= std_logic_vector(to_unsigned(0, 32));

        end case;

      --All I-type operations
      when I_type_op_addi | I_type_op_andi | I_type_op_ori | I_type_op_xori =>
        id_ex_reg_2 <= blank_immediate_header & immediate;
        id_ex_reg_1 <= register_1;
        store_register <= '1';
        load_memory_valid <= '0';
        store_memory_valid <= '0';
        load_store_address <= itype_rt;
        load_store_address_valid <= '0';

      when I_type_op_slti =>
        id_ex_reg_2 <= extended_immediate;
        id_ex_reg_1 <= register_1;
        store_register <= '1';
        load_memory_valid <= '0';
        store_memory_valid <= '0';
        load_store_address <= rtype_rt;
        load_store_address_valid <= '0';

      when I_type_op_lw =>
        id_ex_reg_1 <= register_1;
        id_ex_reg_2 <= extended_immediate;
        -- Special case where both store_register and load_memory_valid is high
        store_register <= '1';
        load_memory_valid <= '1';
        store_memory_valid <= '0';
        load_store_address <= itype_rt; -- LOAD FROM MEM TO $RT
        load_store_address_valid <= '1';

      when I_type_op_sw =>
        id_ex_reg_1 <= register_1;
        id_ex_reg_2 <= extended_immediate;
        store_register <= '0'; -- Not storing in register
        load_memory_valid <= '0';
        store_memory_valid <= '1';
        load_store_address <= itype_rt; -- STORE FROM $RT TO MEM
        load_store_address_valid <= '1';

      when I_type_op_beq | I_type_op_bne =>
        id_ex_reg_1 <= register_1;
        id_ex_reg_2 <= register_2;
        store_register <= '0'; -- Not storing in register
        load_memory_valid <= '0';
        store_memory_valid <= '0';
        load_store_address <= (others => '0'); -- When not used, default it to 0
        load_store_address_valid <= '0';

      when others =>
        -- handles I_type_op_lui | J_type_op_j | J_type_op_jal
        store_register <= '0';
        load_memory_valid <= '0';
        store_memory_valid <= '0';
        load_store_address <= (others => '0');
        load_store_address_valid <= '0';
        id_ex_reg_1 <= std_logic_vector(to_unsigned(0, 32));
        id_ex_reg_2 <= std_logic_vector(to_unsigned(0, 32));
      end case;
    end if;
  end process;

  register_output : process(reset, instruction)
  begin
    if reset = '1' then
      read_1_address <= (others => '0');
      read_2_address <= (others => '0');
    else
      case op_code is
        when R_type_general_op_code =>

            case funct is
              when funct_add | funct_sub | funct_mult | funct_div | funct_slt | funct_and | funct_or | funct_nor | funct_xor =>
                read_1_address <= rtype_rs;
                read_2_address <= rtype_rt;

              when funct_sll | funct_srl | funct_sra =>
                read_1_address <= (others => '0');
                read_2_address <= rtype_rt;

              when funct_jr =>
                read_1_address <= rtype_rs;
                read_2_address <= (others => '0');

              when others =>
                -- includes funct_mfhi | funct_mflo
                read_1_address <= (others => '0');
                read_2_address <= (others => '0');

          end case;

        when I_type_op_addi | I_type_op_andi | I_type_op_ori | I_type_op_xori | I_type_op_slti | I_type_op_lw | I_type_op_sw =>
          read_1_address <= itype_rs;
          read_2_address <= (others => '0');

        when I_type_op_beq | I_type_op_bne =>
          read_1_address <= itype_rs;
          read_2_address <= itype_rt;

        when others =>
          -- handles I_type_op_lui | I_type_op_beq | I_type_op_bne
          read_1_address <= (others => '0');
          read_2_address <= (others => '0');

        end case;
    end if;

  end process;
end arch;
