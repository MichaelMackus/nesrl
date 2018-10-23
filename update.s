; procedures relating to updating the buffer
;
; todo probably want to have a proc for updating previously seen tiles to another tile

.include "global.inc"

.export buffer_hp
.export buffer_tiles
.export buffer_messages
.export buffer_debug

.segment "ZEROPAGE"

tmp:         .res 1
starty:      .res 1 ; for buffer seen loop
startx:      .res 1 ; for buffer seen loop
draw_y:      .res 1 ; current draw buffer index
last_dir:    .res 2 ; last scroll direction (x, y) for bg scrolling
draw_length: .res 1
cur_tile = tmp

.segment "CODE"

; initialize buffers
.proc init_buffer
    ; set to up since by default the dungeon is generated in first NT
    lda #Direction::left
    sta last_dir
    lda #Direction::up
    sta last_dir+1
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
    jsr can_scroll_dir
    beq start_buffer
    ; can't scroll, disable buffering
    rts

start_buffer:
    ; update scroll metaxpos and metaypos depending on player dir
    lda mobs + Mob::direction
    jsr update_coords

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
    ; update last_dir
    lda mobs + Mob::direction
    cmp #Direction::up
    beq last_dir_plus1
    cmp #Direction::down
    beq last_dir_plus1
    ; left or right, store in first byte
    sta last_dir
    ; write zero length for next buffer write
    lda #$00
    sta draw_buffer, y
    rts
last_dir_plus1:
    ; up or down, store in last byte
    sta last_dir + 1
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

.proc buffer_debug
    jsr next_index
    ; length
    lda #$17
    sta draw_buffer, y
    iny
    ; ppu addresses
    lda ppu_addr
    sta draw_buffer, y
    iny
    lda ppu_addr + 1
    sta draw_buffer, y
    iny
    ; ppu switch
    lda #0
    sta draw_buffer, y
    iny

    lda ppu_addr
    jsr buffer_num_hex
    lda ppu_addr + 1
    jsr buffer_num_hex

    lda #$00
    sta draw_buffer, y
    iny

    lda scroll
    jsr buffer_num_hex
    lda scroll + 1
    jsr buffer_num_hex

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


; increase or decrease ppuaddr depending on scroll dir
; todo check last_dir
; todo detect end of dungeon
;
; in: scroll dir
; clobbers: x register
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
    lda #Direction::down
    cmp last_dir+1
    beq up_page
    jsr dey_ppu
    rts
; todo almost! need to figure out scroll value & flipping
up_page:
    jsr dey_ppu_nt
    rts
update_down:
    jsr scroll_down
    lda #Direction::up
    cmp last_dir+1
    beq down_page
    jsr iny_ppu
    rts
; todo almost! need to figure out scroll value & flipping
down_page:
    jsr iny_ppu_nt
    rts
; todo ensure we are at left of page
update_left:
    jsr scroll_left
    jsr dex_ppu
    rts
; todo ensure we are at right of page
update_right:
    jsr scroll_right
    jsr inx_ppu
    rts
.endproc

; update metaxpos and metaypos depending on player dir for the bg tile
;
; in: scroll dir
.proc update_coords
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
    rts
update_left:
    jsr get_first_col
    sta metaxpos
    jsr get_last_row
    sta metaypos
    rts
update_right:
    jsr get_last_col
    sta metaxpos
    jsr get_last_row
    sta metaypos
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
    beq success ; edge case for going up
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
    bcs failure
    jmp success

; todo horizontal check
check_left:
check_right:
    jsr get_first_col
    ;cmp #min_bound*2
    beq failure
    jsr get_last_col
    ;cmp #max_width * 2 - min_bound * 2
    cmp #max_width * 2
    bcs failure
    jmp success
failure:
    lda #1
    rts
success:
    lda #0
    rts
.endproc
