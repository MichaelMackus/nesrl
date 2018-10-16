.include "global.inc"

.export initialize_player
.export buffer_hp

.segment "ZEROPAGE"

tmp: .res 1

;.struct PlayerStats
;    level .byte
;.endstruct

.segment "CODE"

; initialize player mob
.proc initialize_player
    ; initialize HP to 10
    lda #10
    sta mobs+Mob::hp
    ; initialize tile type
    lda #Mobs::player
    sta mobs+Mob::type
    rts
.endproc

; todo max hp
; todo disable nmi rendering while buffering
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
    ; remember draw index
    tya
    pha
    ; data
    lda mobs + Mob::hp
    cmp #10
    bcc buffer_space
    ; buffer tens place
    ldx #0
buffer_tens_loop:
    cmp #10
    bcc buffer_tens
    sec
    sbc #10
    inx
    jmp buffer_tens_loop
buffer_tens:
    sta tmp
    pla
    tay
    txa
    jsr get_num_tile
    sta draw_buffer, y
    iny
    lda tmp
buffer_ones:
    jsr get_num_tile
    sta draw_buffer, y
    iny
    ; length 0 signifying end of buffer
    lda #$00
    sta draw_buffer, y
    rts

buffer_space:
    pla
    tay
    lda #$00
    sta draw_buffer, y
    iny
    lda mobs + Mob::hp
    jmp buffer_ones
.endproc
