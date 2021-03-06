.include "global.inc"

.export rand_passable
.export rand_floor
.export is_floor
.export is_passable
.export within_bounds
.export update_seen
.export was_seen
.export get_byte_mask
.export get_byte_offset

.segment "ZEROPAGE"

dlevel:      .res 1
xpos:        .res 1
ypos:        .res 1
down_x:      .res 1 ; down stair x
down_y:      .res 1 ; down stair y
up_x:        .res 1 ; up stair x
up_y:        .res 1 ; up stair y

.segment "BSS"

tiles:       .res maxtiles ; represents a 256x240 walkable grid in bits, 1 = walkable; 0 = impassable
seen:        .res maxtiles

.segment "CODE"

; pick start x from 0-31 and y from 0-23
; updates xpos and ypos with coordinates
; clobbers: x
.proc randxy
randy:
    jsr prng
    lsr
    lsr
    lsr
    cmp #max_height
    bcs randy
    sta ypos
randx:
    jsr prng
    lsr
    lsr
    lsr
    cmp #max_width
    bcs randx
    sta xpos
    ; 
    ; ensure rand x & y are within max_length of edges
    jsr within_bounds
    bne randxy
    rts
.endproc

; check if tile is floor (doesn't check mobs)
; out: 0 if passable
; clobbers: a1, y, and x
.proc is_floor
    jsr get_byte_offset
    tay
    jsr get_byte_mask
    and tiles, y
    bne tile_passable
    jmp fail
tile_passable:
    ; success!
    lda #0
    rts
fail:
    lda #1
    rts
.endproc

; check if tile passable (checks mobs)
; out: 0 if passable
; clobbers: a1, y, and x
.proc is_passable
    jsr get_byte_offset
    tay
    jsr get_byte_mask
    and tiles, y
    bne tile_passable
    jmp fail
tile_passable:
    ; ensure no mobs at x, y
    jsr mob_at
    beq fail
    ; success!
    lda #0
    rts
fail:
    lda #1
    rts
.endproc

; update the seen tile at xpos and ypos
; clobbers: a1, x,  and y
; updates: seen
.proc update_seen
    jsr get_byte_offset
    tay
    jsr get_byte_mask
    ora seen, y
    sta seen, y
.endproc

; was the tile seen before?
; clobbers: a1, x,  and y
; out: 0 if seen
.proc was_seen
    jsr get_byte_offset
    tay
    jsr get_byte_mask
    and seen, y
    bne success
    ; failure
    lda #1
    rts
success:
    lda #0
    rts
.endproc

; rand passable xy
; clobbers: a1, x,  and y
; todo ensure we don't hit endless loop if out of x,y
.proc rand_passable
    jsr randxy
    jsr is_passable
    bne rand_passable
    rts
.endproc

; rand floor xy
; clobbers: a1, x,  and y
; todo ensure we don't hit endless loop if out of x,y
.proc rand_floor
    jsr randxy
    jsr is_floor
    bne rand_floor
    rts
.endproc

; is x & y within bounds?
; out: 0 if within bounds of map
; clobbers: accum
.proc within_bounds
    ; ensure not within 3 pixels of left or right
    lda xpos
    cmp #min_bound
    bcc within_bounds_fail
    cmp #max_width-min_bound
    bcs within_bounds_fail
    ; ensure not within 3 pixels of top or bottom
    lda ypos
    cmp #min_bound
    bcc within_bounds_fail
    cmp #max_height-min_bound
    bcs within_bounds_fail
within_bounds_success:
    lda #0
    rts
within_bounds_fail:
    lda #1
    rts
.endproc

; get byte offset for x,y
; out: offset to first byte in tiles (x/8 + y*4)
; clobbers: a1
.proc get_byte_offset
    lda xpos
    lsr
    lsr
    lsr
    sta a1
    lda ypos
    asl
    asl
    clc
    adc a1
    rts
.endproc

; get byte mask for x
; out: byte mask
; clobbers: a1 and x
.proc get_byte_mask
    lda xpos
    ; get 3 lowest bits (number 0-7)
    and #%00000111
    ; now, we have the remainder (bit 0-7)
    sta a1
    ldx #0
    sec
get_byte_mask_loop:
    ror
    cpx a1
    beq get_byte_mask_done
    inx
    jmp get_byte_mask_loop
get_byte_mask_done:
    rts
.endproc

; the tiles are arranged like so:
;
; 00000000 00000000 00000000 00000000
; 01000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000100 10000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
;
; 00000000 00000000 00000000 00000000
; 01000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000100 10000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
;
; 00000000 00000000 00000000 00000000
; 01000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000100 10000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
;
; bit at x,y of 1,1 would be in quadrant 0 with offset 0
; bit at x,y of 8,3 would be in quadrant 1 with offset 1
; bit at x,y of 1,9 would be in quadrant 4 with offset 32
; bit at x,y of 8,11 would be in quadrant 5 with offset 33
