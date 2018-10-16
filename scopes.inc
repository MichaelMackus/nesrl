.enum Messages
    none
    hit
    hurt
    kill
    heal
    scroll
    quaff
.endenum

.struct Message
    type   .byte 1 ; one of Messages enum
    amount .byte 1 ; amount for hit/hurt/heal messages
.endstruct

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
