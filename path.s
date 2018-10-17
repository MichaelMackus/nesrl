.include "global.inc"

.segment "ZEROPAGE"

sight_distance = 2

destx: .res 1
desty: .res 1
prevx: .res 1
prevy: .res 1
i:     .res 1 ; used for increment in loop, to prevent use of stack

.segment "CODE"

; check if mob can see tile
; todo on diagonals, probably want to check diagonal closest to player on each increment, might prevent false positives
;
; xpos: destination tile x (unmodified)
; ypos: destination tile y (unmodified)
; y: mob index (unmodified)
;
; out: 0 if can see
; clobbers: x register
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
    ; check if passable
    jsr is_passable
    bne fail
    ; check increment
    inc i
    lda i
    cmp #sight_distance
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
