### Update as we know more

##### We realized that an FSM does not allow us to compute instructions in paralled, because it will only execute one state at a time. Thus the new design allows us to execute components in parallel.

#### Pipeline
The Pipeline is:
  1. a collection of components. Each component represents one stage in the pipeline. i.e. IF is one component, with it's own entity and architecture.
  2. components separated by a pipeline register bus. Each stage component can only access the adjacent pipeline registers initially. i.e. ID component can only interact with the if_id register bus and the id_ex register bus.
  3. components which are given access to memory if they need it. This means that IF can access the instruction memory, but perhaps not the register memory.
  4. A three stage FSM, with states _init_, _process_, and _fini_. _init_ communicates with the testbench to receive data. _process_ is where the processor is working, and _fini_ again communicates appropriately with the testbench in order to return data.
 
#### Pipeline Register Bus (PRB)
  1. The PRB is the principle way of communicating between components. It is a straightforward active-high clock & asynchronous clear register. 
  2. The PRB contains 10 inputs and 10 outputs. These are
    1. 3 x 32b registers, named data_1, data_2, and scratch
    2. 2 x integer registers, one for PC, and the other for Address
    3. 2 x 1b valid registers, one for PC and the other for Address
    4. 3 x 1b valid registers, one for loading into memory, one for storing into memory, and one for storing into the registers. 
  3. The connections between the components and the PRB is outlined in the PR located here: https://github.com/DerekYu177/425G14/pull/17

#### Forwarding
  1. The logic behind forwarding is that the EX stage has the choice to select between what is provided by the ID stage or the current output (at the EX/MEM register).
  2. It should ALWAYS choose the current output (fed back) IF  AND ONLY IF the destination register of the previous instruction matches the (or one of the) source register of the current instruction. In other words, the operand provided by the ID stage is MEANT TO BE UPDATED, and hence invalid.
  3. The idea of $[EX/MEM] -> EX input can be further generalized to cases of $[MEM/WB] -> EX input, and $[MEM/WB] -> MEM input. More if-statements should be addded with care.

#### Concrete Implementation of Forwarding
  
  1. At the EX stage, check if the instruction_register at the beginning holds an instruction (call this i_current) that:
    a) If R-type: 
    Check the instruction at the end of EX stage (call this i_prev), what type is it?
    
      i)
      If i_prev is R-type, does i_prev holds a destination register that is currently being consumed as the source register of i_current (data dependency)?
      if YES ->
      This corresponds to the case of:
      ADD R1 R2 R3 (previous instruction, located in the inst-reg at the end of EX stage, EX_MEM)
      SUB R4 R1 R5 (current instruction, located in the inst-reg at the beginning of EX stage, ID_EX)
      Since all R-type produces their result by EX with 1cc latency, the updated data resulting from executing i_prev should already be ready.
      SELECT FORWARDING FROM EX's output to EX's input
      if NO ->
      NO FORWARDING, nothing additional
      
      ii) If i_prev is an I-type
      Does i_prev holds a destination register that is currently being consumed as the source register of i_current (data dependency)?
      is it a LOAD? if yes ->
      This corresponds to the case of:
      L.D R1 R2 imm (i_prev)
      ADD R4 R1 R5 (i_current)
      Since load only produces at at the end of MEM, it means R1 is not ready yet
      NO FORWADING, STALL to prevent RAW hazard
      is it a STORE? if yes ->
      This corresponds to the case
      S.W R1 R2 imm (i_prev)
      ADD R5 R1 R6 (i_current)
      NO FORWARDING, nothing additional
      Is it an immediate-reg arithmentics? if yes ->
      This correponds to the case of:
      ADDI R1 R2 imm (i_prev)
      ADD R3 R1 R4 (i_current)
       Since immediate-reg arithmentics produce their result by EX with 1cc latency, the updated data resulting from executing i_prev should already be ready.
      SELECT FORWARDING FROM EX's output to EX's input
      
      We then peek 1 stage further (instruction from MEM/WB), but here things are much easier, we disregard all R-type instructions (they're already handled before), we forward from MEM/WB to ID/EX if and only if when the instruction is a LOAD, since the loading should be done producing by now
      L.D R1 R2 imm
      ADD R3 R4 R5 (R1 not ready yet)
      SUB R6 R1 R7 (R1 is ready now)
      
    b) If I-type
      TODO
    
      
      
       
  
#### Testbench
The Testbench must:
  1. Open both the program.txt and the memory.txt to begin sending to the pipeline
  2. Set the reset switch to '1'
  3. Read from the instructions translated by the assembler (the instructions are in binary), and pass them one at a time into the pipeline. These are 32 bit lines.
  4. When all the data has been passed through, assert memory_in_finished and program_in_finished.
  4. Wait until the pipeline has asserted program_execution_finished.
  5. The pipeline should then output, one line at a time, the entire register file and the entire data file.
  6. Once finished, the testbench waits until the pipeline has asserted  memory_out_finished and register_out_finished
  7. Update the memory.txt file accordingly
  8. Update register_file.txt accordingly

(ctrl-shift-m)
