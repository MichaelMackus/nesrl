.enum GameState
    start
    playing
    end
    win
.endenum

.enum Messages
    none
    hit
    hurt
    kill
    heal
    scroll
    quaff
    levelup
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

.struct PlayerStats
    level .byte
    exp   .byte
    maxhp .byte
    power .byte
.endstruct

.enum ItemTypes
    none
    potion
    scroll
.endenum

.enum Potions
    heal
    fullheal
    poison
    confusion
    power
.endenum
.enum Scrolls
    teleport
    mapping
    fire
    fear
    amnesia
.endenum

.struct Item
    appearance .word ; pointer to appearance string
    item       .byte ; one of above item enums
    type       .byte
.endstruct

.struct ItemDrop
    coords     .tag Coord
    item       .tag Item
.endstruct

.enum Features
    none
    chest
.endenum

.struct Feature
    coords     .tag Coord
    type       .byte
.endstruct
