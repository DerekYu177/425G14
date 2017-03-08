LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE IEEE.std_logic_unsigned.all;

entity processor is
  port(
    clock : in std_logic;
    reset : in std_logic;

    -- inputs --
    program_in : in std_logic_vector(31 downto 0);
    program_in_finished : in std_logic;

    -- outputs --
    program_execution_finished : out std_logic;
    memory_out_finished : out std_logic;
    register_out_finished : out std_logic;
    memory_out : out std_logic_vector(31 downto 0);
    register_out : out std_logic_vector(31 downto 0)
  );
end processor;

architecture impl of processor is

signal program_finished_counter : in integer range 0 to ram_size-1;
signal mem_write , mem_read , wait_signal : in std_logic;
signal read_data : std_logic_vector(31 downto 0);
signal reg_input1,reg_input2 :std_logic_vector(5 downto 0); 
reg_input1 <= read_data(10 downto 6);
reg_input2 <= read_data(15 downto 11);
signal A_ID, B_ID : std_logic_vector(31 downto 0); 
signal to_jump, immediate : std_logic; 
signal mux1_output , mux2_output : std_logic_vector(31 downto 0);
signal ALU_Output : std_logic_vector(31 downto 0);


component instruction_memory 
	port(
		clock : in std_logic;
		writedata : in std_logic_vector(31 downto 0);

		address : in integer range 0 to ram_size-1;
		memwrite : in std_logic;
		memread : in std_logic;
		readdata : out std_logic_vector(31 downto 0);-- read data is output out it in there as a signal and assign it to it.
		waitrequest : out std_logic -- output is a std_logic vector
	);
	end component;
	
component data_memory 
	port(
		clock : in std_logic;
		writedata : in std_logic_vector(31 downto 0);
		
		address : in integer range 0 to ram_size-1;
		memwrite : in std_logic;
		memread : in std_logic;
		readdata : out std_logic_vector(31 downto 0);
		waitrequest : out std_logic
	);
	end component; 
	
component registers
 port(
 	   reg1 : in STD_LOGIC_VECTOR(5 downto 0); -- one  they are equated to IR and 
 	   reg2 : in STD_LOGIC_VECTOR(5 downto 0); -- 2nd register
 	   reg3 : in STD_LOGIC_VECTOR(); -- how many bits 
 	   data : in STD_LOGIC_ VECTOR(31 downto 0); 
 	   A : out STD_LOGIC_VECTOR(31 downto 0); 
 	   B : out STD_LOGIC_VECTOR(31 downto 0);
 	   );
 	   end component;
 	   
 	   
 	   
component mux
 Port ( SEL0 : in  STD_LOGIC;
    	   A   : in  STD_LOGIC_VECTOR (31 downto 0);
           B   : in  STD_LOGIC_VECTOR (31 downto 0);
           X   : out STD_LOGIC_VECTOR (31 downto 0));
        end component; 
        

component ALU
port(
clock, reset: in std_logic;
ALU_operation, ALU_operand1, ALU_operand2: in std_logic_vector(31 downto 0);
ALU_PC: in std_logic_vector(31 downto 0);
ALU_output: out std_logic_vector(31 downto 0)
-- Maybe additional control signals that tells the ALU operands are valid?
);
end component; 


BEGIN 

inst_memory: instruction_memory port map(clock => clock ,
										 writedata =>porgram_in ,
										 address =>program_finished_counter, 
										 memwrite => mem_write,
										 memread => mem_read,
										 readdata => read_data; -- this is the data to be read 
										 waitsignal => wait_signal;
										 );

registers : registers port map( clock => clock , 
								reg1 => reg_input1, 
								reg2 => reg_input2, 
								reg3 => 
								data =>
								A => A_ID,
								B => B_ID, 
								);
								
mux1 : mux port map( A => A_ID,
					 B => PC + 4, -- this has to be program counter +4 coming out of mux
					 SEL => to_jump,
					 X => mux1_output
					 ); 
					 
mux2 : mux port map( A => B_ID,
					 B =>16 bit extened to 32 bit -- to tell if its an immediate add or operation 
					 SEL => immediate,
					 X => mux2_output,
					 );
					 
ALUoperations : ALU port map ( clock => clock ,
							   reset => reset , 
							   ALU_operand1 => mux1_output,
							   ALU_operand2 => mux2_output,
							   ALU_operation => program_in,
							   ALU_PC =>
							   ALU_output =>ALU_Output
							   );
	
	end impl;
							   
							   
							   
					 

								

								
								




