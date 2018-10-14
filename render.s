.export render
.export render_escape
.export render_win
.export render_mobs

.segment "ZEROPAGE"

.include "global.inc"

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
    lda #$00
    tax
    tay
; loop through x and y
y_repeat:
    cpy #max_height
    beq tiles_done
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
tiles_done:
    lda #$00
    sta $2007
    ; todo render hp
    ; todo render player level
    ; dlvl
    lda #$44
    sta $2007
    lda #$4C
    sta $2007
    lda #$56
    sta $2007
    lda #$4C
    sta $2007
    lda #$00
    sta $2007
    lda #$10
    clc
    adc dlevel
    sta $2007
render_done:
    ; tell PPU to render BG & sprites
    lda #%00011010 ; note: need second bit in order to show background on left side of screen
    sta $2001
    rts

; get tile index for x,y
; out: index in sprite sheet
; todo maybe we should render BG if sprite already on pos?
get_tile:
    ; todo then check item ??
check_stair:
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
player:
    lda #$A1
    rts


.endproc

.proc render_escape

    ; turn off rendering
    lda #%00000000 ; note: need second bit in order to show background on left side of screen
    sta $2001
    ; prep ppu for first nametable write
    lda #$20
    sta $2006
    lda #$00
    sta $2006
    ldx #$00 ; counter for background sprite position
    txa
    tay
    sta tmp
; clear line until middle of screen
render_escape_clear_y:
    cpy #$0F
    beq render_escape_message
render_escape_clear_x:
    lda #$00
    sta $2007
    inx
    cpx #$20
    bne render_escape_clear_x
    ldx #$00
    iny
    jmp render_escape_clear_y
render_escape_message:
    lda tmp
    bne render_escape_done
    ; You escaped!
    lda #$00
    sta $2007
    lda #$39 ; Y
    sta $2007
    lda #$4F ; o
    sta $2007
    lda #$55 ; u
    sta $2007
    lda #$00
    sta $2007
    lda #$45 ; e
    sta $2007
    lda #$53 ; s
    sta $2007
    lda #$43 ; c
    sta $2007
    lda #$41 ; a
    sta $2007
    lda #$50 ; p
    sta $2007
    lda #$45 ; e
    sta $2007
    lda #$44 ; d
    sta $2007
    lda #$01 ; !
    sta $2007
    ; done
    inc tmp
    lda #$00
    tax
    tay
    jsr render_escape_clear_y
render_escape_done:
    lda #%00001010 ; note: need second bit in order to show background on left side of screen
    sta $2001
    rts

.endproc

.proc render_win

    ; turn off rendering
    lda #%00000000 ; note: need second bit in order to show background on left side of screen
    sta $2001
    ; prep ppu for first nametable write
    lda #$20
    sta $2006
    lda #$00
    sta $2006
    ldx #$00 ; counter for background sprite position
    txa
    tay
    sta tmp
; clear line until middle of screen
render_win_clear_y:
    cpy #$0F
    beq render_win_message
render_win_clear_x:
    lda #$00
    sta $2007
    inx
    cpx #$20
    bne render_win_clear_x
    ldx #$00
    iny
    jmp render_win_clear_y
render_win_message:
    lda tmp
    bne render_win_done
    ; You escaped!
    lda #$00
    sta $2007
    lda #$39 ; Y
    sta $2007
    lda #$4F ; o
    sta $2007
    lda #$55 ; u
    sta $2007
    lda #$00
    sta $2007
    lda #$57 ; w
    sta $2007
    lda #$49 ; i
    sta $2007
    lda #$4E ; n
    sta $2007
    ; done
    inc tmp
    lda #$00
    tax
    tay
    jsr render_win_clear_y
render_win_done:
    lda #%00001010 ; note: need second bit in order to show background on left side of screen
    sta $2001
    rts

.endproc

.proc render_mobs

; render the player sprite
render_mobs:
    lda #0
    tay
    tax
render_mobs_loop:
    ; todo check is_alive, need to set hp for player first
    jsr moby
    asl
    asl
    asl
    clc
    adc #$04 ; sprite data is delayed by 1 scanline in NES
    sta $0200, x
    lda #$A1 ; todo plus type of mob
    sta $0201, x
    lda #%00000000
    sta $0202, x
    jsr mobx
    asl
    asl
    asl
    sta $0203, x
    ; todo continue loop, for now just do another mob
    txa
    clc
    adc #$04
    tax
    tya
    clc
    adc #mob_size
    tay
    jsr moby
    asl
    asl
    asl
    clc
    adc #$04 ; sprite data is delayed by 1 scanline in NES
    sta $0200, x
    lda #$A2
    sta $0201, x
    lda #%00000000
    sta $0202, x
    jsr mobx
    asl
    asl
    asl
    sta $0203, x

skip_mob:
    ; todo hide sprite
continue_mobs:
    ; todo
    ;inx
    ;cpx #maxmobs
    ;beq done_mobs

done_mobs:
    rts

.endproc

