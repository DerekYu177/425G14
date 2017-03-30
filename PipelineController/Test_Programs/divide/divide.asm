addi $1, $0, 5 #put 5 into register 1
addi $2, $0, 2 #put 2 into register 2
div $1, $2 #divide 5/2
mflo $3 # put dividend into register 3 (should be 2)
mfhi $4 # put remainder into register 4 (should be 1)