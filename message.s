.include "global.inc"

.export push_msg
.export buffer_messages

.segment "ZEROPAGE"

max_messages = 3
message_strlen = 18
messages:    .res .sizeof(Message)*max_messages
tmp_message: .res .sizeof(Message)

.segment "CODE"

; Use messages as a message stack & push the message.
;
; in: type
; x:  amount
; clobbers: all registers
.proc push_msg
    sta tmp_message
    txa
    sta tmp_message+Message::amount
    ; initialize x to end of message list - 1
    ldx #.sizeof(Message)*max_messages - .sizeof(Message)*2
shift_messages:
    ; store current message at messages+message_size
    txa
    clc
    adc #.sizeof(Message)
    tay
    lda messages, x
    sta messages, y
    lda messages+Message::amount, x
    sta messages+Message::amount, y
    txa
    sec
    sbc #.sizeof(Message)
    tax
    bcs shift_messages
    ; done shifting, now store first message
    lda tmp_message
    sta messages
    lda tmp_message+Message::amount
    sta messages+Message::amount
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
    lda messages+Message::type, x
    sta tmp_message+Message::type
    lda messages+Message::amount, x
    sta tmp_message+Message::amount
    txa
    pha
    jsr update_str_pointer
    jsr buffer_str
    ldx draw_length
    ; add damage/amount
    jsr buffer_amount
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
    lda tmp_message+Message::type
    cmp #Messages::hit
    beq continue_buffer_amount
    cmp #Messages::hurt
    beq continue_buffer_amount
    cmp #Messages::heal
    beq continue_buffer_amount
    ; default condition
    rts
continue_buffer_amount:
    ; increase x by amount of digits
    lda tmp_message+Message::amount
    cmp #10
    bcc increase_x_once
    ; more than 1 digit, assuming num 0-99
    inx
    inx
update_buffer_amount:
    ; remember x for after buffer update
    txa
    pha
    ; buffer number to draw buffer
    lda tmp_message+Message::amount
    jsr buffer_num
    ; remember x index
    pla
    tax
    rts
increase_x_once:
    inx
    jmp update_buffer_amount

; update the str_pointer to point to the correct message
; uses index in x for message
update_str_pointer:
    lda tmp_message+Message::type
    cmp #Messages::none
    beq load_blank
    cmp #Messages::hit
    beq load_hit
    cmp #Messages::hurt
    beq load_hurt
    cmp #Messages::kill
    beq load_kill
load_blank:
    ; default condition
    lda #<txt_blank
    sta str_pointer
    lda #>txt_blank
    sta str_pointer+1
    rts
load_hit:
    lda #<txt_hit
    sta str_pointer
    lda #>txt_hit
    sta str_pointer+1
    rts
load_hurt:
    lda #<txt_hurt
    sta str_pointer
    lda #>txt_hurt
    sta str_pointer+1
    rts
load_kill:
    lda #<txt_kill
    sta str_pointer
    lda #>txt_kill
    sta str_pointer+1
    rts
.endproc

.segment "RODATA"

txt_blank:  .asciiz " "
txt_hit:    .asciiz "You hit it for "
txt_hurt:   .asciiz "You got hit for "
txt_kill:   .asciiz "It died!"
txt_heal:   .asciiz "You healed for "
txt_scroll: .asciiz "You read the scroll"
txt_quaff:  .asciiz "*gulp*" ; todo need asterisk
