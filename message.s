.include "global.inc"

.segment "ZEROPAGE"

max_messages = 3
messages:    .res .sizeof(Message)*max_messages
tmp_message: .res .sizeof(Message)
messages_updated: .byte 1 ; used to re-render messages on change

.segment "CODE"

; use messages as a message stack & push the message
; in: type
; x:  amount
; clobbers: all registers
push_msg:
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
    lda #1
    sta messages_updated
    rts
