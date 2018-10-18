.include "global.inc"

.export rand_passable
.export is_passable
.export within_bounds
.export update_seen
.export was_seen
.export get_byte_mask
.export get_byte_offset

.segment "ZEROPAGE"

min_bound  = 1  ; minimum number of spaces from edge

dlevel:      .res 1
xpos:        .res 1
ypos:        .res 1
down_x:      .res 1 ; down stair x
down_y:      .res 1 ; down stair y
up_x:        .res 1 ; up stair x
up_y:        .res 1 ; up stair y
tmp:         .res 1

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

; check if tile passable
; out: 0 if passable
; clobbers: tmp, y, and x
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
; clobbers: tmp, x,  and y
; updates: seen
.proc update_seen
    jsr get_byte_offset
    tay
    jsr get_byte_mask
    ora seen, y
    sta seen, y
.endproc

; was the tile seen before?
; clobbers: tmp, x,  and y
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
; clobbers: tmp, x,  and y
; todo ensure we don't hit endless loop if out of x,y
.proc rand_passable
    jsr randxy
    jsr is_passable
    bne rand_passable
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
; clobbers: tmp
.proc get_byte_offset
    lda xpos
    lsr
    lsr
    lsr
    sta tmp
    lda ypos
    asl
    asl
    clc
    adc tmp
    rts
.endproc

; get byte mask for x
; out: byte mask
; clobbers: tmp and x
.proc get_byte_mask
    lda xpos
    sta tmp
    lda #0
    lsr tmp
    ror
    lsr tmp
    ror
    lsr tmp
    ror
    ; now fill in zeroes
    ror
    ror
    ror
    ror
    ror
    ; now, we have the remainder (bit 0-7)
    sta tmp
    lda #0
    tax
    sec
get_byte_mask_loop:
    ror
    cpx tmp
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
