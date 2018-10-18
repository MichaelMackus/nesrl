.include "global.inc"

.export initialize_player
.export player_regen

.segment "ZEROPAGE"

tmp:   .res 1
stats: .res .sizeof(PlayerStats)

.segment "CODE"

; initialize player mob
.proc initialize_player
    ; initialize HP to 10
    lda #10
    sta mobs+Mob::hp
    ; initialize tile type
    lda #Mobs::player
    sta mobs+Mob::type
    ; initialize stats
    lda #1
    sta stats+PlayerStats::level
    lda #0
    sta stats+PlayerStats::exp
    lda #10
    sta stats+PlayerStats::maxhp
    rts
.endproc

; regen player every 8 turns
.proc player_regen
    lda turn
    lsr
    bcs done
    lsr
    bcs done
    lsr
    bcs done
    ; regen player if not at max HP
    lda mobs + Mob::hp
    cmp stats+PlayerStats::maxhp
    beq done
    ; do regen
    inc mobs + Mob::hp
    ; ensure buffer gets re-drawn
    lda #1
    sta need_buffer
done:
    rts
.endproc
