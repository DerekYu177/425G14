### Update as we know more

#### Pipeline
Implemented as a FSM.

#### Testbench
The Testbench must:
  1. Initialize the data memory.txt file upon starting, effectively starting from a blank slate
  2. Initialize PC = 0
  3. Read from the instructions translated by the assembler (the instructions are in binary), and pass them one at a time into the pipeline. These are 32 bit lines.
  4. Wait the appropriate amount of time for the output to occur (initial latency = 5 clock cycles)
  5. Understand the output from the pipeline:
    * R instruction, where the output should be the register + register value
    * Jump/Branch instruction, where the output should indicate the new PC value to jump to
  6. Update PC accordingly
  7. Update the memory.txt file accordingly
  8. Read the next line of the program.txt file
  9. Keep the register values as internal signals
  10. Repeat until PC reaches the end of the program
  11. Update register_file.txt appropriately 


Basically,
  1. given a file "program.txt", we put the program into instruction memory (how?)
  2. we traverse through the instruction memory, modifying "register_file.txt" at the very end (can this be done through write-back with a cache flush at the very end?)

(ctrl-shift-m)
