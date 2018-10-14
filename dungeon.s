.include "global.inc"

.segment "ZEROPAGE"

maxtiles   = 96
max_width  = 32
max_height = 24
min_bound  = 1  ; minimum number of spaces from edge

tiles:       .res maxtiles ; represents a 256x240 walkable grid in bits, 1 = walkable; 0 = impassable
dlevel:      .res 1
xpos:        .res 1
ypos:        .res 1
down_x:      .res 1 ; down stair x
down_y:      .res 1 ; down stair y
up_x:        .res 1 ; up stair x
up_y:        .res 1 ; up stair y

.segment "CODE"

; pick start x from 0-31 and y from 0-23
; updates xpos and ypos with coordinates
; clobbers: x
randxy:
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

; check if tile passable
; clobbers: tmp and y
; out: 0 if passable
is_passable:
    jsr get_byte_offset
    tay
    jsr get_byte_mask
    and tiles, y
    bne is_passable_success
    lda #1
    rts
is_passable_success:
    lda #0
    rts

; rand passable xy
; clobbers: tmp, x,  and y
rand_passable:
    jsr randxy
    jsr is_passable
    bne rand_passable
    rts

; is x & y within bounds?
; out: 0 if within bounds of map
; clobbers: tmp, y, and accum
within_bounds:
    ; ensure not within 3 pixels of left or right
    ldy xpos
    cpy #min_bound
    bcc within_bounds_fail
    lda #max_width
    sec
    sbc #min_bound
    sta tmp
    cpy tmp
    bcs within_bounds_fail
    ; ensure not within 3 pixels of top or bottom
    ldy ypos
    cpy #min_bound
    bcc within_bounds_fail
    lda #max_height
    sec
    sbc #min_bound
    sta tmp
    cpy tmp
    bcs within_bounds_fail
within_bounds_success:
    lda #0
    rts
within_bounds_fail:
    lda #1
    rts

; get byte offset for x,y
; out: offset to first byte in tiles (x/8 + y*4)
; clobbers: tmp
get_byte_offset:
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

; get byte mask for x
; out: byte mask
; clobbers: tmp and x
get_byte_mask:
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
