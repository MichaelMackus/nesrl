; some simple procedures related to screen math

.include "global.inc"

.export get_first_col
.export get_last_col
.export get_first_row
.export get_last_row

.segment "ZEROPAGE"

screen_width  = 32
screen_height = 30

metaxpos: .res 1
metaypos: .res 1

.segment "CODE"

; metax of first column on screen
.proc get_first_col
    ; start x = player's xpos - 16
    lda mobs + Mob::coords + Coord::xcoord
    asl ; multiply by 2 for metax
    cmp #screen_width / 2
    bcc force_x
    sec
    sbc #screen_width / 2
    rts
; todo will only work if we stop scrolling at edge
force_x:
    lda #0
    rts
.endproc

; metax of last column on screen
.proc get_last_col
    ; end   x = player's xpos + 16
    lda mobs + Mob::coords + Coord::xcoord
    asl ; multiply by 2 for metax
    cmp #screen_width / 2
    bcc force_x
    clc
    adc #screen_width / 2
    rts
; todo will only work if we stop scrolling at edge
force_x:
    lda #screen_width
    rts
.endproc

; metay of first row on screen
.proc get_first_row
    ; start y = player's ypos - 15
    lda mobs + Mob::coords + Coord::ycoord
    asl ; multiply by 2 for metay
    cmp #screen_width / 2
    bcc force_y
    sec
    sbc #screen_height / 2
    rts
; todo will only work if we stop scrolling at edge
force_y:
    lda #0
    rts
.endproc

; metay of last row on screen
.proc get_last_row
    ; end   y = player's xpos + 15
    lda mobs + Mob::coords + Coord::ycoord
    asl ; multiply by 2 for metay
    cmp #screen_width / 2
    bcc force_y
    clc
    adc #screen_height / 2
    rts
; todo will only work if we stop scrolling at edge
force_y:
    lda #screen_height
    rts
.endproc
