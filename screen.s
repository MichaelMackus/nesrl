; some simple procedures related to screen math
; todo need to ensure we see entire dungeon accounting for overscan

.include "global.inc"

.export get_first_col
.export get_last_col
.export get_first_row
.export get_last_row

.segment "ZEROPAGE"

screen_width     = 32
screen_height    = 30
vertical_bound   = 14
horizontal_bound = 16

; screen x & y offset
xoffset:     .res 1
yoffset:     .res 1

.segment "CODE"

; initialize xoffset and yoffset
.proc update_screen_offsets
    jsr get_first_col
    sta xoffset
    jsr get_first_row
    sta yoffset
    rts
.endproc

; metax of first column on screen
.proc get_first_col
    ; start x = player's xpos - 16
    lda mobs + Mob::coords + Coord::xcoord
    asl ; multiply by 2 for metax
    cmp #horizontal_bound
    bcc force_x
    ; check end of dungeon
    cmp #(max_width * 2) - horizontal_bound
    bcs force_endx
    sec
    sbc #horizontal_bound
    rts
; will only work if we stop scrolling at edge
force_x:
    lda #0
    rts
force_endx:
    lda #(max_width * 2) - (screen_width)
    rts
.endproc

; metax of last column on screen
.proc get_last_col
    jsr get_first_col
    clc
    adc #screen_width
    rts
.endproc

; metay of first row on screen
.proc get_first_row
    ; start y = player's ypos - 14
    lda mobs + Mob::coords + Coord::ycoord
    asl ; multiply by 2 for metay
    cmp #vertical_bound
    bcc force_y
    ; check end of dungeon
    cmp #(max_height * 2) - (screen_height - vertical_bound)
    bcs force_endy
    sec
    sbc #vertical_bound
    rts
; will only work if we stop scrolling at edge
force_y:
    lda #0
    rts
force_endy:
    lda #(max_height * 2) - (screen_height)
    rts
.endproc

; metay of last row on screen
.proc get_last_row
    jsr get_first_row
    clc
    adc #screen_height
    rts
.endproc
