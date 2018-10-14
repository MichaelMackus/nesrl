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

maxenemies = 20
player:    .res .sizeof(Mob)
playerlvl: .res 1
enemies:   .res .sizeof(Mob)*maxenemies

.segment "CODE"

update_player_pos:
    lda xpos
    sta player+Mob::coords+Coord::xcoord
    lda ypos
    sta player+Mob::coords+Coord::ycoord
    rts

playerx:
    lda player+Mob::coords+Coord::xcoord
    rts
playery:
    lda player+Mob::coords+Coord::ycoord
    rts

; check if mob alive
; in: mob index
; out: 0 if alive
is_alive:
    tay
    lda enemies + Mob::hp, y
    cmp #0
    beq is_dead
    lda #0
    rts
is_dead:
    lda #1
    rts

; get enemy x coord
; in: mob index
; out: coord
enemyx:
    tay
    lda enemies + Mob::coords + Coord::xcoord, y
    rts

; get enemy y coord
; in: mob index
; out: coord
enemyy:
    tay
    lda enemies + Mob::coords + Coord::ycoord, y
    rts

; generate random mob at index x
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
    sta enemies + Mob::coords + Coord::xcoord, y
    lda ypos
    sta enemies + Mob::coords + Coord::ycoord, y
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
    sta enemies + Mob::hp, y
    lda Mobs::goblin
    sta enemies + Mob::type, y
    rts
gen_orc:
    lda tmp
    tay
    lda #6
    sta enemies + Mob::hp, y
    lda Mobs::orc
    sta enemies + Mob::type, y
    rts
gen_ogre:
    lda tmp
    tay
    lda #10
    sta enemies + Mob::hp, y
    lda Mobs::ogre
    sta enemies + Mob::type, y
    rts
gen_dragon:
    lda tmp
    tay
    lda #20
    sta enemies + Mob::hp, y
    lda Mobs::dragon
    sta enemies + Mob::type, y
    rts
