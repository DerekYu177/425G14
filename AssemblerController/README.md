The Pipeline itself is implemented as a FSM.

Basically,
  1. given a file "program.txt", we put the program into instruction memory (how?)
  2. we traverse through the instruction memory, modifying "register_file.txt" at the very end (can this be done through write-back with a cache flush at the very end?)

Deliverables:
  1.Processor, with binary inputs and the "register_file.txt" output.
