### update as we know more

###### Pipeline
Implemented as a FSM.

###### Testbench
The Testbench must:
  1. be able to read from the instructions translated by the assembler (the instructions are in binary).

Basically,
  1. given a file "program.txt", we put the program into instruction memory (how?)
  2. we traverse through the instruction memory, modifying "register_file.txt" at the very end (can this be done through write-back with a cache flush at the very end?)
