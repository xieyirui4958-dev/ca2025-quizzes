.text
.globl _start

_start:
    # ---------------------------------------
    # Loop 3 test cases in test_vec[]
    # ---------------------------------------
    la   s0, test_vec        # base of tests
    li   s1, 3               # N = 3
    li   s2, 0               # i = 0

T_loop:
    beq  s2, s1, T_done

    # a0 = test_vec[i]
    slli t3, s2, 2
    add  t0, s0, t3
    lw   a0, 0(t0)

    # 把 input 存到變數 (沿用原本的列印流程)
    la   t4, input_val
    sw   a0, 0(t4)

    # ---- encode ----
    add  a1, x0, x0          # !! 先把 a1 清成 0 (overflow 累計從 0 開始)
    jal  ra, uf8_encode_v1   # a0 = code (8-bit)
    la   t1, out_code
    sw   a0, 0(t1)

    # ---- decode ----
    andi a0, a0, 255
    jal  ra, uf8_decode      # a0 = decoded value
    la   t2, out_value
    sw   a0, 0(t2)

    # ===== print =====

    # input
    la   a0, msg_in
    li   a7, 4
    ecall
    la   t0, input_val
    lw   a0, 0(t0)
    li   a7, 1
    ecall
    la   a0, msg_hexopen
    li   a7, 4
    ecall
    lw   a0, 0(t0)
    jal  ra, print_hex32
    la   a0, msg_hexclose
    li   a7, 4
    ecall

    # code
    la   a0, msg_code
    li   a7, 4
    ecall
    la   t0, out_code
    lw   a0, 0(t0)
    li   a7, 1
    ecall
    la   a0, msg_hexopen
    li   a7, 4
    ecall
    lw   a0, 0(t0)
    jal  ra, print_hex32
    la   a0, msg_hexclose
    li   a7, 4
    ecall

    # value
    la   a0, msg_val
    li   a7, 4
    ecall
    la   t0, out_value
    lw   a0, 0(t0)
    li   a7, 1
    ecall
    la   a0, msg_hexopen
    li   a7, 4
    ecall
    lw   a0, 0(t0)
    jal  ra, print_hex32
    la   a0, msg_hexclose
    li   a7, 4
    ecall

    # 空一行分隔各測試
    la   a0, msg_nl
    li   a7, 4
    ecall

    addi s2, s2, 1
    j    T_loop

T_done:
halt:
    jal  x0, halt

# ---------------- uf8_decode(b) ----------------
# a0=b -> a0=(m<<e)+((2^e-1)<<4),  e=b>>4, m=b&0xF
uf8_decode:
    andi    t0, a0, 15
    srli    t1, a0, 4
    beq     t1, x0, Ldec_e0
    li      t2, 1
    sll     t2, t2, t1
    addi    t2, t2, -1
    slli    t2, t2, 4
    sll     t3, t0, t1
    add     a0, t3, t2
    jalr    x0, ra, 0
Ldec_e0:
    add     a0, t0, x0
    jalr    x0, ra, 0

# ---------------- msb_index32(x) ----------------
msb_index32:
    li      t0, 0
    add     t1, a0, x0
    srli    t2, t1, 16
    beq     t2, x0, Lmsb_8
    addi    t0, t0, 16
    add     t1, t2, x0
Lmsb_8:
    li      t3, 256
    sltu    t4, t1, t3
    bne     t4, x0, Lmsb_4
    addi    t0, t0, 8
    srli    t1, t1, 8
Lmsb_4:
    li      t3, 16
    sltu    t4, t1, t3
    bne     t4, x0, Lmsb_2
    addi    t0, t0, 4
    srli    t1, t1, 4
Lmsb_2:
    li      t3, 4
    sltu    t4, t1, t3
    bne     t4, x0, Lmsb_1
    addi    t0, t0, 2
    srli    t1, t1, 2
Lmsb_1:
    li      t3, 2
    sltu    t4, t1, t3
    bne     t4, x0, Lmsb_end
    addi    t0, t0, 1
    srli    t1, t1, 1
Lmsb_end:
    add     a0, t0, t1
    jalr    x0, ra, 0

# ---------------- uf8_encode_v1(value) ----------------
uf8_encode_v1:
    li      t0, 16
    blt     a0, t0, Lret_small_v1

    li      t1, 0               # e = 0
    # 這裡的 overflow 放在 a1；呼叫前務必把 a1 清 0
Lv1_loop:
    slli    t3, a1, 1
    addi    t3, t3, 16          # next_overflow = (overflow<<1)+16
    blt     a0, t3, Lv1_done
    add     a1, t3, x0          # overflow = next_overflow
    addi    t1, t1, 1           # e++
    li      t4, 15
    blt     t1, t4, Lv1_loop

Lv1_done:
    sub     t4, a0, a1
    srl     t4, t4, t1          # mantissa
    slli    a0, t1, 4           # (e<<4)|m
    or      a0, a0, t4
    jalr    x0, ra, 0

Lret_small_v1:
    add     a0, a0, x0
    jalr    x0, ra, 0

# ---------------- print_hex32(a0=value) ----------------
print_hex32:
    add     t0, a0, x0
    li      a7, 11               # putchar

    li      a0, 48               # '0'
    ecall
    li      a0, 120              # 'x'
    ecall

    li      t1, 8
    li      t2, 28
ph_loop:
    srl     t3, t0, t2
    andi    t3, t3, 15
    li      t4, 10
    blt     t3, t4, ph_digit
    addi    t3, t3, -10
    li      a0, 65
    add     a0, a0, t3
    ecall
    jal     x0, ph_next
ph_digit:
    li      a0, 48
    add     a0, a0, t3
    ecall
ph_next:
    addi    t2, t2, -4
    addi    t1, t1, -1
    bne     t1, x0, ph_loop
    jalr    x0, ra, 0

# ---------------- Data ----------------
.data

# 三筆測試資料（可自行更換）
test_vec:    .word 12, 256, 12345

input_val:   .word 0
out_code:    .word 0
out_value:   .word 0

# "input:  "
msg_in:      .word 0x75706E69, 0x20203A74, 0x00000000
# "code:   "
msg_code:    .word 0x65646F63, 0x2020203A, 0x00000000
# "value:  "
msg_val:     .word 0x756C6176, 0x20203A65, 0x00000000
# " (0x"
msg_hexopen: .word 0x78302820, 0x00000000
# ")\n"
msg_hexclose:.word 0x00000A29
# "\n"
msg_nl:      .word 0x0000000A
