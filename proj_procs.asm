.include "./proj_macro.asm"
.text
#-----------------------------------------------
# C style signature 'printf(<format string>,<arg1>,
#			 <arg2>, ... , <argn>)'
#
# This routine supports %s and %d only
#
# Argument: $a0, address to the format string
#	    All other addresses / values goes into stack
#-----------------------------------------------
printf:
	#store RTE - 5 *4 = 20 bytes
	addi	$sp, $sp, -24
	sw	$fp, 24($sp)
	sw	$ra, 20($sp)
	sw	$a0, 16($sp)
	sw	$s0, 12($sp)
	sw	$s1,  8($sp)
	addi	$fp, $sp, 24
	# body
	move 	$s0, $a0 #save the argument
	add     $s1, $zero, $zero # store argument index
printf_loop:
	lbu	$a0, 0($s0)
	beqz	$a0, printf_ret
	beq     $a0, '%', printf_format
	# print the character
	li	$v0, 11
	syscall
	j 	printf_last
printf_format:
	addi	$s1, $s1, 1 # increase argument index
	mul	$t0, $s1, 4
	add	$t0, $t0, $fp # all print type assumes
			      # the latest argument pointer at $t0
	addi	$s0, $s0, 1
	lbu	$a0, 0($s0)
	beq 	$a0, 'd', printf_int
	beq	$a0, 's', printf_str
	beq	$a0, 'c', printf_char
printf_int:
	lw	$a0, 0($t0) # printf_int
	li	$v0, 1
	syscall
	j 	printf_last
printf_str:
	lw	$a0, 0($t0) # printf_str
	li	$v0, 4
	syscall
	j 	printf_last
printf_char:
	lbu	$a0, 0($t0)
	li	$v0, 11
	syscall
	j 	printf_last
printf_last:
	addi	$s0, $s0, 1 # move to next character
	j	printf_loop
printf_ret:
	#restore RTE
	lw	$fp, 24($sp)
	lw	$ra, 20($sp)
	lw	$a0, 16($sp)
	lw	$s0, 12($sp)
	lw	$s1,  8($sp)
	addi	$sp, $sp, 24
	jr $ra

# Implement au_logical
# Argument:
# 	$a0: First number
#	$a1: Second number
#	$a2: operation code ('+':add, '-':sub, '*':mul, '/':div)
# Return:
#	$v0: ($a0+$a1) | ($a0-$a1) | ($a0*$a1):LO | ($a0 / $a1)
# 	$v1: ($a0 * $a1):HI | ($a0 % $a1)
# Notes:
#####################################################################
au_logical:
	beq	$a2, '+', add_logical
	beq	$a2, '-', sub_logical
	beq	$a2, '*', mul_logical
	beq	$a2, '/', div_logical
	xor $v0, $v0, $v0
	xor $v1, $v1, $v1
	jr	$ra
add_logical:
	or $t0, $a0, $zero
	or $t1, $a1, $zero
add_logical_loop:
	beq $t1, $zero, add_logical_ret
	and $t2, $t0, $t1
	xor $t0, $t0, $t1
	sll $t1, $t2, 1
	j add_logical_loop
add_logical_ret:
	or $v0, $t0, $zero
	xor $v1, $v1, $v1
	jr $ra
sub_logical:
	or $t0, $a0, $zero
	or $t1, $a1, $zero
sub_logical_loop:
	beq $t1, $zero, sub_logical_ret
	nor $t2, $t0, $t0
	and $t2, $t2, $t1
	xor $t0, $t0, $t1
	sll $t1, $t2, 1
	j sub_logical_loop
sub_logical_ret:
	or $v0, $t0, $zero
	xor $v1, $v1, $v1
	jr $ra
mul_logical:
	or $t0, $a0, $zero
	or $t1, $a1, $zero
	xor $v0, $v0, $v0
	xor $v1, $v1, $v1
	beq $t1, $zero, mul_exit
	beq $t0, $zero, mul_exit
	xor $t3, $t0, $t1
	bge $t0, $zero, no_inv_x
	neg $t0, $t0
no_inv_x:
	bge $t1, $zero, no_inv_y
	neg $t1, $t1
no_inv_y:
	or $t4, $t0, $zero
mul_loop:
	beq $t1, 1, mul_ret
	or $t6, $t4, $zero
mul_add_logical_loop:
	beq $t4, $zero, mul_add_logical_ret
	and $t5, $t0, $t4
	xor $t0, $t0, $t4
	sll $t4, $t5, 1
	j mul_add_logical_loop
mul_add_logical_ret:
	or $t4, $t6, $zero
	ori $t6, $zero, 1
mul_sub_logical_loop:
	beq $t6, $zero, mul_sub_logical_ret
	nor $t5, $t1, $t1
	and $t5, $t5, $t6
	xor $t1, $t1, $t6
	sll $t6, $t5, 1
	j mul_sub_logical_loop
mul_sub_logical_ret:
	j mul_loop
mul_ret:
	or $v0, $t0, $zero
	bge $t3, $zero, mul_exit
	neg $v0, $v0
	nor $v1, $v1, $v1
mul_exit:
	jr $ra
div_logical:
	beq $a1, $zero, zero_divisor
	or $t0, $zero, $a0
	or $t1, $zero, $a1
	or $t2, $zero, 1
	xor $t3, $t3, $t3
#sign
	xor $t4, $t4, $t4
less1:
	bge $t0, $zero, less2
	xor $t4, $t4, 1
	neg $t0, $t0
less2: 
#copy of dividend
	or $t5, $zero, $t0
	bge $t1, $zero, loop1
	xor $t4, $t4, 1
	neg $t1, $t1
loop1:
	bgt $t1, $t0, ex1
	sll $t1, $t1, 1
	sll $t2, $t2, 1
	j loop1
ex1:
loop:
	ble $t2, 1, ex
	srl $t1, $t1, 1
	srl $t2, $t2, 1
	blt $t0, $t1, loop
	or $t7, $t1, $zero
div_sub_logical_loop:
	beq $t1, $zero, div_sub_logical_ret
	nor $t6, $t0, $t0
	and $t6, $t6, $t1
	xor $t0, $t0, $t1
	sll $t1, $t6, 1
	j div_sub_logical_loop
div_sub_logical_ret:
	or $t1, $t7, $zero
	or $t6, $t2, $zero
div_add_logical_loop:
	beq $t2, $zero, div_add_logical_ret
	and $t7, $t3, $t2
	xor $t3, $t3, $t2
	sll $t2, $t7, 1
	j div_add_logical_loop
div_add_logical_ret:
	or $t2, $t6, $zero
	j loop
ex:
	blt $t5, $t1, remainder
	or $t7, $t1, $zero
div_sub_logical_loop2:
	beq $t1, $zero, div_sub_logical_ret2
	nor $t6, $t5, $t5
	and $t6, $t6, $t1
	xor $t5, $t5, $t1
	sll $t1, $t6, 1
	j div_sub_logical_loop2
div_sub_logical_ret2:
	or $t1, $t7, $zero
	j ex
remainder:
	bge $a0, $zero, no_neg
	neg $t5, $t5
no_neg:
	or $v1, $zero, $t5
	beq $t4, $zero, output
	neg $t3, $t3
output:
	or $v0, $t3, $zero
	jr $ra
zero_divisor:
	xor $v0, $v0, $v0
	xor $v1, $v1, $v1
	jr $ra
	

#####################################################################
# Implement au_normal
# Argument:
# 	$a0: First number
#	$a1: Second number
#	$a2: operation code ('+':add, '-':sub, '*':mul, '/':div)
# Return:
#	$v0: ($a0+$a1) | ($a0-$a1) | ($a0*$a1):LO | ($a0 / $a1)
# 	$v1: ($a0 * $a1):HI | ($a0 % $a1)
# Notes:
#####################################################################
au_normal:
	beq	$a2, '+', add_normal
	beq	$a2, '-', sub_normal
	beq	$a2, '*', mul_normal
	beq	$a2, '/', div_normal
	xor $v0, $v0, $v0
	xor $v1, $v1, $v1
	jr	$ra
add_normal:
	add $v0, $a0, $a1
	jr $ra
sub_normal:
	sub $v0, $a0, $a1
	jr $ra
mul_normal:
	mult $a0, $a1
	mflo $v0
	mfhi $v1
	jr $ra
div_normal:
	div $a0, $a1
	mflo $v0
	mfhi $v1
	jr $ra
	