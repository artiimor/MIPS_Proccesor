# Prog de prueba para Practica 2. Ej 2

.data 0
num0: .word 1 # posic 0
num1: .word 2 # posic 4
num2: .word 4 # posic 8 
num3: .word 8 # posic 12 
num4: .word 16 # posic 16 
num5: .word 32 # posic 20
num6: .word 0 # posic 24
num7: .word 0 # posic 28
num8: .word 0 # posic 32
num9: .word 0 # posic 36
num10: .word 0 # posic 40
num11: .word 0 # posic 44
.text 0
main:
  # carga num0 a num5 en los registros 9 a 14
  lw $t1, 0($zero) # lw $r9, 0($r0)
  lw $t2, 4($zero) # lw $r10, 4($r0)
  lw $t3, 8($zero) # lw $r11, 8($r0)
  lw $t4, 12($zero) # lw $r12, 12($r0)
  lw $t5, 16($zero) # lw $r13, 16($r0)
  lw $t6, 20($zero) # lw $r14, 20($r0)
  nop
  nop
  nop
  nop
  # RIESGOS REGISTRO REGISTRO, SALTO EFECTIVO
  add $t3, $t1, $t2 # en r11 un 3 = 1 + 2
  add $t4, $t1, $t2 # en r12 un 3 = 1 + 2
  beq $t3, $t4, salto1 #salto efectivo
  lw $t3, 8($zero) # lw $r11, 8($r0)
  nop
  nop
  nop
  #SALTO NO EFECTIVO
salto1:
  add $t5, $t1, $t3 # en r13 un 4 = 1 + 3
  beq $t3, $t5, salto2 #salto no efectivo
  lw $t3, 8($zero) # lw $r11, 8($r0)
  nop
  #SALTO EFECTIVO
salto2:
  lw $t1, 4($zero) # en r9 un 2
  beq $t2, $t1, salto3 #salto efectivo
  add $t2, $t4, $t3 # en r10 un 7 = 3 + 4
  nop
  nop
  nop
  #SALTO NO EFECTIVO
salto3:
  lw $t6, 0($zero) # en r14 un 1
  beq $t2, $t6, salto4 #salto no efectivo
  add $t2, $t4, $t3 # en r10 un 7 = 3 + 4
salto4:
  nop
  nop
  nop