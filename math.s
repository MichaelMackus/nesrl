; basic math functions

.export divide
.export inc_ppu
.export dec_ppu

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

; PPU increment & decrement setup, todo handle incy and incx
first_nt = $20
last_nt  = $28

; increment PPU address by 2 rows, handles wrapping to first NT addr
;
; x: low byte
; y: high byte
.proc inc_ppu
.endproc

; decrement PPU address by 2 rows, handles wrapping to last NT addr
; updates x and y registers with new NT addr
;
; x: high byte
; y: low byte
.proc dec_ppu
    stx ppu_addr
    sty ppu_addr+1
    lda ppu_addr+1
    beq dec_ppu_high ; zero
    ; decrement low byte by one row (32 tiles)
    lda ppu_addr+1
    sec
    sbc #$40
    sta ppu_addr+1
    ; done
    jmp done
done:
    ldx ppu_addr
    ldy ppu_addr + 1
    rts
.endproc

; increment PPU high address by 1, wrapping to first PPU high address
.proc inc_ppu_high
.endproc

; increment PPU low address by 2 rows, wrapping to 00 on end of NT
.proc inc_ppu_low
.endproc

; decrement PPU high address by 1, wrapping to first PPU high address
.proc dec_ppu_high
    ; handle nametable wrapping
    lda ppu_addr
    cmp #first_nt
    beq wrap_last_nt
    cmp #last_nt
    beq wrap_prev_nt
    ; not start of first or start of last, decrement by 1
    dec ppu_addr
    ; set low byte to last row of prev addr
    lda #$C0
    sta ppu_addr + 1
    jmp done
wrap_prev_nt:
    lda #first_nt + $03
    sta ppu_addr
    jmp wrap_prev_lowbyte
wrap_last_nt:
    lda #last_nt + $03
    sta ppu_addr
wrap_prev_lowbyte:
    ; set low byte to $80, last row in NT
    lda #$80
    sta ppu_addr + 1
done:
    ; update x and y
    ldx ppu_addr
    ldy ppu_addr + 1
    rts
.endproc

; decrement PPU low address by 2 rows, wrapping to 00 on end of NT
.proc dec_ppu_low
.endproc
