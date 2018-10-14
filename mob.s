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
mobindex:  .res 1 ; remember index of mob for operations

.segment "CODE"

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

; update the mob index for mob operations
; in: mob index (0-19)
; clobbers: y and accum
set_mob_index:
    tay
    lda #0
    sta mobindex
set_mob_index_loop:
    tya
    beq set_mob_index_done
    ; not zero yet, increase mobindex by size
    lda mobindex
    clc
    adc .sizeof(Mob)
    sta mobindex
    dey
    jmp set_mob_index_loop
set_mob_index_done:
    rts

; get mob x coord
; in: mob index
; out: coord
; clobbers: tmp and y
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
    lda tmp
    tay
    lda #4
    sta mobs + Mob::hp, y
    lda Mobs::goblin
    sta mobs + Mob::type, y
    rts
gen_orc:
    lda tmp
    tay
    lda #6
    sta mobs + Mob::hp, y
    lda Mobs::orc
    sta mobs + Mob::type, y
    rts
gen_ogre:
    lda tmp
    tay
    lda #10
    sta mobs + Mob::hp, y
    lda Mobs::ogre
    sta mobs + Mob::type, y
    rts
gen_dragon:
    lda tmp
    tay
    lda #20
    sta mobs + Mob::hp, y
    lda Mobs::dragon
    sta mobs + Mob::type, y
    rts
