.include "global.inc"

.export render

.segment "CODE"

.proc render

max_width  = 32
max_height = 24

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
    lda #$00
    tax
    tay
; loop through x and y
y_repeat:
    cpy #max_height
    beq bgdone
x_repeat:
    stx xpos
    sty ypos
    jsr get_tile
    sta $2007
    ldx xpos
    ldy ypos
    inx
    cpx #max_width
    bne x_repeat
    iny
    ldx #$00
    jmp y_repeat
bgdone:
    ; tell PPU to render BG & sprites
    lda #%00011010 ; note: need second bit in order to show background on left side of screen
    sta $2001
    rts

; get tile index for x,y
; out: index in sprite sheet
get_tile:
    ; todo first check mob
    ; todo then check item
    ; then check stair
    cpx up_x
    bne check_downstair
    cpy up_y
    beq up
check_downstair:
    cpx down_x
    bne tile
    cpy down_y
    beq down
tile:
    ; finally, display tile
    jsr get_byte_offset
    tay
    jsr get_byte_mask
    and tiles, y
    bne floor
bg:
    lda #$00
    rts
floor:
    lda #$82
    rts
up:
    lda #$3E
    rts
down:
    lda #$3F
    rts

.endproc
