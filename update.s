; procedures relating to updating the buffer
;
; todo probably want to have a proc for updating previously seen tiles to another tile

.include "global.inc"

.export buffer_hp
.export buffer_seen
.export buffer_messages

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

; todo max hp
.proc buffer_hp
    jsr next_index
    ; length
    lda #$02 ; HP always 2 chars wide
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
    bcc buffer_space
    ; buffer tens place
continue_buffer:
    jsr buffer_num
    ; finish buffer
    lda #$00
    sta draw_buffer, y
    rts
buffer_space:
    lda #$00
    sta draw_buffer, y
    iny
    lda mobs + Mob::hp
    jmp continue_buffer
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
    ; done, fill with blank spaces
    lda #$00
    sta draw_buffer, y
    inx
    iny
    cpx #message_strlen
    bne fill_loop
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
    beq continue_buffer_amount
    ; default condition
    rts
continue_buffer_amount:
    ; increase x by amount of digits
    lda messages+Message::amount, x
    cmp #10
    bcc increase_draw_len_once
    ; more than 1 digit, assuming num 0-99
    inc draw_length
    inc draw_length
update_buffer_amount:
    ; buffer number to draw buffer
    lda messages+Message::amount, x
    jsr buffer_num
    rts
increase_draw_len_once:
    inc draw_length
    jmp update_buffer_amount
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

