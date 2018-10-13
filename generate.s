.include "global.inc"

.export generate

.segment "ZEROPAGE"

tunnels:     .res 1
tunnel_len:  .res 1
direction:   .res 1 ; represents last direction

maxtiles    = 96
max_tunnels = 90 ; maximum tunnels
max_length  = 6  ; maximum length for tunnel

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
; see https://medium.freecodecamp.org/how-to-make-your-own-procedural-dungeon-map-generator-using-the-random-walk-algorithm-e0085c8aa9a?gi=74f51f176996
generate_corridors:
    sta direction
    lda #0
    sta tunnels

    jsr randxy
    stx xpos
    sty ypos

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

update_tile:
    inc tunnels
    lda tunnels
    cmp #max_tunnels
    beq tiles_done
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

tiles_done:
    ; generate up & down stair
    jsr rand_passable
    lda xpos
    sta down_x
    lda ypos
    sta down_y
    jsr rand_passable
    lda xpos
    sta up_x
    lda ypos
    sta up_y
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
