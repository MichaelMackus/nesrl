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
