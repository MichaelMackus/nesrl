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
dec_ppu_high:
    ; handle nametable wrapping
    ; if high byte divisible by 4, wrap to end of prev NT
    lda ppu_addr
    ldx #4
    jsr divide
    beq wrap_prev_nt
    ; not divisible by 4 - decrement high byte & set low byte
    dec ppu_addr
    ; set low byte to last row of prev addr
    lda #$C0
    sta ppu_addr + 1
    ; done
    jmp done
wrap_prev_nt:
    ; if first nametable, wrap to last NT
    lda #$20
    cmp ppu_addr
    beq wrap_last_nt
    ; otherwise, subtract 4 from high byte
    lda ppu_addr
    sec
    sbc #$04
    sta ppu_addr
    jmp wrap_prev_lowbyte
wrap_last_nt:
    lda #$2F
    sta ppu_addr
wrap_prev_lowbyte:
    ; set low byte to $A0, last row in NT
    lda #$80
    sta ppu_addr + 1
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
.endproc

; decrement PPU low address by 2 rows, wrapping to 00 on end of NT
.proc dec_ppu_low
.endproc
