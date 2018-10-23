; some simple procedures related to screen math
; todo need to ensure we see entire dungeon - in NES 0 = unseen tile so need to account for that

.include "global.inc"

.export init_offsets
.export get_mob_xoffset
.export get_mob_yoffset
.export can_scroll_dir
.export get_first_col
.export get_last_col
.export get_first_row
.export get_last_row

.segment "ZEROPAGE"

screen_width  = 32
screen_height = 30

metaxpos: .res 1
metaypos: .res 1

; offset for screen scrolling
xoffset:  .res 1
yoffset:  .res 1

.segment "CODE"

; initialize xoffset and yoffset
.proc init_offsets
    jsr get_first_col
    sta xoffset
    jsr get_first_row
    sta yoffset
    rts
.endproc

; get mob offset from left edge
;
; y: mob index to calculate
.proc get_mob_xoffset
    ; todo remove when figure out buffer updates
;    cpy #0
;    bne get_offset_xpos
;    jsr can_scroll_horizontal
;    bne get_offset_xpos
    lda #screen_width/2
    rts
;; calculate offset based on xpos & screen_width
;get_offset_xpos:
;    lda mobs + Mob::coords + Coord::xcoord, y
;    asl ; multiply by 2
;    sec
;    sbc xoffset
    rts
.endproc

; get mob offset from top edge
;
; y: mob index to calculate
.proc get_mob_yoffset
    ; todo remove when figure out buffer updates
;    cpy #0
;    bne get_offset_ypos
;    jsr can_scroll_vertical
;    bne get_offset_ypos
    lda #14 ; todo don't hardcode, need to line up with dungeon
    rts
;; calculate offset based on xpos & screen_width
;get_offset_ypos:
;    lda mobs + Mob::coords + Coord::ycoord, y
;    asl ; multiply by 2
;    sec
;    sbc yoffset
    rts
.endproc

; check mob dir to ensure we can scroll in that dir
;
; output: 0 if success
.proc can_scroll_dir
    lda mobs + Mob::direction
    cmp #Direction::right
    beq check_right
    cmp #Direction::left
    beq check_left
    cmp #Direction::down
    beq check_down
    ;cmp #Direction::up
    ;beq check_up
check_up:
    ; can't scroll if we're past up minbound, or down maxbound
    jsr get_first_row
    ;cmp #min_bound*2
    beq failure
    jmp success
check_down:
    jsr get_last_row
    ;cmp #max_height * 2 - min_bound * 2
    cmp #max_height * 2
    bcs failure
    jmp success
check_left:
    jsr get_first_col
    ;cmp #min_bound*2
    beq failure
check_right:
    jsr get_last_col
    ;cmp #max_width * 2 - min_bound * 2
    cmp #max_width * 2
    bcs failure
    jmp success
failure:
    lda #1
    rts
success:
    lda #0
    rts
.endproc


; metax of first column on screen
.proc get_first_col
    ; start x = player's xpos - 16
    lda mobs + Mob::coords + Coord::xcoord
    asl ; multiply by 2 for metax
    cmp #screen_width / 2
    bcc force_x
    ; check end of dungeon
    cmp #(max_width * 2) - (screen_width / 2)
    bcs force_endx
    sec
    sbc #screen_width / 2
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
    ; start y = player's ypos - 15
    lda mobs + Mob::coords + Coord::ycoord
    asl ; multiply by 2 for metay
    cmp #14 ; todo don't hardcode
    bcc force_y
    ; check end of dungeon
    cmp #(max_height * 2) - (screen_height / 2)
    bcs force_endy
    sec
    sbc #14 ; todo don't hardcode
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
