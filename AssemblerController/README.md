### Update as we know more

#### Pipeline
The Pipeline must:
  * Be built and connected using the block diagram given in the handouts.
  * Be able to read line by line from the testbench and store it into its data memory and instruction memory, _ideally concurrently_.
  * Be able to detect hazards and stall appropriately

#### Testbench
The Testbench must:
  1. Open both the program.txt and the memory.txt to begin sending to the pipeline
  2. Set the reset switch to '1'
  3. Read from the instructions translated by the assembler (the instructions are in binary), and pass them one at a time into the pipeline. These are 32 bit lines. _If possible_, pass them both in concurrently
  4. When all the data has been passed through, assert memory_in_finished and program_in_finished.
  4. Wait until the pipeline has asserted program_execution_finished.
  5. The pipeline should then output, one line at a time, the entire register file and the entire data file.
  6. Once finished, the testbench waits until the pipeline has asserted  memory_out_finished and register_out_finished
  7. Update the memory.txt file accordingly
  8. Update register_file.txt accordingly

(ctrl-shift-m)
