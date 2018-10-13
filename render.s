.include "global.inc"

.export render

.segment "CODE"

.proc render

generate_ppu:
    ; turn off rendering
    lda #%00000000 ; note: need second bit in order to show background on left side of screen
    sta $2001
    ; prep ppu for first nametable write
    lda #$20
    sta $2006
    lda #$00
    sta $2006
    ldx #$00 ; counter for background sprite position
; clear first line (not renderable)
clear_line:
    lda #$00
    sta $2007
    inx
    cpx #$20
    bne clear_line
    ldx #$00
bg_repeat:
    ldy #$00 ; counter for background bit index
    lda tiles, x
bg_bits:
    cpy #8
    beq next_bg
    iny
    asl
    bcs floor
    ; push accumulator to stack, draw bg, then pull from stack
    pha
    lda #$00
    sta $2007
    pla
    jmp bg_bits
floor:
    ; push accumulator to stack, draw floor, then pull from stack
    pha
    lda #$82
    sta $2007
    pla
    jmp bg_bits
next_bg:
    inx
    ; repeat until desired amount (first byte of sprite-set)
    ; todo sometimes rendering weird tile to bottom right...
    ; todo perhaps try turning of sprites to see where its coming from?
    cpx #96
    bne bg_repeat
    ; fill the rest of the tiles to BG for now
    ldy #0

    lda #$00
    tax
    tay
    sta $2007
    lda xpos
count_xpos_tens:
    cmp #10
    bcc write_xpos
    ; increment tens place and subtract 10 from xpos
    sec
    sbc #10
    iny
    jmp count_xpos_tens
write_xpos:
    tax
    tya
    sta tmp
    lda #$10
    clc
    adc tmp
    sta $2007
    txa
    sta tmp
    lda #$10
    clc
    adc tmp
    sta $2007

    lda #$00
    tax
    tay
    sta $2007
    lda ypos
count_ypos_tens:
    cmp #10
    bcc write_ypos
    ; increment tens place and subtract 10 from xpos
    sec
    sbc #10
    iny
    jmp count_ypos_tens
write_ypos:
    tax
    tya
    sta tmp
    lda #$10
    clc
    adc tmp
    sta $2007
    txa
    sta tmp
    lda #$10
    clc
    adc tmp
    sta $2007


;fill_bg:
;    lda #$00
;    sta $2007
;    inx
;    cpx #00
;    bne fill_bg
;    ; reset x & increment y
;    ldx #0
;    iny
;    cpy #3
;    beq last_page
;    bcc bgdone ; greater than 3, we're done
;    jmp fill_bg
;last_page:
;    ldx #64
;    jmp fill_bg

bgdone:

    ; tell PPU to render BG & sprites
    lda #%00011010 ; note: need second bit in order to show background on left side of screen
    sta $2001
    rts


.endproc
