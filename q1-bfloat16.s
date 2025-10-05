# ===== bfloat16 demo with automated tests =====
# f32bits -> bf16bits -> f32bits, verify and summarize

.text
.globl _start

_start:
    # boot banner: 確認 console OK
    li   s0, 3        # N: 測試總筆數
    li   s1, 0        # i: 目前索引
    li   s2, 0        # pass 計數
    li   s3, 0        # fail 計數

    la   a0, msg_boot
    li   a7, 4
    ecall

    # -----------------------------------------------------
    # Test harness
    # -----------------------------------------------------
    la   t0, test_vec
    li   t1, 3                  # 三筆測資
    la   t3, out_bf16_arr
    la   t4, out_f32_arr

    li   t2, 0                  # i
    li   t5, 0                  # pass
    li   t6, 0                  # fail

T_loop:
    beq  s1, s0, T_done

    slli a1, s1, 2
    add  a2, t0, a1
    lw   a0, 0(a2)

    # ... encode/decode 比較 ...

T_pass:
    addi s2, s2, 1
    j    T_next

T_fail:
    addi s3, s3, 1
    # （後面印錯誤細節的程式碼不變）

T_next:
    addi s1, s1, 1
    j    T_loop

T_done:
    # print summary
    la   a0, msg_sum_total
    li   a7, 4
    ecall
    add  a0, s0, x0         # total（你用 s0/s2/s3 當計數器）
    li   a7, 1
    ecall
    la   a0, msg_nl
    li   a7, 4
    ecall

    la   a0, msg_sum_pass
    li   a7, 4
    ecall
    add  a0, s2, x0         # pass
    li   a7, 1
    ecall
    la   a0, msg_nl
    li   a7, 4
    ecall

    la   a0, msg_sum_fail
    li   a7, 4
    ecall
    add  a0, s3, x0         # fail
    li   a7, 1
    ecall
    la   a0, msg_nl
    li   a7, 4
    ecall

    # 真的結束（只印一次）
    li   a7, 10
    ecall

halt:                       # 保險：若 exit 未被處理就自旋
    j    halt


# --- functions (與你原本相同) ---
f32_to_bf16:
    add    t0, a0, x0
    srli   t1, a0, 23
    andi   t1, t1, 255
    li     t2, 255
    beq    t1, t2, FTBN_inf
    srli   t3, t0, 16
    andi   t3, t3, 1
    add    a0, t0, t3
    li     t4, 0x7FFF
    add    a0, a0, t4
    srli   a0, a0, 16
    jalr   x0, ra, 0
FTBN_inf:
    srli   a0, t0, 16
    jalr   x0, ra, 0

bf16_to_f32:
    slli   a0, a0, 16
    jalr   x0, ra, 0

print_hex32:
    add    t0, a0, x0
    li     a7, 11
    li     a0, 48               # '0'
    ecall
    li     a0, 120              # 'x'
    ecall
    li     t1, 8
    li     t2, 28
ph32_loop:
    srl    t3, t0, t2
    andi   t3, t3, 15
    li     t4, 10
    blt    t3, t4, ph32_dig
    addi   t3, t3, -10
    li     a0, 65               # 'A'
    add    a0, a0, t3
    ecall
    j      ph32_next
ph32_dig:
    li     a0, 48
    add    a0, a0, t3
    ecall
ph32_next:
    addi   t2, t2, -4
    addi   t1, t1, -1
    bne    t1, x0, ph32_loop
    jalr   x0, ra, 0

print_hex16:
    add    t0, a0, x0
    li     a7, 11
    li     a0, 48
    ecall
    li     a0, 120
    ecall
    li     t1, 4
    li     t2, 12
ph16_loop:
    srl    t3, t0, t2
    andi   t3, t3, 15
    li     t4, 10
    blt    t3, t4, ph16_dig
    addi   t3, t3, -10
    li     a0, 65
    add    a0, a0, t3
    ecall
    j      ph16_next
ph16_dig:
    li     a0, 48
    add    a0, a0, t3
    ecall
ph16_next:
    addi   t2, t2, -4
    addi   t1, t1, -1
    bne    t1, x0, ph16_loop
    jalr   x0, ra, 0

# ========================= Data =========================
.data
.align 4

# 三筆測試
test_vec:
    .word 0x4048F5C3      # 3.14f
    .word 0x00000000      # 0.0f
    .word 0xC0200000      # -2.5f

# 輸出緩衝
.align 4
out_bf16_arr: .word 0, 0, 0
.align 4
out_f32_arr:  .word 0, 0, 0

# 訊息
msg_boot:       .asciz "boot\n"
msg_fail:       .asciz "FAIL: "
msg_in:         .asciz "in f32 : "
msg_bf16:       .asciz "bf16   : "
msg_out:        .asciz "out f32: "
msg_exp:        .asciz "expect : "
msg_sum_total:  .asciz "total : "
msg_sum_pass:   .asciz "pass  : "
msg_sum_fail:   .asciz "fail  : "
msg_nl:         .asciz "\n"
msg_dblnl:      .asciz "\n\n"
