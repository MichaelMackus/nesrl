; functions related to PPU scrolling

; in: dividend
; x: divisor
; out: remainder of modulus
.import mod

.export iny_ppu
.export dey_ppu
.export inx_ppu
.export dex_ppu

y_first_nt = $20
y_last_nt  = $28
x_first_nt = $20
x_last_nt  = $24

.segment "ZEROPAGE"

ppu_addr: .res 2

.segment "CODE"

; increment PPU address by 1 rows, handles wrapping to first NT addr
;
; x: low byte
; y: high byte
.proc iny_ppu
    stx ppu_addr
    sty ppu_addr+1
    lda ppu_addr+1
    cmp #$A0
    beq iny_ppu_high ; last row for low byte
    ; decrement low byte by one row (32 tiles)
    lda ppu_addr+1
    clc
    adc #$20
    sta ppu_addr+1
    ; done
    jmp done
done:
    ldx ppu_addr
    ldy ppu_addr + 1
    rts
.endproc

; decrement PPU address by 1 rows, handles wrapping to last NT addr
; updates x and y registers with new NT addr
;
; x: high byte
; y: low byte
.proc dey_ppu
    stx ppu_addr
    sty ppu_addr+1
    lda ppu_addr+1
    beq dey_ppu_high ; zero
    ; decrement low byte by one row (32 tiles)
    lda ppu_addr+1
    sec
    sbc #$20
    sta ppu_addr+1
    ; done
    jmp done
done:
    ldx ppu_addr
    ldy ppu_addr + 1
    rts
.endproc

.proc inx_ppu
    stx ppu_addr
    sty ppu_addr+1
    ; if remainder of division is #$1F (31), wrap to next NT
    lda ppu_addr+1
    ldx #$20
    jsr mod
    cmp #$1F
    beq inx_ppu_nt
    ; increment low byte by one row (32 tiles)
    inc ppu_addr+1
    ; done
done:
    ldx ppu_addr
    ldy ppu_addr + 1
    rts
.endproc
.proc dex_ppu
    stx ppu_addr
    sty ppu_addr+1
    ; if remainder of division is #$00, wrap to prev NT
    lda ppu_addr+1
    ldx #$20
    jsr mod
    cmp #$0
    beq dex_ppu_nt
    ; decrement low byte by one row (32 tiles)
    dec ppu_addr+1
    ; done
done:
    ldx ppu_addr
    ldy ppu_addr + 1
    rts
.endproc

; increment PPU high address by 1, updating address to next NT if appropriate
.proc iny_ppu_high
    ; handle nametable wrapping
    lda ppu_addr
    cmp #y_first_nt + 3
    beq wrap_last_nt
    cmp #y_last_nt + 3
    beq wrap_first_nt
    ; not start of first or start of last, increment by 1
    inc ppu_addr
    ; set low byte to first row
    jmp set_lowbyte
wrap_first_nt:
    lda #y_first_nt
    sta ppu_addr
    jmp set_lowbyte
wrap_last_nt:
    lda #y_last_nt
    sta ppu_addr
set_lowbyte:
    ; set low byte to $00, first row in NT
    lda #$00
    sta ppu_addr + 1
done:
    ; update x and y
    ldx ppu_addr
    ldy ppu_addr + 1
    rts
.endproc

; decrement PPU high address by 1, updating address to previous NT if appropriate
.proc dey_ppu_high
    ; handle nametable wrapping
    lda ppu_addr
    cmp #y_first_nt
    beq wrap_last_nt
    cmp #y_last_nt
    beq wrap_first_nt
    ; not start of first or start of last, decrement by 1
    dec ppu_addr
    ; set low byte to last row of prev addr
    lda #$E0
    sta ppu_addr + 1
    jmp done
wrap_first_nt:
    lda #y_first_nt + $03
    sta ppu_addr
    jmp wrap_prev_lowbyte
wrap_last_nt:
    lda #y_last_nt + $03
    sta ppu_addr
wrap_prev_lowbyte:
    ; set low byte to $80, last row in NT
    lda #$A0
    sta ppu_addr + 1
done:
    ; update x and y
    ldx ppu_addr
    ldy ppu_addr + 1
    rts
.endproc

; increment PPU nametable horizontally
.proc inx_ppu_nt
    ; handle nametable wrapping
    lda ppu_addr
    cmp #x_last_nt
    bcs dec_nt
    ; increment nametable
    clc
    adc #$04
    sta ppu_addr
    jmp set_lowbyte
dec_nt:
    sec
    sbc #$04
    sta ppu_addr
set_lowbyte:
    ; subtract $1F from low byte to go to start x of next NT
    lda ppu_addr + 1
    sec
    sbc #$1F
    sta ppu_addr + 1
done:
    ; update x and y
    ldx ppu_addr
    ldy ppu_addr + 1
    rts
.endproc

; decrement PPU nametable horizontally
.proc dex_ppu_nt
    ; handle nametable wrapping
    lda ppu_addr
    cmp #x_last_nt
    bcs dec_nt
    ; increment nametable
    clc
    adc #$04
    sta ppu_addr
    jmp set_lowbyte
dec_nt:
    sec
    sbc #$04
    sta ppu_addr
set_lowbyte:
    ; add $to from low byte to go to end x of next NT
    lda ppu_addr + 1
    clc
    adc #$1F
    sta ppu_addr + 1
done:
    ; update x and y
    ldx ppu_addr
    ldy ppu_addr + 1
    rts
.endproc

