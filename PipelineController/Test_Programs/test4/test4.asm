addi $1, $0, 1 #place 1 into regsiter 1
addi $2, $0, 2
addi $3, $0, 3 #stall to avoid data hazard
sw $1, 0($0)  #store contents of reg 1 into memory address 0
