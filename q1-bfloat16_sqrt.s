# ===== bfloat16 sqrt (RV32I) with automated tests =====
# Ripes syscalls: a7=4 print string, a7=11 putchar, a7=1 print int, a7=10 exit

    .text
    .globl _start

_start:
    # boot banner
    la   a0, msg_boot
    li   a7, 4
    ecall

    # -------------------------------
    # Test harness : N = 3 cases
    # -------------------------------
    la   s5, tv_in          # in base
    la   s6, tv_exp         # expected base
    li   s0, 3              # N
    li   s1, 0              # i
    li   s2, 0              # pass
    li   s3, 0              # fail

T_loop:
    beq  s1, s0, T_done

    slli a1, s1, 1          # offset = i*2 (bf16 = 16-bit)
    add  a2, s5, a1
    lhu  a0, 0(a2)          # a0 = in(bf16)
    jal  ra, bf16_sqrt
    mv   t6, a0             # keep out(bf16)

    add  a3, s6, a1
    lhu  a4, 0(a3)          # a4 = expected(bf16)
    bne  t6, a4, T_fail

T_pass:
    addi s2, s2, 1
    j    T_next

T_fail:
    addi s3, s3, 1
  

T_next:
    addi s1, s1, 1
    j    T_loop

T_done:
    # summary
    la   a0, msg_total
    li   a7, 4
    ecall
    mv   a0, s0
    li   a7, 1
    ecall
    la   a0, msg_nl
    li   a7, 4
    ecall

    la   a0, msg_pass
    li   a7, 4
    ecall
    mv   a0, s2
    li   a7, 1
    ecall
    la   a0, msg_nl
    li   a7, 4
    ecall

    la   a0, msg_fail
    li   a7, 4
    ecall
    mv   a0, s3
    li   a7, 1
    ecall
    la   a0, msg_nl
    li   a7, 4
    ecall

    li   a7, 10
    ecall

# -----------------------------------------------------
# bf16_sqrt(a0=bf16bits) -> a0=bf16bits (RV32I)
# -----------------------------------------------------
bf16_sqrt:
    srli  t0, a0, 15         # sign
    andi  t0, t0, 1
    srli  t1, a0, 7          # exp  (8-bit)
    andi  t1, t1, 0xFF
    andi  t2, a0, 0x7F       # mant (7-bit)

    # exp == 0xFF ?
    li    t3, 0xFF
    bne   t1, t3, BS_chk_zero
    bnez  t2, BS_ret_a0      # NaN -> return a0
    bnez  t0, BS_nan         # -Inf -> NaN
    j     BS_ret_a0          # +Inf -> return a0

BS_chk_zero:
    beqz  t1, BS_zero        # +/-0 or denorm -> 0
    bnez  t0, BS_nan         # negative -> NaN

    # normalized positive
    li    t4, 0x80
    or    t4, t4, t2         # m = 0x80|mant (128..255)

    li    t5, 127
    sub   t6, t1, t5         # e = exp - 127
    andi  a5, t6, 1          # odd?
    beqz  a5, BS_e_adj
    slli  t4, t4, 1
    addi  t6, t6, -1
BS_e_adj:
    srai  t6, t6, 1
    add   t6, t6, t5         # new_exp

    # n = m << 7   (scale so 128 represents 1.0)
    slli  t4, t4, 7

    # restoring integer sqrt on n, start bit = 1<<14
    li    t2, 0              # res
    li    a5, 16384          # bit = 1<<14

BS_isqrt_loop:
    beqz  a5, BS_isqrt_done
    add   a4, t2, a5         # trial = res + bit
    blt   t4, a4, BS_no_sub
    sub   t4, t4, a4         # n -= trial
    srli  t2, t2, 1
    add   t2, t2, a5         # res = (res>>1)+bit
    j     BS_next
BS_no_sub:
    srli  t2, t2, 1          # res >>= 1
BS_next:
    srli  a5, a5, 2          # bit >>= 2
    j     BS_isqrt_loop

BS_isqrt_done:
    andi  t2, t2, 0x7F       # mant 7-bit

    # exponent guard
    li    a4, 0xFF
    bge   t6, a4, BS_pos_inf
    blt   t6, x0, BS_zero
    beq   t6, x0, BS_zero

    slli  t6, t6, 7
    or    a0, t6, t2         # sign=0
    jalr  x0, ra, 0

BS_pos_inf:
    li    a0, 0x7F80         # +Inf
    jalr  x0, ra, 0
BS_zero:
    li    a0, 0x0000
    jalr  x0, ra, 0
BS_nan:
    li    a0, 0x7FC0         # quiet NaN
    jalr  x0, ra, 0
BS_ret_a0:
    jalr  x0, ra, 0

# -----------------------------------------------------
# (可保留；目前摘要模式沒用到)
print_hex16:
    mv    t0, a0
    li    a7, 11
    li    a0, 48         # '0'
    ecall
    li    a0, 120        # 'x'
    ecall
    li    t1, 4
    li    t2, 12
ph16_loop:
    srl   t3, t0, t2
    andi  t3, t3, 15
    li    t4, 10
    blt   t3, t4, ph16_dig
    addi  t3, t3, -10
    li    a0, 65         # 'A'
    add   a0, a0, t3
    ecall
    j     ph16_next
ph16_dig:
    li    a0, 48
    add   a0, a0, t3
    ecall
ph16_next:
    addi  t2, t2, -4
    addi  t1, t1, -1
    bne   t1, x0, ph16_loop
    jalr  x0, ra, 0

# ========================= Data =========================
    .data
    .align 4

# 三筆測試（bf16）
tv_in:   .2byte 0x4110, 0x4080, 0xBF80
tv_exp:  .2byte 0x4040, 0x4000, 0x7FC0

# 字串
msg_boot:  .asciz "boot\n"
msg_total: .asciz "total : "
msg_pass:  .asciz "pass  : "
msg_fail:  .asciz "fail  : "
msg_nl:    .asciz "\n"
