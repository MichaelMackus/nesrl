.include "global.inc"

; todo perhaps use ray casting + bresenham's line algorithm?
; todo alternatively, if fix generation to generate non-overlapping corridors,
; todo and separate rooms, we can just do simple alg of showing current
; todo corridor(s) lining up to player's tile, and current room

.segment "ZEROPAGE"

sight_distance = 7

destx: .res 1
desty: .res 1
prevx: .res 1
prevy: .res 1
i:     .res 1 ; used for increment in loop, to prevent use of stack
sight: .res 1 ; used to set sight for mobs (mobs can see further in dungeon)

.segment "CODE"

; check if mob can see tile
;
; xpos: destination tile x (unmodified)
; ypos: destination tile y (unmodified)
; y: mob index (modified)
;
; out: 0 if can see
; clobbers: x and y register
.proc can_see
    ; load our destination
    lda xpos
    sta destx
    sta prevx
    lda ypos
    sta desty
    sta prevy
    ; load our source
    lda mobs + Mob::coords + Coord::xcoord, y
    sta xpos
    lda mobs + Mob::coords + Coord::ycoord, y
    sta ypos
    lda mobs + Mob::type, y
    cmp #Mobs::player
    bne set_mob_sight
    ; set player sight radius
    lda #sight_distance
    sta sight
    jmp continue
set_mob_sight:
    ; set mob sight radius (+1 from player)
    lda #sight_distance+1
    sta sight

continue:
    ; set increment
    lda #0
    sta i

loop:

    ; keep advancing until we get to destx
    lda destx
    cmp xpos
    bcc decx ; less than
    beq skipx
incx:
    inc xpos
    jmp skipx
decx:
    dec xpos
skipx:
    ; keep advancing until we get to desty
    lda desty
    cmp ypos
    bcc decy ; less than
    beq skipy
incy:
    inc ypos
    jmp skipy
decy:
    dec ypos
skipy:

    ; check if equal
    lda xpos
    cmp destx
    bne check_passable
    lda ypos
    cmp desty
    ; success!
    beq success
check_passable:
    ; check if floor
    jsr is_floor
    bne fail
    ; check increment
    inc i
    lda i
    cmp sight
    beq fail
    ; re-try loop until we get to destination *or* impassable
    jmp loop

success:
    ; remember pos
    lda prevx
    sta xpos
    lda prevy
    sta ypos
    ; success result
    lda #0
    rts
fail:
    ; remember pos
    lda prevx
    sta xpos
    lda prevy
    sta ypos
    ; failure result
    lda #1
    rts
.endproc
