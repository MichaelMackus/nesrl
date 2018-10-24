.include "global.inc"

.export update_sprite_offsets
.export update_sprites

.segment "ZEROPAGE"

cur_tile:    .res 1 ; for drawing sprites
tmp:         .res 1

xoffset:     .res 1
yoffset:     .res 1

.segment "CODE"

; initialize xoffset and yoffset
.proc update_sprite_offsets
    jsr get_first_col
    sta xoffset
    jsr get_first_row
    sta yoffset
    rts
.endproc

.proc update_sprites
; render the player in the center of the screen, unless there are no
; more tiles in that direction
render_player:
    lda #0
    jsr get_mob_tile
    sta cur_tile
    ldx #$00
    ldy #$00
render_player_loop:
    ; update sprite y pos
    jsr get_player_y
    sta $0200, x
set_player_tile:
    lda cur_tile
    sta $0201, x
    jsr get_dir_attribute
    sta $0202, x
    ; update sprite x pos
    jsr get_player_x
    sta $0203, x
    ; continue loop
    iny
    cpy #4
    bne continue_loop ; done
    jmp render_mobs
continue_loop:
    txa
    clc
    adc #$04
    tax
    ; increment mob tile
    cpy #2
    beq next_tile_row
    inc cur_tile
    jmp render_player_loop
next_tile_row:
    ; increment to next row
    lda cur_tile
    clc
    adc #$F ; add 15 to get to next row
    sta cur_tile
    jmp render_player_loop

; getters for mob x & y based on screen pos
get_player_y:
    sty tmp
    ldy #0
    jsr get_mob_yoffset
    ; multiply by 8 for pixels
    asl
    asl
    asl
    ; need y for adjustments
    ldy tmp
adjust_player_y:
    ; increment based on y value
    pha
    lda mobs + Mob::direction
    cmp #Direction::down
    beq adjust_player_y_inverse
    pla
    cpy #2
    beq increase_y
    cpy #3
    beq increase_y
    rts
increase_y:
    ; increase sprite row
    clc
    adc #$08
    rts
adjust_player_y_inverse:
    pla
    cpy #0
    beq increase_y
    cpy #1
    beq increase_y
    rts
get_player_x:
    sty tmp
    ldy #0
    jsr get_mob_xoffset
    ; multiply by 8 for pixels
    asl
    asl
    asl
    ; need y for adjustments
    ldy tmp
adjust_player_x:
    ; increment based on x value
    pha
    lda mobs + Mob::direction
    cmp #Direction::left
    beq adjust_player_x_inverse
    pla
    cpy #1
    beq increase_x
    cpy #3
    beq increase_x
    rts
increase_x:
    ; increase sprite row
    clc
    adc #$08
    rts
adjust_player_x_inverse:
    pla
    cpy #0
    beq increase_x
    cpy #2
    beq increase_x
    rts

get_dir_attribute:
    lda mobs + Mob::direction
    cmp #Direction::up
    beq get_normal_attribute
    cmp #Direction::right
    beq get_normal_attribute
    cmp #Direction::down
    beq flip_vertical_attribute
    ; left - flip horizontal
    lda #%01000000
    rts
get_normal_attribute:
    lda #%00000000
    rts
flip_vertical_attribute:
    lda #%10000000
    rts

render_mobs:
    rts ; todo remove
    ldx #4
    ldy #mob_size
render_mobs_loop:
    jsr is_alive
    bne clear_mob
    lda mobs + Mob::coords + Coord::xcoord, y
    sta xpos
    lda mobs + Mob::coords + Coord::ycoord, y
    sta ypos
    ; check if we can see mob
    tya
    pha
    txa
    pha
    ldy #0
    jsr can_see
    beq render_mob
    pla
    tax
    pla
    tay
    ; nope, hide mob
    jmp clear_mob
render_mob:
    pla
    tax
    pla
    tay
    ; todo multiply x & y by 2 in order to get metax
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

; display sprites on bottom of screen debugging current PPUADDR
; y = offset from DEBUG_Y
; x = offset from DEBUG_SPRITE
.proc debug
    DEBUG_Y = 200
    DEBUG_X = 210
    DEBUG_SPRITE = 60

    tya
    clc
    adc #DEBUG_Y
    tay
    txa
    clc
    adc #DEBUG_SPRITE
    tax

    ; ppu high
    lda ppu_addr
    ; get high place tile
    lsr
    lsr
    lsr
    lsr
    jsr get_hex_tile
    ; update sprite
    sta $0201, x
    tya
    sta $0200, x
    lda #0
    sta $0202, x
    lda #DEBUG_X
    sta $0203, x
    inx
    inx
    inx
    inx
    ; ppu high
    lda ppu_addr
    ; get low place tile
    and #%00001111
    jsr get_hex_tile
    ; update sprite
    sta $0201, x
    tya
    sta $0200, x
    lda #0
    sta $0202, x
    lda #DEBUG_X + 8
    sta $0203, x
    inx
    inx
    inx
    inx
    ; ppu high
    lda ppu_addr + 1
    ; get high place tile
    lsr
    lsr
    lsr
    lsr
    jsr get_hex_tile
    ; update sprite
    sta $0201, x
    tya
    sta $0200, x
    lda #0
    sta $0202, x
    lda #DEBUG_X + 16
    sta $0203, x
    inx
    inx
    inx
    inx
    ; ppu high
    lda ppu_addr + 1
    ; get low place tile
    and #%00001111
    jsr get_hex_tile
    ; update sprite
    sta $0201, x
    tya
    sta $0200, x
    lda #0
    sta $0202, x
    lda #DEBUG_X + 24
    sta $0203, x
    inx
    inx
    inx
    inx

    rts
.endproc


; get mob offset from left edge
;
; y: mob index to calculate
.proc get_mob_xoffset
; calculate offset based on xpos & screen_width
get_offset_xpos:
    lda mobs + Mob::coords + Coord::xcoord, y
    asl ; multiply by 2
    sec
    sbc xoffset
    rts
.endproc

; get mob offset from top edge
;
; y: mob index to calculate
.proc get_mob_yoffset
; calculate offset based on xpos & screen_width
get_offset_ypos:
    lda mobs + Mob::coords + Coord::ycoord, y
    asl ; multiply by 2
    sec
    sbc yoffset
    rts
.endproc

