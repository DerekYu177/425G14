addi $1, $0, 1 #place 1 into regsiter 1
addi $2, $0, 2
addi $2, $0, 3
addi $3, $0, 4 #stall to avoid data hazard
sw $0, 0($1)  #store contents of reg 1 into memory address 0
