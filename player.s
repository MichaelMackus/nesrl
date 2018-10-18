.include "global.inc"

.export initialize_player
.export player_regen
.export player_dmg
.export award_exp

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
    lda #0
    sta stats+PlayerStats::power
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

; generate damage for player based on level todo equipment?
; clobbers: x
.proc player_dmg
    ; generate random number 1-6
    jsr d6
    ; add the player's power
    clc
    adc stats+PlayerStats::power
    rts
.endproc

; award exp to player for mob at index y
; clobbers: all registers if level up
.proc award_exp
    lda mobs+Mob::type, y
    cmp #Mobs::goblin
    beq goblin
    cmp #Mobs::orc
    beq orc
    cmp #Mobs::ogre
    beq ogre
    cmp #Mobs::dragon
    beq dragon
    ; error
    rts
goblin:
    lda #1
    clc
    adc stats+PlayerStats::exp
    sta stats+PlayerStats::exp
    jsr check_level
    rts
orc:
    lda #2
    clc
    adc stats+PlayerStats::exp
    sta stats+PlayerStats::exp
    jsr check_level
    rts
ogre:
    lda #5
    clc
    adc stats+PlayerStats::exp
    sta stats+PlayerStats::exp
    jsr check_level
    rts
dragon:
    lda #10
    clc
    adc stats+PlayerStats::exp
    sta stats+PlayerStats::exp
    jsr check_level
    rts
.endproc

; award exp to player for mob at index y
; clobbers: all registers if level up
.proc check_level
    lda stats+PlayerStats::level
    cmp #4
    bcc check_level3
    cmp #6
    bcc check_level5
    cmp #8
    bcc check_level7
    cmp #10
    bcc check_level9
    ; no more leveling at level 10
    rts
check_level3:
    ; level player up every 10 goblins
    lda stats+PlayerStats::exp
    cmp #10
    bcs levelup
    rts
check_level5:
    ; level player up every 50 goblins
    lda stats+PlayerStats::exp
    cmp #50
    bcs levelup
    rts
check_level7:
    ; level player up every 100 goblins
    lda stats+PlayerStats::exp
    cmp #100
    bcs levelup
    rts
check_level9:
    ; level player up every 200 goblins
    lda stats+PlayerStats::exp
    cmp #200
    bcs levelup
    rts

; *ding*!
levelup:
    inc stats+PlayerStats::level
    ; level up message
    lda #Messages::levelup
    jsr push_msg
    ; gain 5 max hp every level
    lda stats+PlayerStats::maxhp
    clc
    adc #5
    sta stats+PlayerStats::maxhp
    ; reset hp to max
    sta mobs + Mob::hp
    ; gain 1 power
    inc stats+PlayerStats::power
    ; reset exp to zero
    lda #0
    sta stats+PlayerStats::exp
    ; ensure we buffer the changes
    lda #1
    sta need_buffer
    rts
.endproc
