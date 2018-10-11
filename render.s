.include "global.inc"

.export render

.segment "CODE"

.proc render

generate_ppu:
    ; prep ppu for first nametable write
    lda #$20
    sta $2006
    lda #$00
    sta $2006
    ldx #$00 ; counter for background sprite position
bg_repeat:
    ldy #$00 ; counter for background bit index
    lda tiles, x
bg_bits:
    cpy #8
    beq next_bg
    iny
    asl
    bcs wall
    ; push accumulator to stack, draw floor, then pull from stack
    pha
    lda #$00
    sta $2007
    pla
    jmp bg_bits
wall:
    ; push accumulator to stack, draw wall, then pull from stack
    pha
    lda #$60
    sta $2007
    pla
    jmp bg_bits
next_bg:
    inx
    ; repeat until desired amount (first byte of sprite-set)
    cpx #$78
    bne bg_repeat
bgdone:
    ; tell PPU to render BG & sprites
    lda #%00011010 ; note: need second bit in order to show background on left side of screen
    sta $2001
    rts


.endproc
