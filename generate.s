.include "global.inc"

.export generate

.segment "ZEROPAGE"

xpos:        .res 1
ypos:        .res 1
tunnels:     .res 1
tunnel_len:  .res 1
direction:   .res 1 ; represents last direction

max_width = 32
max_height = 24
max_tunnels = 90 ; maximum tunnels
max_length = 6 ; maximum length for tunnel
min_bound = 1 ; minimum number of spaces from edge

.segment "CODE"

; generate level
.proc generate

clear_tiles:
    ldx #$00 ; counter for background sprite position
    ldy #$00 ; counter for background bit index
    lda #$00
clear_loop:
    sta tiles, x
    inx
    cpx #maxtiles
    bne clear_loop

; random maze generator (with length limits & no repeats) as way to make more interesting
generate_corridors:
    sta direction
    lda #0
    sta tunnels

; pick random start x from 0-31
randx:
    jsr prng
    lsr
    lsr
    lsr
    cmp #max_width
    bcs randx
    sta xpos
; pick random start y from 0-23
randy:
    jsr prng
    lsr
    lsr
    lsr
    cmp #max_height
    bcs randy
    sta ypos

    ; ensure rand x & y are within max_length of edges
    jsr within_bounds
    bne randx

    ; initialize vars
    lda #$00
    sta tunnels

    ; push xpos & ypos to stack
    lda xpos
    pha
    lda ypos
    pha

random_dir:
    ; restore xpos and ypos from stack (for check function)
    pla
    sta ypos
    pla
    sta xpos
random_dir_loop:
    ; pick random direction
    jsr d4
    sta tmp
    ; prevent picking same direction as previous loop
    cmp direction
    beq random_dir_loop
    ; prevent picking opposite direction
    jsr is_opposite_dir
    beq random_dir_loop
    ; push xpos and ypos to stack to restore after check
    lda xpos
    pha
    lda ypos
    pha
    ; update direction
    lda tmp
    sta direction
    ldx #$00

; pick random length
random_length:
    jsr d6 ; todo don't hardcode random value
    cmp #max_length
    beq length_done
    bcs random_length ; greater than max_length
length_done:
    sta tunnel_len

check_dir:
    lda direction
    jsr update_pos
    jsr within_bounds
    bne random_dir
    inx
    cpx tunnel_len
    bne check_dir
    ; restore xpos and ypos from stack (for check function)
    pla
    sta ypos
    pla
    sta xpos
    ; update xpos and ypos
    ldx #$00

; todo inc tunnels
update_tile:
    inc tunnels
    lda tunnels
    cmp #max_tunnels
    beq done_generating
update_tile_loop:
    lda direction
    jsr update_pos
    ; update tile
    jsr get_byte_offset
    tay
    txa
    pha
    jsr get_byte_mask
    ora tiles, y
    sta tiles, y
    pla
    tax
    ; keep updating until tunnel length
    inx
    cpx tunnel_len
    bne update_tile_loop

    ; done, pick a new direction
    jmp random_dir_loop

    ; todo use random walk algorithm
    ; todo see https://medium.freecodecamp.org/how-to-make-your-own-procedural-dungeon-map-generator-using-the-random-walk-algorithm-e0085c8aa9a?gi=74f51f176996

;generate_corridors_loop:
;    pla
;    tay
;    jsr generate_corridor
;    tya
;    pha
;    jsr update_visited
;    ; keep going until all cells visited
;    cmp #12
;    bne generate_corridors_loop
;    pla

done_generating:
    rts

.endproc

; check if direction is opposite of previous "direction" var
; in: current dir
; out: 0 if true (invalid current dir)
is_opposite_dir:
    cmp #1
    beq cmp_dir_3
    cmp #2
    beq cmp_dir_4
    cmp #3
    beq cmp_dir_1
    cmp #4
    beq cmp_dir_2
cmp_dir_1:
    lda direction
    cmp #1
    beq is_opposite
    jmp isnt_opposite
cmp_dir_2:
    lda direction
    cmp #2
    beq is_opposite
    jmp isnt_opposite
cmp_dir_3:
    lda direction
    cmp #3
    beq is_opposite
    jmp isnt_opposite
cmp_dir_4:
    lda direction
    cmp #4
    beq is_opposite
    jmp isnt_opposite
is_opposite:
    lda #0
    rts
isnt_opposite:
    lda #1
    rts

; is xpos & ypos within bounds?
; out: 0 if within bounds of map
; clobbers: tmp and y
within_bounds:
    ldy xpos
    ; ensure not within 3 pixels of left or right
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

; update xpos and ypos
; in: direction (1-4)
; affects: xpos and ypos
update_pos:
    cmp #1
    beq dec_ypos
    cmp #2
    beq inc_xpos
    cmp #3
    beq inc_ypos
    cmp #4
    beq dec_xpos
dec_ypos:
    dec ypos
    rts
inc_xpos:
    inc xpos
    rts
inc_ypos:
    inc ypos
    rts
dec_xpos:
    dec xpos
    rts

; get quadrant for offset y
; in: offset
; out: quadrant
; clobbers: tmp and all registers
; todo fixme the rol stuff is messed up, bits will be reversed
get_quadrant:
    tay
    lda #0
    sta tmp
    tya
    ; divide by 32, storing remainder in tmp
    lsr
    rol tmp
    lsr
    rol tmp
    lsr
    rol tmp
    lsr
    rol tmp
    lsr
    rol tmp
    ; decrement division result by 1 to get index
    tay
    dey
    ; now a has y value and tmp has remainder

    ; ; divide remainder by 4
    ; lda tmp
    ; ldx #$0
    ; stx tmp
    ; lsr
    ; rol tmp
    ; lsr
    ; rol tmp

    ; remainder of division should be x offset
    ; result is 4 * y + x
    tya
    asl
    asl
    clc
    adc tmp

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

; the tiles quadrants are arranged like so:
;
;    0        1        2        3
; 00000000 00000001 00000010 00000011
;
; 00000000 00000000 00000000 00000000
; 01000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000100 10000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000

;    4        5        6        7
; 00000100 00000101 00000110 00000111
;
; 00000000 00000000 00000000 00000000
; 01000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000100 10000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000

;    8        9        10       11
; 00001000 00001001 00001010 00010111
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

