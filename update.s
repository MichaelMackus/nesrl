; procedures relating to updating the buffer
;
; todo probably want to have a proc for updating previously seen tiles to another tile

.include "global.inc"

.export buffer_hp
.export buffer_tiles
.export buffer_messages
.export update_sprites

.segment "ZEROPAGE"

tmp:         .res 1
starty:      .res 1 ; for buffer seen loop
startx:      .res 1 ; for buffer seen loop
draw_y:      .res 1 ; current draw buffer index
last_dir:    .res 1 ; last scroll direction for bg scrolling
draw_length: .res 1
cur_tile:    .res 1 ; for drawing sprites

.segment "CODE"

; initialize buffers
.proc init_buffer
    ; set to up since by default the dungeon is generated in first NT
    lda #Direction::up
    sta last_dir
    lda #0
    sta draw_buffer
    sta scroll
    sta scroll+1
    sta base_nt
    sta ppu_addr+1
    lda #$20
    sta ppu_addr
    rts
.endproc

; todo update rest of code to work with new byte (vram increment flag)

; update draw buffer with new bg tiles
; this assumes scrolling in direction of player movement
;
; clobbers: all registers, xpos, and ypos
.proc buffer_tiles
    ; load player xpos and ypos
    lda mobs + Mob::coords + Coord::xcoord
    sta xpos
    lda mobs + Mob::coords + Coord::ycoord
    sta ypos

    jsr can_scroll_dir
    bne skip_buffer
    jmp start_buffer
skip_buffer:
    rts

start_buffer:
    ; update scroll metaxpos and metaypos depending on player dir
    jsr update_offsets
    lda xoffset
    sta metaxpos
    lda yoffset
    sta metaypos

    ; update ppu & scroll depending on player direction
    lda mobs + Mob::direction
    jsr update_ppuaddr

continue_buffer:
    ; get next y index
    jsr next_index

    ; write length to ppu
    lda mobs + Mob::direction
    cmp #Direction::right
    beq len_30
    cmp #Direction::left
    beq len_30
    ; going up or down, len = 32
    lda #32
    sta draw_length
    jmp buffer_start
len_30:
    lda #30
    sta draw_length

buffer_start:
    lda draw_length
    sta draw_buffer, y
    iny
    lda ppu_addr
    sta draw_buffer, y
    iny
    lda ppu_addr + 1
    sta draw_buffer, y
    iny
    ; write ppuctrl byte, updating increment depending on direction
    lda mobs + Mob::direction
    cmp #Direction::right
    beq inc_vertically
    cmp #Direction::left
    beq inc_vertically
    ; increment horizontally
    lda base_nt
    sta draw_buffer, y
    iny
    jmp buffer_tiles
inc_vertically:
    lda base_nt
    ora #%00000100 ; increment going down
    sta draw_buffer, y
    iny

buffer_tiles:
    ldx #$00
    stx cur_tile
buffer_tile_loop:
    sty draw_y
    ; get the tiles at the ppu_addr location
    jsr get_bg_metatile
    ldy draw_y
    sta draw_buffer, y
    iny
    ; increment xpos or ypos depending on player dir
    lda mobs + Mob::direction
    cmp #Direction::right
    beq inc_metay
    cmp #Direction::left
    beq inc_metay
    ; inc metax
    inc metaxpos
    jmp continue_loop
inc_metay:
    ; inc metay
    inc metaypos
    jmp continue_loop
continue_loop:
    inc cur_tile
    ldx cur_tile
    ; check draw length
    cpx draw_length
    beq done
    jmp buffer_tile_loop

done:
    ; write zero length for next buffer write
    lda #$00
    sta draw_buffer, y
    rts


.endproc

.proc buffer_hp
    jsr next_index
    ; length
    lda #$05 ; HP always 7 chars wide
    sta draw_buffer, y
    iny
    ; ppu addresses
    lda #$23
    sta draw_buffer, y
    iny
    lda #$25
    sta draw_buffer, y
    iny
    ; add leading space (for spacing up with other elements)
    lda mobs + Mob::hp
    cmp #10
    bcs tens
space:
    lda #$00
    sta draw_buffer, y
    iny
    lda mobs + Mob::hp
    ; buffer tens place
tens:
    jsr buffer_num
    ; add " / " for max HP, todo need slash char, for now using comma
    lda #$0C
    sta draw_buffer, y
    iny
    ; render max hp
    lda stats + PlayerStats::maxhp
    jsr buffer_num
    ; finish buffer
    lda #$00
    sta draw_buffer, y
    rts
.endproc

; buffer the messages to draw buffer
.proc buffer_messages
    message_ppu_offset = $20
    message_ppu_start  = $2C
    ldx #message_ppu_start
    txa
    pha ; remember ppu index for next iteration
    lda #0
    pha ; remember message index
write_message_header:
    ; store next draw buffer index into y
    jsr next_index
    ; write the message length
    lda #message_strlen
    sta draw_buffer, y
    iny
    ; write the PPU addr high byte
    lda #$23
    sta draw_buffer, y
    iny
    ; write the PPU addr low byte
    txa
    sta draw_buffer, y
    iny
write_message_str:
    pla
    tax
    ; update tmp_message using stack var
    txa
    sta tmp
    txa
    pha
    ldx tmp
    jsr update_message_str
    jsr buffer_str
    sta draw_length
    ; add damage/amount
    ldx tmp
    jsr buffer_amount
    ldx draw_length
fill_loop:
    cpx #message_strlen
    beq finish_buffer
    ; done, fill with blank spaces
    lda #$00
    sta draw_buffer, y
    inx
    iny
    jmp fill_loop
finish_buffer:
    ; store a length of zero at end, to ensure we can get next index
    lda #$00
    sta draw_buffer, y
continue_loop:
    pla
    clc
    adc #.sizeof(Message)
    tay

    ; end condition
    cmp #max_messages*.sizeof(Message)
    beq done

    ; increment ppu offset and add to stack
    pla
    clc
    adc #message_ppu_offset
    pha
    tax ; for next loop iteration

    tya
    pha
    jmp write_message_header
done:
    pla
    rts

; buffer amount to draw buffer
; increment x by amount tiles drawn
buffer_amount:
    jsr has_amount
    beq update_buffer_amount
    ; default condition
    rts
update_buffer_amount:
    ; buffer number to draw buffer
    lda messages+Message::amount, x
    jsr buffer_num
    clc
    adc draw_length
    sta draw_length
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


; increase or decrease ppuaddr depending on scroll dir
; todo check last_dir
; todo detect end of dungeon
;
; in: scroll dir
.proc update_ppuaddr
    cmp #Direction::right
    beq update_right
    cmp #Direction::left
    beq update_left
    cmp #Direction::down
    beq update_down
    ;cmp #Direction::up
    ;beq update_up
update_up:
    jsr scroll_up
    jsr dey_ppu
    rts
update_down:
    jsr scroll_down
    jsr iny_ppu
    rts
update_left:
    jsr scroll_left
    jsr dex_ppu
    rts
update_right:
    jsr scroll_right
    jsr inx_ppu
    rts
.endproc

; update metaxpos and metaypos depending on player dir for the bg tile
;
; in: scroll dir
.proc update_offsets
    cmp #Direction::right
    beq update_right
    cmp #Direction::left
    beq update_left
    cmp #Direction::down
    beq update_down
    ;cmp #Direction::up
    ;beq update_up
update_up:
    dec yoffset
    rts
update_down:
    inc yoffset
    rts
update_left:
    dec xoffset
    rts
update_right:
    inc xoffset
    rts
.endproc

; check mob dir to ensure we can scroll in that dir
;
; output: 0 if success
.proc can_scroll_dir
    lda mobs + Mob::direction
    cmp #Direction::right
    beq check_right
    cmp #Direction::left
    beq check_left
    cmp #Direction::down
    beq check_down
    ;cmp #Direction::up
    ;beq check_up
check_up:
check_down:
    jsr can_scroll_vertical
    rts
check_left:
check_right:
    jsr can_scroll_horizontal
    rts
.endproc

