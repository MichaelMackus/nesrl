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
