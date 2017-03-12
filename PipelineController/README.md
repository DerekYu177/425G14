### Update as we know more

##### We realized that an FSM does not allow us to compute instructions in paralled, because it will only execute one state at a time. Thus the new design allows us to execute components in parallel.

#### Pipeline
The Pipeline is:
  1. a collection of components. Each component represents one stage in the pipeline. i.e. IF is one component, with it's own entity and architecture.
  2. components separated by a pipeline register. Each stage component can only access the adjacent pipeline registers initially. i.e. ID component can only interact with the if_id register and the id_ex register.
  3. components which are given access to memory if they need it. This means that IF can access the instruction memory, but perhaps not the register memory.
  4. A three stage FSM, with states _init_, _process_, and _finished_. _init_ communicates with the testbench to receive data. _process_ is where the processor is working, and _finished_ again communicates appropriately with the testbench in order to return data.
  
#### Forwarding
  1. The logic behind forwarding is that the EX stage has the choice to select between what is provided by the ID stage or the current output (at the EX/MEM register).
  2. It should ALWAYS choose the current output (fed back) IF  AND ONLY IF the destination register of the previous instruction matches the (or one of the) source register of the current instruction. In other words, the operand provided by the ID stage is MEANT TO BE UPDATED, and hence invalid.
  3. The idea of $[EX/MEM] -> EX input can be further generalized to cases of $[MEM/WB] -> EX input, and [MEM/WB] -> MEM input. More if-statements should be addded with care.
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
