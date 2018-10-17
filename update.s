; functions relating to updating the buffer

.include "global.inc"

.export buffer_hp
.export buffer_messages

.segment "ZEROPAGE"

tmp: .res 1

.segment "CODE"

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

