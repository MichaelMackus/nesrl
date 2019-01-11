; procedures relating to updating the buffer
;
; todo probably want to have a proc for updating previously seen tiles to another tile
; todo update rest of code to work with new byte (vram increment flag)

.include "global.inc"

.export buffer_tiles
.export buffer_seen
.export buffer_messages

.segment "ZEROPAGE"

tmp:            .res 1
endy:           .res 1 ; for buffer seen loop
endx:           .res 1 ; for buffer seen loop
prevx:          .res 1 ; for buffer seen loop

; represents player sight distance (hardcoded for now)
sight_distance = 1

.segment "CODE"

; update draw buffer with new bg tiles
; this assumes scrolling in direction of player movement
;
; clobbers: all registers, xpos, and ypos
.proc buffer_tiles

    ; disable scrolling if we're at edge
    jsr can_scroll_dir
    beq start_scroll_buffer
    jmp start_seen_buffer

start_scroll_buffer:
    ; buffer leading edges
    jsr buffer_edges

    ; scroll twice
    ; todo scroll *after* buffer updated?
    jsr update_scroll
    jsr update_scroll

start_seen_buffer:
    jsr buffer_seen ; this is for tiles *on* screen not edges

    rts
.endproc

.proc buffer_edges
    ; initialize ppuaddr for buffering edge
    jsr init_ppuaddr

    ; clear leading edge(s) (assumes cannot be seen)
    jsr update_ppuaddr
    jsr buffer_edge
    jsr update_ppuaddr
    jsr buffer_edge
    ; reset ppuaddr to origin from buffering edge
    jsr reset_ppuaddr

    rts

buffer_edge:
    ; update scroll metaxpos and metaypos depending on player dir
    jsr update_coords

    ; get next y index
    jsr next_index
    sty buffer_start

    lda mobs + Mob::direction
    cmp #Direction::left
    beq len_30
    cmp #Direction::right
    beq len_30
    ; going up or down, len = 32
    lda #32
    jmp write_buffer
len_30:
    lda #30
write_buffer:
    sta draw_length
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
    sta ppu_ctrl
    iny
    jmp buffer_tiles
inc_vertically:
    lda base_nt
    ora #%00000100 ; increment going down
    sta draw_buffer, y
    sta ppu_ctrl
    iny

buffer_tiles:
    ; calculate the position in the PPU
    jsr calculate_ppu_pos

    ldx #$00
    stx cur_tile
buffer_tile_loop:
    sty draw_y

    ; update ppu page if at NT boundary
    jsr update_nt_boundary

    ; check if we can see or already seen tile
    lda metaxpos
    lsr
    sta xpos
    lda metaypos
    lsr
    sta ypos
    jsr can_player_see
    beq load_seen
    jsr was_seen
    beq load_seen
    ; can't see, load BG for now
    lda #$00
    jmp update_buffer
load_seen:
    jsr get_bg_metatile

update_buffer:
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
continue_loop:
    inc ppu_pos
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

; increase or decrease ppuaddr depending on scroll dir
;
; in: scroll dir
; clobbers: x register
.proc update_ppuaddr
    lda mobs + Mob::direction
    cmp #Direction::right
    beq update_right
    cmp #Direction::left
    beq update_left
    cmp #Direction::down
    beq update_down
    ;cmp #Direction::up
    ;beq update_up
update_up:
    jsr dey_ppu
    rts
update_down:
    jsr iny_ppu
    rts
update_left:
    jsr dex_ppu
    rts
update_right:
    jsr inx_ppu
    rts
.endproc

; todo not exactly working since player is moving in 16 pixel increments
; update metaxpos and metaypos depending on player dir for the bg tile
;
; in: scroll dir
.proc update_coords
    lda mobs + Mob::direction
    cmp #Direction::right
    beq update_right
    cmp #Direction::left
    beq update_left
    cmp #Direction::down
    beq update_down
    ;cmp #Direction::up
    ;beq update_up
update_up:
    jsr get_first_col
    sta metaxpos
    jsr get_first_row
    sta metaypos
    rts
update_down:
    jsr get_first_col
    sta metaxpos
    jsr get_last_row
    sta metaypos
    dec metaypos
    rts
update_left:
    jsr get_first_col
    sta metaxpos
    jsr get_first_row
    sta metaypos
    rts
update_right:
    jsr get_last_col
    sta metaxpos
    dec metaxpos
    jsr get_first_row
    sta metaypos
    rts
.endproc

; initialize the PPU address to point to start address for buffering
; assumes ppuaddr is pointing to origin
.proc init_ppuaddr
    ; flip nametable if going right or down
    lda mobs + Mob::direction
    cmp #Direction::right
    beq right_of_nt
    cmp #Direction::down
    beq bottom_of_nt
    ; origin works for going left or up
    rts
right_of_nt:
    ; flip nametable
    jsr inx_ppu_nt
    ; decrement x to get back to end of previous nametable
    jsr dex_ppu
    rts
bottom_of_nt:
    ; flip nametable
    jsr iny_ppu_nt
    ; decrement y to get back to end of previous nametable
    jsr dey_ppu
    rts
.endproc

; reset the PPU address to point to origin
.proc reset_ppuaddr
    ; first reset to origin of screen
    lda mobs + Mob::direction
    cmp #Direction::right
    beq reset_right
    cmp #Direction::down
    beq reset_down
    ; if we went left or up, we're already at origin of screen
    rts
reset_right:
    ; flip nametable
    jsr dex_ppu_nt
    ; increase x to get to origin
    jsr inx_ppu
    rts
reset_down:
    ; flip nametable
    jsr dey_ppu_nt
    ; increase y to get to origin
    jsr iny_ppu
    rts
.endproc
.endproc

; update draw buffer with seen bg tiles
;
; clobbers: all registers, xpos, and ypos
; todo bug when hitting max tiles - 5, introduced by 8473542e9c2809cd4f8fe2cdb76bfcfa8a54fc46
.proc buffer_seen
    ; remember original ppu pos
    lda ppu_addr
    pha
    lda ppu_addr + 1
    pha

    ; set start & end x/y pos
set_startx:
    lda mobs + Mob::coords + Coord::xcoord
    asl ; multiply by 2
    sec
    sbc #sight_distance*2
    bcc forcex
    sta metaxpos
    sta prevx
    jmp set_starty
forcex:
    lda #0
    sta metaxpos
set_starty:
    ; get starty
    lda mobs + Mob::coords + Coord::ycoord
    asl ; multiply by 2
    sec
    sbc #sight_distance*2
    bcc forcey
    sta metaypos
    jmp set_endx
forcey:
    lda #0
    sta metaypos
set_endx:
    lda metaxpos
    clc
    adc #(sight_distance*2 + 1)*2
    ; check within bounds
    cmp #max_width*2
    bcs force_endx
    sta endx
    jmp set_endy
force_endx:
    lda #max_width*2
    sta endx
set_endy:
    lda metaypos
    clc
    adc #(sight_distance*2 + 1)*2
    ; check within bounds
    cmp #max_height*2
    bcs force_endy
    sta endy
    jmp inx_ppu_start
force_endy:
    lda #max_height*2
    sta endy

    ; increment PPU X
inx_ppu_start:
    ldy xoffset
inx_ppu_loop:
    cpy metaxpos
    beq iny_ppu_start
    jsr inx_ppu
    iny
    jmp inx_ppu_loop

    ; increment PPU Y
iny_ppu_start:
    ldy yoffset
iny_ppu_loop:
    cpy metaypos
    beq loop_start
    jsr iny_ppu
    iny
    jmp iny_ppu_loop

loop_start:
    ; initialize draw_length
    lda #(sight_distance*2 + 1)*2 ; increment by 1 for player
    sta draw_length
    jsr next_index

loop:
    ; end when endy hit
    lda metaypos
    cmp endy
    bcc loop_start_buffer
    jmp done
loop_start_buffer:
    ; save buffer_start for NT boundary check
    sty buffer_start

    ; initialize cur_tile for NT boundary check
    lda #0
    sta cur_tile

    ; write draw buffer length of sight distance
    lda draw_length
    sta draw_buffer, y
    iny
    ; store ppu addr to buffer
    lda ppu_addr
    sta draw_buffer, y
    iny
    lda ppu_addr+1
    sta draw_buffer, y
    iny
    ; vram increment
    lda base_nt
    sta draw_buffer, y
    sta ppu_ctrl
    iny

    ; calculate the position in the PPU
    jsr calculate_ppu_pos

   ; now we're ready to draw tile data
tile_loop:
    sty draw_y

    ; update ppu page if at NT boundary
    jsr update_nt_boundary

    ; update xpos and ypos with meta pos
    lda metaxpos
    lsr
    sta xpos
    lda metaypos
    lsr
    sta ypos
    ; ensure xpos and ypos is valid
    jsr within_bounds
    bne tile_bg
    ; check if we can see
    jsr can_player_see
    beq draw_seen
    ; draw seen tile, if already seen
    jsr was_seen
    ; no tile was seen, draw bg
    bne tile_bg
draw_seen:
    ; update seen tile
    jsr update_seen
    ; success, draw tile
    jsr get_bg_metatile
    ldy draw_y
    sta draw_buffer, y
    iny
    jmp loop_nextx
tile_bg:
    ldy draw_y
    lda #$00
    sta draw_buffer, y
    iny

loop_nextx:
    inc metaxpos
    lda metaxpos
    cmp endx
    beq loop_donex
    ; increment cur_tile & ppu_pos (for NT boundary check)
    inc cur_tile
    inc ppu_pos
    ; redo loop
    jmp tile_loop

loop_donex:
    ; reset x
    lda prevx
    sta metaxpos
loop_next:
    ; store zero length at end
    lda #$00
    sta draw_buffer, y
    ; increment y pos
    inc metaypos
    ; increment PPU row
    jsr iny_ppu
    ; continue loop until batching finished
    jmp loop
 
done:
    ; reset ppu addr
    pla
    sta ppu_addr + 1
    pla
    sta ppu_addr
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

; update scroll amount
;
; in: scroll dir
; clobbers: x register
.proc update_scroll
    lda mobs + Mob::direction
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
    rts
update_down:
    jsr scroll_down
    rts
update_left:
    jsr scroll_left
    rts
update_right:
    jsr scroll_right
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
    lda mobs + Mob::coords + Coord::ycoord
    asl
    ; ensure we're not at top of dungeon
    cmp #vertical_bound
    bcc failure
    ; edge case for walking up from bottom of dungeon
    cmp #(max_height*2) - (screen_height-vertical_bound)
    bcs failure
    jmp success
check_down:
    lda mobs + Mob::coords + Coord::ycoord
    asl
    ; edge case for walking down from top of dungeon
    cmp #vertical_bound
    beq failure ; edge case for going down
    bcc failure
    ; ensure we're not at bottom of dungeon
    cmp #(max_height*2) - (screen_height-vertical_bound)
    beq success;  edge case for going down
    bcs failure
    jmp success

check_left:
    lda mobs + Mob::coords + Coord::xcoord
    asl
    ; ensure we're not at top of dungeon
    cmp #horizontal_bound
    bcc failure
    ; edge case for walking left from right of dungeon
    cmp #(max_width*2) - (screen_width-horizontal_bound)
    bcs failure
    jmp success
check_right:
    lda mobs + Mob::coords + Coord::xcoord
    asl
    ; edge case for walking right from left of dungeon
    cmp #horizontal_bound
    beq failure ; edge case for going right
    bcc failure
    ; ensure we're not at end of dungeon
    cmp #(max_width*2) - (screen_width-horizontal_bound)
    beq success;  edge case for going right
    bcs failure
    jmp success

failure:
    lda #1
    rts
success:
    lda #0
    rts
.endproc

