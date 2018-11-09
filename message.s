.include "global.inc"

.export push_msg
.export update_message_str
.export has_amount

.segment "ZEROPAGE"

max_messages = 3
message_strlen = 18
messages:    .res .sizeof(Message)*max_messages
tmp_message: .res .sizeof(Message)

.segment "CODE"

; clobbers: x
.proc clear_messages
    ldx #0
clear_messages:
    lda #Messages::none
    sta messages, x
    txa
    clc
    adc #.sizeof(Message)
    tax
    cmp #.sizeof(Message) * max_messages
    bne clear_messages
    rts
.endproc

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

.proc update_message_str
; update the str_pointer to point to the correct message
; uses index in x for message
    lda messages+Message::type, x
    cmp #Messages::none
    beq load_blank
    cmp #Messages::hit
    beq load_hit
    cmp #Messages::hurt
    beq load_hurt
    cmp #Messages::kill
    beq load_kill
    cmp #Messages::levelup
    beq load_levelup
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
load_levelup:
    lda #<txt_lvlup
    sta str_pointer
    lda #>txt_lvlup
    sta str_pointer+1
    rts
.endproc

; out: 0 if type uses amount at end of str
.proc has_amount
    lda messages+Message::type, x
    cmp #Messages::hit
    beq success
    cmp #Messages::hurt
    beq success
    cmp #Messages::heal
    beq success
    ; default condition
    lda #1
    rts
success:
    lda #0
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
txt_lvlup:  .asciiz "You leveled up!"
