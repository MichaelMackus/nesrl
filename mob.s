.include "global.inc"

.segment "ZEROPAGE"

.enum Mobs
    player
    goblin
    orc
    ogre
    dragon
.endenum

.struct Coord
    xcoord .byte
    ycoord .byte
.endstruct

.struct Mob
    coords .tag Coord
    hp     .byte
    type   .byte ; one of Mobs enum
.endstruct

mob_size  = .sizeof(Mob)
mobs_size = .sizeof(Mob)*maxmobs

playerlvl: .res 1 ; todo stats struct
mobs:      .res mobs_size
dmg:       .res 1 ; tmp var for damage calculation

.segment "CODE"

; initialize player mob
initialize_player:
    ; initialize HP to 10
    lda #10
    sta mobs+Mob::hp
    ; initialize tile type
    lda Mobs::player
    sta mobs+Mob::type
    rts

; get player x coord
; out: coord
playerx:
    lda mobs + Mob::coords + Coord::xcoord
    rts

; get player y coord
; out: coord
playery:
    lda mobs + Mob::coords + Coord::ycoord
    rts

; update coords of player with xpos and ypos vars
update_player_pos:
    lda xpos
    sta mobs+Mob::coords+Coord::xcoord
    lda ypos
    sta mobs+Mob::coords+Coord::ycoord
    rts

; get mob x coord
; in: mob index
; out: coord
mobx:
    lda mobs + Mob::coords + Coord::xcoord, y
    rts

; get mob y coord
; in: mob index
; out: coord
moby:
    lda mobs + Mob::coords + Coord::ycoord, y
    rts

; update coords of mob at index y with xpos and ypos vars
update_mob_pos:
    lda xpos
    sta mobs+Mob::coords+Coord::xcoord, y
    lda ypos
    sta mobs+Mob::coords+Coord::ycoord, y
    rts

; get mob type
; in: mob index
; out: type
mobtype:
    lda mobs + Mob::type, y
    rts

; get a mob at xpos and ypos
; out: 0 on success, 1 on failure
; updates: y register to mob index
mob_at:
    lda #$00
    tay
mob_at_loop:
    jsr is_alive
    bne mob_at_continue
    jsr mobx
    cmp xpos
    bne mob_at_continue
    jsr moby
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

; deal damage to mob at index y
; in: damage
damage_mob:
    cmp mobs+Mob::hp, y
    bcs kill_mob
    ; subtract damage from hp
    sta dmg
    lda mobs+Mob::hp, y
    sec
    sbc dmg
    sta mobs+Mob::hp, y
    rts

; kill the mob at index y
kill_mob:
    lda #0
    sta mobs+Mob::hp, y
    rts

; check if mob alive
; in: mob index
; out: 0 if alive
is_alive:
    lda mobs + Mob::hp, y
    cmp #0
    beq is_dead
    lda #0
    rts
is_dead:
    lda #1
    rts

; generate random mob at index y
rand_mob:
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
    cmp #4
    bcs gen_dragon
    cmp #3
    bcs gen_ogre
    jmp gen_orc
gen_4_mob:
    jsr d4
    cmp #3
    bcs gen_dragon
    cmp #2
    bcs gen_ogre
    jmp gen_orc
gen_goblin:
    lda #4
    sta mobs + Mob::hp, y
    lda Mobs::goblin
    sta mobs + Mob::type, y
    rts
gen_orc:
    lda #6
    sta mobs + Mob::hp, y
    lda Mobs::orc
    sta mobs + Mob::type, y
    rts
gen_ogre:
    lda #10
    sta mobs + Mob::hp, y
    lda Mobs::ogre
    sta mobs + Mob::type, y
    rts
gen_dragon:
    lda #20
    sta mobs + Mob::hp, y
    lda Mobs::dragon
    sta mobs + Mob::type, y
    rts
