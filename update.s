; procedures relating to updating the buffer
;
; todo probably want to have a proc for updating previously seen tiles to another tile

.include "global.inc"

.export buffer_hp
.export buffer_seen
.export buffer_messages
.export update_sprites

.segment "ZEROPAGE"

tmp:   .res 1
prevx: .res 1 ; for buffer seen loop
endy:  .res 1 ; for buffer seen loop
endx:  .res 1 ; for buffer seen loop
draw_y:   .res 1 ; current draw buffer index
draw_ppu: .res 2 ; current draw ppu addr
draw_length: .res 1

.segment "CODE"

; update draw buffer with seen bg tiles
;
; clobbers: all registers, xpos, and ypos
.proc buffer_seen
    ; load player xpos and ypos
    lda mobs + Mob::coords + Coord::xcoord
    sta xpos
    lda mobs + Mob::coords + Coord::ycoord
    sta ypos
    ; get current byte offset & mask
    jsr get_byte_offset
    tay
    jsr get_byte_mask

    ; update endx and endy
    lda ypos
    clc
    adc #sight_distance + 1 ; increment by 1 for player
    sta endy
    lda xpos
    clc
    adc #sight_distance + 1 ; increment by 1 for player
    sta endx

    ; initialize draw_length
    lda #sight_distance*2 + 1 ; increment by 1 for player
    sta draw_length

    ; set ypos to ypos - 2, and xpos to xpos - 2
update_ypos:
    lda ypos
    sec
    sbc #sight_distance
    bcc fix_overflow_ypos ; detect overflow
    sta ypos
update_xpos:
    lda xpos
    sec
    sbc #sight_distance
    bcc fix_overflow_xpos ; detect overflow
    sta xpos
    sta prevx
    jmp loop

fix_overflow_ypos:
    lda #0
    sta ypos
    jmp update_xpos
fix_overflow_xpos:
    lda #0
    sta xpos
    sta prevx
    ; update draw_length
    lda mobs + Mob::coords + Coord::xcoord
    clc
    adc #sight_distance+1 ; increment by 1 for player
    sta draw_length

loop:
    lda ypos
    cmp #max_height
    bcc loop_start_buffer
    jmp done
loop_start_buffer:
    ; write draw buffer length of sight distance
    jsr next_index
    lda draw_length
    sta draw_buffer, y
    iny
    sty draw_y
    ; update ppu addr pointer, todo just need to inc by 32 each time for y
    jsr update_ppuaddr
    ; store ppu addr to buffer
    ldy draw_y
    lda draw_ppu
    sta draw_buffer, y
    iny
    lda draw_ppu+1
    sta draw_buffer, y
    iny

   ; now we're ready to draw tile data
tile_loop:
    sty draw_y
    ; ensure xpos and ypos is valid
    jsr within_bounds
    bne tile_bg
    ; check if we can see
    ldy #0
    jsr can_see
    beq draw_seen
    ; draw seen tile, if already seen
    jsr was_seen
    ; no tile was seen, draw bg
    bne tile_bg
draw_seen:
    ; update seen tile
    jsr update_seen
    ; success, draw tile
    ldx xpos
    ldy ypos
    jsr get_bg_tile
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
    inc xpos
    lda xpos
    cmp endx
    beq loop_donex
    jmp tile_loop

loop_donex:
    ; reset x
    lda prevx
    sta xpos
loop_next:
    ; store zero length at end
    lda #$00
    sta draw_buffer, y
    iny
    ; increment y & ensure we're not done
    inc ypos
    lda ypos
    cmp endy
    beq done
    jmp loop
 
done:
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
; render the player sprite
render_mobs:
    lda #0
    tay
    tax
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


; get the ppu addr for xpos and ypos and store in draw_ppu
; todo test this
.proc update_ppuaddr
    lda #$20
    sta draw_ppu
    lda #$20
    sta draw_ppu+1
    ldx #0
    ldy #0
loop:
    cpy ypos
    bne inc_ppu
    cpx xpos
    bne inc_ppu
    jmp done
inc_ppu:
    inc draw_ppu+1
    lda draw_ppu+1
    bne loop_next
    ; increment ppu high byte
    inc draw_ppu
loop_next:
    inx
    cpx #$20
    bne loop
    ldx #$0
    iny
    ; ensure y didn't overflow
    cpy #$00
    beq done
    jmp loop
done:
    rts
.endproc

