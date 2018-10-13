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
    cpx #96
    bne bg_repeat
    ; fill the rest of the tiles to BG for now
    ldy #0

    lda #$00
    tax
    tay
    sta $2007

bgdone:
    ; tell PPU to render BG & sprites
    lda #%00011010 ; note: need second bit in order to show background on left side of screen
    sta $2001
    rts


.endproc
