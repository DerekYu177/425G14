addi $1, $0, 1 #place 1 into regsiter 1
addi $0, $0, 0
addi $0, $0, 0 #stall to avoid data hazard
sw $1, 0($0)  #store contents of reg 1 into memory address 0
