; functions related to PPU scrolling
; todo scrolling functions currently assume scroll is always on 8 pixel boundary

; in: dividend
; x: divisor
; out: remainder of modulus
.import mod

.exportzp ppu_addr
.exportzp scroll
.exportzp base_nt
.export scroll_right
.export scroll_left
.export scroll_up
.export scroll_down
.export iny_ppu
.export dey_ppu
.export inx_ppu
.export dex_ppu

y_first_nt = $20
y_last_nt  = $28
x_first_nt = $20
x_last_nt  = $24

.segment "ZEROPAGE"

ppu_addr: .res 2 ; high byte, low byte
scroll:   .res 2 ; x, y
base_nt:  .res 1 ; mask for controller base NT bits

.segment "CODE"

; scroll right by 1 column
.proc scroll_right
    lda scroll
    clc
    adc #$08
    beq flip_page
    sta scroll
    rts
flip_page:
    ; flip the x page
    lda base_nt
    eor #%00000001
    sta base_nt
    ; set scroll to 8, simulating right scroll
    lda #8
    sta scroll
    rts
.endproc

; scroll left by 1 column
.proc scroll_left
    lda scroll
    sec
    sbc #$08
    bcc flip_page
    sta scroll
    rts
flip_page:
    ; flip the x page
    lda base_nt
    eor #%00000001
    sta base_nt
    ; set scroll to 256 - 8, simulating left scroll
    lda #256 - 8
    sta scroll
    rts
.endproc

; scroll up by 1 column
.proc scroll_up
    lda scroll + 1
    sec
    sbc #$08
    bcc flip_page
    sta scroll + 1
    rts
flip_page:
    ; flip the y page
    lda base_nt
    eor #%00000010
    sta base_nt
    ; set scroll to 240 - 8, simulating up scroll
    lda #240 - 8
    sta scroll + 1
    rts
.endproc

; scroll down by 1 column
.proc scroll_down
    lda scroll + 1
    clc
    adc #$08
    cmp #240
    bcs flip_page
    sta scroll + 1
    rts
flip_page:
    ; flip the y page
    lda base_nt
    eor #%00000010
    sta base_nt
    ; set scroll to 8, simulating down scroll
    lda #8
    sta scroll + 1
    rts
.endproc

; increment PPU address by 1 rows, handles wrapping to first NT addr
;
; x: low byte
; y: high byte
.proc iny_ppu
    lda ppu_addr+1
    cmp #$A0
    beq iny_ppu_high ; last row for low byte
    ; decrement low byte by one row (32 tiles)
    lda ppu_addr+1
    clc
    adc #$20
    sta ppu_addr+1
    ; done
    rts
.endproc

; decrement PPU address by 1 rows, handles wrapping to last NT addr
; updates x and y registers with new NT addr
;
; x: high byte
; y: low byte
.proc dey_ppu
    lda ppu_addr+1
    beq dey_ppu_high ; zero
    ; decrement low byte by one row (32 tiles)
    lda ppu_addr+1
    sec
    sbc #$20
    sta ppu_addr+1
    ; done
    rts
.endproc

; clobbers: x
.proc inx_ppu
    ; if remainder of division is #$1F (31), wrap to next NT
    lda ppu_addr+1
    ldx #$20
    jsr mod
    cmp #$1F
    beq inx_ppu_nt
    ; increment low byte by one row (32 tiles)
    inc ppu_addr+1
    ; done
    rts
.endproc

; clobbers: x
.proc dex_ppu
    ; if remainder of division is #$00, wrap to prev NT
    lda ppu_addr+1
    ldx #$20
    jsr mod
    cmp #$0
    beq dex_ppu_nt
    ; decrement low byte by one row (32 tiles)
    dec ppu_addr+1
    ; done
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
    ; done
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
    ; done
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
    ; done
    rts
.endproc

