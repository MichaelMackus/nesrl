; basic math functions

.export divide
.export iny_ppu
.export dey_ppu
.export inx_ppu
.export dex_ppu

.segment "ZEROPAGE"

tmp:      .res 1
ppu_addr: .res 2

.segment "CODE"

; divide x / y
;
; in: dividend
; x:  divisor
;
; out: remainder (mod)
; x:   result of division
.proc divide
    divisor  = tmp
    stx divisor
    ldx #0
loop:
    cmp divisor
    bcc done
    ; dividend - divisor
    sec
    sbc divisor
    inx
    jmp loop
done:
    rts
.endproc

y_first_nt = $20
y_last_nt  = $28
x_first_nt = $20
x_last_nt  = $24

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

; todo
.proc inx_ppu
.endproc
.proc dex_ppu
.endproc

; increment PPU high address by 1, wrapping to first PPU high address
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

; decrement PPU high address by 1, wrapping to first PPU high address
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
