; todo simplify - we shouldn't need render_str or render_num in here

.include "global.inc"

.export render
.export regenerate
.export render_escape
.export render_win
.export update_sprites

.segment "ZEROPAGE"

tmp: .byte 1

.segment "CODE"

; render string constant to screen
; in: address to start of str
; clobbers: x
.macro render_str str
    .local loop
    .local done
    ldx #0
loop:
    lda str, x
    beq done
    jsr get_str_tile
    sta $2007
    inx
    jmp loop
done:
.endmacro

.proc render

    lda nmis
wait_nmi:
    ; wait for nmi
    cmp nmis
    beq wait_nmi
generate_ppu:
    ; turn off rendering
    lda #%00000000 ; note: need second bit in order to show background on left side of screen
    sta $2001

    bit $2002
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
    beq render_status
x_repeat:
    stx xpos
    sty ypos
    jsr get_bg_tile
    sta $2007
    ldx xpos
    ldy ypos
    inx
    cpx #max_width
    bne x_repeat
    iny
    ldx #$00
    jmp y_repeat
    rts

; render status messages
render_status:
    ; hp
    bit $2002
    lda #$23
    sta $2006
    lda #$21
    sta $2006
    render_str txt_hp
    ; render hp via draw buffer
    jsr buffer_hp
    jsr render_buffer

    ; dlvl
    bit $2002
    lda #$23
    sta $2006
    lda #$61
    sta $2006
    render_str txt_dlvl
    ; render current dlevel
    lda #$00
    sta $2007
    lda dlevel
    jsr render_num

    lda nmis
render_done:
    cmp nmis
    beq render_done

    ; update scrolling
    bit $2002
    lda #$00
    sta $2005
    sta $2005

    ; tell PPU to render BG & sprites
    lda #%00011010 ; note: need second bit in order to show background on left side of screen
    sta $2001
    rts

.endproc

; re-generate next dungeon level
.proc regenerate
    lda nmis
    sta seed
    jsr generate
    ; render the dungeon
    jsr render
    rts
.endproc

.proc render_death

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
render_death_clear_y:
    cpy #$0F
    beq render_death_message
render_death_clear_x:
    lda #$00
    sta $2007
    inx
    cpx #$20
    bne render_death_clear_x
    ldx #$00
    iny
    jmp render_death_clear_y
render_death_message:
    lda tmp
    bne render_death_done
    ; You deathd!
    lda #$00
    sta $2007
    render_str txt_death
    ; done
    inc tmp
    lda #$00
    tax
    tay
    jsr render_death_clear_y
render_death_done:
    lda #%00001010 ; note: need second bit in order to show background on left side of screen
    sta $2001
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
    render_str txt_escape
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
    ; You win!
    lda #$00
    sta $2007
    render_str txt_win
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

.proc update_sprites

; render the player sprite
render_mobs:
    lda #0
    tay
    tax
render_mobs_loop:
    jsr is_alive
    bne clear_mob
    lda mobs + Mob::coords + Coord::ycoord, y
    asl
    asl
    asl
    clc
    adc #$07 ; +8 (skip first row), and -1 (sprite data delayed 1 scanline)
    sta $0200, x
    tya
    jsr get_mob_tile
    sta $0201, x
    lda #%00000000
    sta $0202, x
    lda mobs + Mob::coords + Coord::xcoord, y
    asl
    asl
    asl
    sta $0203, x
continue_mobs_loop:
    txa
    clc
    adc #$04
    tax
    tya
    clc
    adc #mob_size
    tay
    cmp #mobs_size
    bne render_mobs_loop

done_mobs:
    rts

clear_mob:
    ; set sprite x and y to off screen
    lda #$FF
    sta $0200, x
    sta $0203, x
    jmp continue_mobs_loop

.endproc

; render num 0-99
; in: number
; clobbers: x and y
render_num:
    cmp #10
    bcc render_ones
    ; first, render tens place for number
    ldx #0
tens_loop:
    cmp #10
    bcc render_tens
    sec
    sbc #10
    inx
    jmp tens_loop
render_tens:
    tay
    txa
    jsr get_num_tile
    sta $2007
    ; now, render ones place
    tya
render_ones:
    jsr get_num_tile
    sta $2007
    rts

.segment "RODATA"

; status
txt_hp:     .asciiz "hp"
txt_lvl:    .asciiz "lvl"
txt_dlvl:   .asciiz "dlvl"
; end messages
txt_win:    .asciiz "You win!"
txt_escape: .asciiz "You escaped!"
txt_death:  .asciiz "You died!"
