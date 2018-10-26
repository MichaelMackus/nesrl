; procedures relating to updating the buffer
;
; todo probably want to have a proc for updating previously seen tiles to another tile
; todo update rest of code to work with new byte (vram increment flag)

.include "global.inc"

.export buffer_hp
.export buffer_tiles
.export buffer_messages

.segment "ZEROPAGE"

tmp:           .res 1
tmp2:          .res 1
starty:        .res 1 ; for buffer seen loop
startx:        .res 1 ; for buffer seen loop
draw_y:        .res 1 ; current draw buffer index
draw_length:   .res 1
ppu_pos:       .res 1 ; for ppu_at_attribute procedure
buffer_start:  .res 1 ; start index for draw buffer
prev_ppu_addr: .res 2 ; for clearing status, todo remove

.segment "CODE"

; initialize buffers
.proc init_buffer
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

; todo going right (now *left?) has a glitch in the amount of cycles it takes sometimes, perhaps something to do with NT boundary
; update draw buffer with new bg tiles
; this assumes scrolling in direction of player movement
;
; clobbers: all registers, xpos, and ypos
.proc buffer_tiles
    cur_tile = tmp

    jsr can_scroll_dir
    beq start_buffer
    ; can't scroll, disable buffering
    rts

start_buffer:
    lda ppu_addr
    sta prev_ppu_addr
    lda ppu_addr + 1
    sta prev_ppu_addr + 1

    ; initialize ppuaddr for buffering
    jsr init_ppuaddr

    ; execute buffer update twice, for 16 pixels total
    jsr buffer
    jsr buffer

    ; scroll twice
    jsr update_scroll
    jsr update_scroll

    ; reset ppuaddr to origin
    jsr reset_ppuaddr

    rts

buffer:
    ; update scroll metaxpos and metaypos depending on player dir
    jsr update_coords

    ; update ppu & scroll depending on player direction
    jsr update_ppuaddr

    ; calculate the position in the PPU, todo should we do this before updating ppu?
    jsr calculate_ppu_pos

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
    ; check to prevent attributes update (scrolling up or down)
    jsr ppu_at_attribute
    beq update_attribute
    ; check if we're past nametable boundary (scrolling left or right)
    jsr ppu_at_next_nt
    bne buffer_tile
    ; we're past NT boundary, update buffer and continue
    jsr buffer_next_nt ; updates draw buffer and draw_y
    jmp buffer_tile
update_attribute:
    jsr buffer_next_vertical_nt
buffer_tile:
    ; divide metax and metay by 2 to get tile offset
    lda metaxpos
    lsr
    sta xpos
    lda metaypos
    lsr
    sta ypos
    ; check that we can see the tile
    ; todo need to update newly seen tiles
    ;ldy #0
    ;jsr can_see ; todo check seen tiles
    ;bne blank_tile

    ; get the tiles at the ppu_addr location
    jsr get_bg_tile
    jmp update_buffer
blank_tile:
    lda #$00

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
.endproc

.proc clear_hp
    jsr next_index
    ; length
    lda #$08 ; HP always 8 chars wide
    sta draw_buffer, y
    iny
    ; ppu addresses
    jsr buffer_status_ppuaddr
    ; for VRAM update
    lda base_nt
    sta draw_buffer, y
    iny
    ; data
    lda #$00
    sta draw_buffer, y
    iny
    lda #$00
    sta draw_buffer, y
    iny
    lda #$00
    sta draw_buffer, y
    iny
    lda #$00
    sta draw_buffer, y
    iny
    lda #$00
    sta draw_buffer, y
    iny
    lda #$00
    sta draw_buffer, y
    iny
    lda #$00
    sta draw_buffer, y
    iny
    lda #$00
    sta draw_buffer, y
    iny
    lda #$00
    sta draw_buffer, y
    iny
    rts
.endproc

; todo why is status moving down on left scroll?
.proc buffer_hp
    ; clear old HP if exists
    ;lda ppu_addr
    ;pha
    ;lda ppu_addr + 1
    ;pha
    ;lda prev_ppu_addr
    ;sta ppu_addr
    ;lda prev_ppu_addr + 1
    ;sta ppu_addr + 1
    ;jsr clear_hp
    ;pla
    ;sta ppu_addr + 1
    ;pla
    ;sta ppu_addr

    jsr next_index
    ; length
    lda #$08 ; HP always 8 chars wide
    sta draw_buffer, y
    iny
    ; ppu addresses
    jsr buffer_status_ppuaddr
    ; vram increment
    lda base_nt
    sta draw_buffer, y
    iny
    ; write "HP" to screen
    lda #<txt_hp
    sta str_pointer
    lda #>txt_hp
    sta str_pointer+1
    jsr buffer_str
    lda #$00
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

; test if ppu at attribute boundary
;
; from nesdev:
; Each attribute table, starting at $23C0, $27C0, $2BC0, or $2FC0, is arranged as an 8x8 byte array
; (64 bytes total)
.proc ppu_at_attribute
    ; only test when increasing vram vertically
    lda mobs + Mob::direction
    cmp #Direction::up
    beq failure
    cmp #Direction::down
    beq failure

    ; ppu row 30 and 31 are attributes
    lda ppu_pos
    cmp #30
    bcc failure
    cmp #32
    bcc success
    jmp failure

success:
    lda #0
    rts
failure:
    lda #1
    rts
.endproc

; calculate current position in PPU
.proc calculate_ppu_pos
    lda mobs + Mob::direction
    cmp #Direction::right
    beq calculate_ppu_row
    cmp #Direction::left
    beq calculate_ppu_row

    ; calculate column
    lda ppu_addr + 1
    ldx #$20
    jsr divide
    sta ppu_pos
    rts
.endproc

; calculate current row in PPU for attribute check
.proc calculate_ppu_row
    ; 8 rows in first 3 pages
    lda ppu_addr
    ldx #4
    jsr divide
    ; result of *mod* is page number, multiply by 8 to get row
    asl
    asl
    asl
    sta ppu_pos
    ; divide low byte by 32 to get offset in page
    lda ppu_addr + 1
    ldx #$20
    jsr divide
    ; add result of *division* with row of page
    txa
    clc
    adc ppu_pos
    sta ppu_pos
    rts
.endproc

.proc ppu_at_next_nt
    lda mobs + Mob::direction
    cmp #Direction::right
    beq failure
    cmp #Direction::left
    beq failure

    ; are we at end of NT?
    lda ppu_pos
    cmp #$20
    beq success
failure:
    ; nope
    lda #1
    rts
success:
    lda #0
    rts
.endproc

; updates draw_buffer to next NT
; updates previously written draw_buffer's length
; NOTE: should only happen once per update cycle
.proc buffer_next_nt
    ; update old length to current loop index
    cur_tile = tmp
    ldy buffer_start
    lda cur_tile
    sta draw_buffer, y

    ; write new draw length
    ldy draw_y
    lda draw_length
    sec
    sbc cur_tile
    sta draw_buffer, y
    iny

    ; remember origin
    lda ppu_addr
    pha
    lda ppu_addr + 1
    pha

    ; switch to start column of next nt
    jsr inx_ppu_nt
    lda ppu_addr+1
    ldx #$20
    jsr divide
    sta tmp2
    lda ppu_addr+1
    sec
    sbc tmp2
    sta ppu_addr+1

    ; write new ppu address
    lda ppu_addr
    sta draw_buffer, y
    iny
    lda ppu_addr + 1
    sta draw_buffer, y
    iny

    ; restore previous ppu address for next buffer update
    pla
    sta ppu_addr + 1
    pla
    sta ppu_addr

    ; write vram increment, assume horizontal
    lda base_nt
    sta draw_buffer, y
    iny

    ; update ppu_pos
    lda #0
    sta ppu_pos

    sty draw_y
    rts
.endproc

; updates draw_buffer to next NT
; updates previously written draw_buffer's length
; NOTE: should only happen once per update cycle
.proc buffer_next_vertical_nt
    ; update old length to current loop index
    cur_tile = tmp
    ldy buffer_start
    lda cur_tile
    sta draw_buffer, y

    ; write new draw length
    ldy draw_y
    lda draw_length
    sec
    sbc cur_tile
    sta draw_buffer, y
    iny

    ; remember origin
    lda ppu_addr
    pha
    lda ppu_addr + 1
    pha

    ; switch to start page of next nt
    jsr iny_ppu_nt
    lda ppu_addr
    ldx #4
    jsr divide
    sta tmp2
    lda ppu_addr
    sec
    sbc tmp2
    sta ppu_addr
    ; switch to start row of next nt
    lda ppu_addr + 1
    ldx #$20
    jsr divide
    sta ppu_addr + 1

    ; write new ppu address
    lda ppu_addr
    sta draw_buffer, y
    iny
    lda ppu_addr + 1
    sta draw_buffer, y
    iny

    ; restore previous ppu address for next buffer update
    pla
    sta ppu_addr + 1
    pla
    sta ppu_addr

    ; write vram increment, assume vertical
    lda base_nt
    ora #%00000100 ; increment going down
    sta draw_buffer, y
    iny
    
    ; update ppu_pos
    lda #0
    sta ppu_pos

    sty draw_y
    rts
.endproc

; todo not properly setting to bot of nt every time
.proc buffer_status_ppuaddr
    lda ppu_addr
    pha
    lda ppu_addr + 1
    pha

    ; set ppuaddr
    jsr iny_ppu_nt
    jsr dey_ppu
    jsr dey_ppu
    jsr dey_ppu
    jsr dey_ppu
    jsr inx_ppu
    jsr inx_ppu

    lda ppu_addr
    sta draw_buffer, y
    iny
    lda ppu_addr + 1
    sta draw_buffer, y
    iny

    pla
    sta ppu_addr + 1
    pla
    sta ppu_addr
    rts
.endproc

.segment "RODATA"

txt_hp: .asciiz "HP"
