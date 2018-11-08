.include "global.inc"

.export can_player_see
.export line_of_sight

; todo perhaps use ray casting + bresenham's line algorithm?

.segment "ZEROPAGE"

destx: .res 1
desty: .res 1
prevx: .res 1
prevy: .res 1
i:     .res 1 ; used for increment in loop, to prevent use of stack
sight: .res 1 ; used to set sight for mobs (mobs can see further in dungeon)

.segment "CODE"

.proc can_player_see
    lda #1
    sta sight
    ldy #0
    jmp can_see
.endproc

.proc line_of_sight
    lda #14
    sta sight
    jmp can_see
.endproc

; check if mob can see tile
; todo line of sight
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
