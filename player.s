.include "global.inc"

.export initialize_player

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
