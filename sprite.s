.include "global.inc"

.export update_sprites

.segment "ZEROPAGE"

mob_tile:    .res 1
mob:         .res 1 ; current mob index

.segment "CODE"

; todo add case for >= 255 sprites, that way we can increase maxmobs
; todo add flicker for >= 8 sprites per scan line
.proc update_sprites
    ldx #$00

; sprite zero for split-scrolling
sprite_zero:
    lda #$18
    sta $0200, x
    lda #$0e
    sta $0201, x
    lda #$00
    sta $0202, x
    lda #$00
    sta $0203, x
    inx
    inx
    inx
    inx

render_mobs:
    lda #$00
    sta mob
render_mob:
    ; todo ensure we can see mob first, will need to clear OAM data after
    ;ldy mob
    ;jsr can_player_see
    ;bne next_mob
    ; get mob start tile
    jsr get_mob_tile
    sta mob_tile
    ldy #$00
render_mob_loop:
    ; update sprite y pos
    jsr get_mob_y
    sta $0200, x
set_mob_tile:
    lda mob_tile
    sta $0201, x
    jsr get_mob_attribute
    sta $0202, x
    ; update sprite x pos
    jsr get_mob_x
    sta $0203, x
    ; add 4 to sprite index
    txa
    clc
    adc #$04
    tax
    ; finish loop if we've rendered 4 tiles (16x16 sprite)
    iny
    cpy #4
    beq next_mob
continue_loop:
    ; increment mob tile
    cpy #2
    beq next_tile_row
    inc mob_tile
    jmp render_mob_loop
next_tile_row:
    ; increment to next row
    lda mob_tile
    clc
    adc #$F ; add 15 to get to next row
    sta mob_tile
    jmp render_mob_loop
next_mob:
    lda mob
    clc
    adc #mob_size
    sta mob
    cmp #mobs_size
    bne render_mob
    rts

.proc clear_mob
    ; dead - Y to 0, todo anything *but* zero doesn't work here...
    ldy a3
    lda #$00
    rts
.endproc

; getters for mob x & y based on screen pos
.proc get_mob_y
    sty a3
    ldy mob
    ; ensure mob is within screen bounds
    jsr can_player_see_mob
    bne clear_mob
    jsr is_alive
    beq adjust_mob_y
adjust_mob_y:
    lda mobs + Mob::direction, y
    ldy a3
    ; increment based on y value
    cmp #Direction::down
    beq adjust_mob_y_inverse
    cpy #2
    beq increase_y
    cpy #3
    beq increase_y
    ; get offset unchanged
    ldy mob
    jsr get_mob_yoffset
    ; restore original y
    ldy a3
    rts
increase_y:
    ; get offset
    ldy mob
    jsr get_mob_yoffset
    ; increase sprite row
    clc
    adc #$08
    ; restore original y
    ldy a3
    rts
adjust_mob_y_inverse:
    cpy #0
    beq increase_y
    cpy #1
    beq increase_y
    ; get offset unchanged
    ldy mob
    jsr get_mob_yoffset
    ; restore original y
    ldy a3
    rts
.endproc
.proc get_mob_x
    sty a3
    ldy mob
    ; ensure mob is within screen bounds
    jsr can_player_see_mob
    bne clear_mob
    jsr is_alive
    beq adjust_mob_x
    jmp clear_mob
adjust_mob_x:
    ; increment based on x value
    lda mobs + Mob::direction, y
    ldy a3
    cmp #Direction::left
    beq adjust_mob_x_inverse
    cpy #1
    beq increase_x
    cpy #3
    beq increase_x
    ; get offset unchanged
    ldy mob
    jsr get_mob_xoffset
    ; restore original y
    ldy a3
    rts
increase_x:
    ; get offset unchanged
    ldy mob
    jsr get_mob_xoffset
    ; increase sprite row
    clc
    adc #$08
    ; restore original y
    ldy a3
    rts
adjust_mob_x_inverse:
    cpy #0
    beq increase_x
    cpy #2
    beq increase_x
    ; get offset unchanged
    ldy mob
    jsr get_mob_xoffset
    ; restore original y
    ldy a3
    rts
.endproc

.proc get_mob_attribute
    sty a3
    ldy mob
    lda mobs + Mob::type, y
    cmp #Mobs::player
    beq normal
    cmp #Mobs::goblin
    beq green
    cmp #Mobs::orc
    beq dark
    cmp #Mobs::ogre
    beq dark
    ; dark + red
    lda #3
    sta a2
    jmp get_dir_attr
normal:
    lda #0
    sta a2
    jmp get_dir_attr
green:
    lda #1
    sta a2
    jmp get_dir_attr
dark:
    lda #2
    sta a2

get_dir_attr:
    ldy mob
    lda mobs + Mob::direction, y
    ldy a3
    cmp #Direction::up
    beq get_normal_attribute
    cmp #Direction::right
    beq get_normal_attribute
    cmp #Direction::down
    beq flip_vertical_attribute
    ; left - flip horizontal
    lda #%01000000
    ora a2
    rts
get_normal_attribute:
    lda #%00000000
    ora a2
    rts
flip_vertical_attribute:
    lda #%10000000
    ora a2
    rts
.endproc
.endproc

; display sprites on bottom of screen debugging current PPUADDR
; y = offset from DEBUG_Y
; x = offset from DEBUG_SPRITE
.proc debug
    DEBUG_Y = 200
    DEBUG_X = 210
    DEBUG_SPRITE = 100

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

; display sprites on bottom of screen debugging current player y
; y = offset from DEBUG_Y
; x = offset from DEBUG_SPRITE
.proc debug_ypos
    DEBUG_Y = 200
    DEBUG_X = 210
    DEBUG_SPRITE = 100

    tya
    clc
    adc #DEBUG_Y
    tay
    txa
    clc
    adc #DEBUG_SPRITE
    tax

    ; ppu high
    lda mobs + Mob::coords + Coord::ycoord
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
    ; multiply by 8 for pixels
    asl
    asl
    asl
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
    ; multiply by 8 for pixels
    asl
    asl
    asl
    ; offset for statusbar
    clc
    adc #8*4 - 2
    rts
.endproc

.proc can_player_see_mob
    ; don't clobber x and y
    tya
    pha
    txa
    pha

    lda mobs + Mob::coords + Coord::ycoord, y
    asl
    cmp yoffset
    bcc failure
    lda yoffset
    clc
    adc #screen_height
    sta a2
    lda mobs + Mob::coords + Coord::ycoord, y
    asl
    cmp a2
    bcs failure

    lda mobs + Mob::coords + Coord::xcoord, y
    asl
    cmp xoffset
    bcc failure
    lda xoffset
    clc
    adc #screen_width
    sta a2
    lda mobs + Mob::coords + Coord::xcoord, y
    asl
    cmp a2
    bcs failure

    ; ensure player has seen tile before displaying mob
    lda mobs + Mob::coords + Coord::xcoord, y
    sta xpos
    lda mobs + Mob::coords + Coord::ycoord, y
    sta ypos
    jsr was_seen
    bne failure
    ; check player line of sight
    ldy #0
    jsr line_of_sight
    bne failure

    ; success
    pla
    tax
    pla
    tay
    lda #0
    rts

failure:
    pla
    tax
    pla
    tay
    lda #1
    rts
.endproc

.segment "RODATA"

txt_hp: .asciiz "HP"
