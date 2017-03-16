	addi $1, $0, 2 #place 2 into register 1
loop:	addi $2, $2, 1 #increment 2 by 1
	bne $1, $2, loop #if reg 2 hasn't incremented to 2 yet, keep incrementing