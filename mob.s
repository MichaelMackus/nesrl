.include "global.inc"

.export mob_at
.export damage_mob
.export kill_mob
.export rand_mob
.export is_alive
.export mob_dmg

.segment "ZEROPAGE"

mob_size  = .sizeof(Mob)
mobs_size = .sizeof(Mob)*maxmobs

mobs:      .res mobs_size
dmg:       .res 1 ; tmp var for damage calculation

.segment "CODE"

; get a mob at xpos and ypos
; out: 0 on success, 1 on failure
; updates: y register to mob index
.proc mob_at
    lda #$00
    tay
mob_at_loop:
    jsr is_alive
    bne mob_at_continue
    lda mobs + Mob::coords + Coord::xcoord, y
    cmp xpos
    bne mob_at_continue
    lda mobs + Mob::coords + Coord::ycoord, y
    cmp ypos
    beq mob_at_success
mob_at_continue:
    tya
    clc
    adc #mob_size
    tay
    cmp #mobs_size
    beq mob_at_fail
    jmp mob_at_loop
mob_at_success:
    lda #0
    rts
mob_at_fail:
    ldy #$FF
    lda #1
    rts
.endproc

; deal damage to mob at index y
; in: damage
.proc damage_mob
    cmp mobs+Mob::hp, y
    bcs kill_mob
    ; subtract damage from hp
    sta dmg
    lda mobs+Mob::hp, y
    sec
    sbc dmg
    sta mobs+Mob::hp, y
    rts
.endproc

; kill the mob at index y
.proc kill_mob
    lda #0
    sta mobs+Mob::hp, y
    rts
.endproc

; check if mob alive
; in: mob index
; out: 0 if alive
.proc is_alive
    lda mobs + Mob::hp, y
    cmp #0
    beq is_dead
    lda #0
    rts
is_dead:
    lda #1
    rts
.endproc

; damage roll for mob at index y
; out: damage amount
; clobbers: x
.proc mob_dmg
    lda mobs + Mob::type, y
    cmp #Mobs::player
    beq player
    cmp #Mobs::goblin
    beq d4_dmg
    cmp #Mobs::orc
    beq d6_dmg
    cmp #Mobs::ogre
    beq d8_dmg
    cmp #Mobs::dragon
    beq d12_dmg
    rts
player:
    jsr player_dmg
    rts
d4_dmg:
    jsr d4
    rts
d6_dmg:
    jsr d4
    rts
d8_dmg:
    jsr d8
    rts
d12_dmg:
    jsr d12
    rts
.endproc


; generate random mob at index y
; clobbers: x
.proc rand_mob
    ; store y for later use
    tya
    pha
    ; generate rand x, y
    jsr rand_passable
    ; restore y pos
    pla
    tay
    ; continue mob generation
    lda xpos
    sta mobs + Mob::coords + Coord::xcoord, y
    lda ypos
    sta mobs + Mob::coords + Coord::ycoord, y
    ; generate random mob type
    lda dlevel
    cmp #3
    bcc gen_1_mob
    cmp #5
    bcc gen_2_mob
    cmp #7
    bcc gen_3_mob
    jmp gen_4_mob
gen_1_mob:
    jsr d4
    cmp #4
    bcs gen_orc
    jmp gen_goblin
gen_2_mob:
    jsr d4
    cmp #4
    bcs gen_ogre
    jmp gen_orc
gen_3_mob:
    jsr d4
    cmp #3
    bcs gen_ogre
    jmp gen_orc
gen_4_mob:
    jsr d4
    cmp #4
    bcs gen_dragon
    cmp #2
    bcs gen_ogre
    jmp gen_orc
gen_goblin:
    lda #4
    sta mobs + Mob::hp, y
    lda #Mobs::goblin
    sta mobs + Mob::type, y
    rts
gen_orc:
    lda #6
    sta mobs + Mob::hp, y
    lda #Mobs::orc
    sta mobs + Mob::type, y
    rts
gen_ogre:
    lda #10
    sta mobs + Mob::hp, y
    lda #Mobs::ogre
    sta mobs + Mob::type, y
    rts
gen_dragon:
    lda #20
    sta mobs + Mob::hp, y
    lda #Mobs::dragon
    sta mobs + Mob::type, y
    rts
.endproc
