.include "global.inc"

; todo do this in batches - first generate maze, with *no* overlapping corridors
; todo then, generate rooms with max dimensions of 4x4
; todo this way, lighting & scrolling code don't update as much tiles at once
;
; todo can also do some clever tricks by making rooms have doors, so that we
; todo only show corridor *or* room at once (door would block sight)
;
; todo if we limit corridors to max length of 4, this would also eliminate
; todo need for sprite flicker

.export generate

.segment "ZEROPAGE"

tunnels:     .res 1
tunnel_len:  .res 1
direction:   .res 1 ; represents corridor direction
prevdir:     .res 1 ; previous direction
prevdlevel:  .res 1 ; previous dlevel

max_tunnels = 90 ; maximum tunnels
max_length  = 6  ; maximum length for tunnel

.segment "CODE"

; generate level
;
; clobbers: x, y, a1, and a2
.proc generate

initialize:
    lda dlevel
    cmp #0
    bne clear_tiles
    ; initialize dlevel and prevdlevel
    sta prevdlevel
    inc dlevel
clear_tiles:
    ldx #$00 ; counter for background sprite position
    ldy #$00 ; counter for background bit index
    lda #$00
clear_loop:
    sta tiles, x
    sta seen, x
    inx
    cpx #maxtiles
    bne clear_loop

; random maze generator (with length limits & no repeats) as way to make more interesting
; see https://medium.freecodecamp.org/how-to-make-your-own-procedural-dungeon-map-generator-using-the-random-walk-algorithm-e0085c8aa9a?gi=74f51f176996
generate_corridors:
    sta prevdir
    sta direction
    sta tunnels
    sta tunnel_len
    sta up_x
    sta up_y
    sta down_x
    sta down_y

    jsr randxy

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
    sta a2
    ; prevent picking same direction as previous loop
    cmp prevdir
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
    lda a2
    sta direction
    ldx #$00
    txa
    pha

; pick random length
random_length:
    jsr d6 ; todo don't hardcode random value
    ; prevent picking previous length
    cmp tunnel_len
    beq random_length
    ; check max & min length
    cmp #max_length
    beq length_done
    bcs random_length ; greater than max_length
length_done:
    sta tunnel_len
    pla
    tax
check_dir:
    lda direction
    jsr update_pos
    jsr within_bounds
    bne random_dir
    inx
    cpx tunnel_len
    bne check_dir
    ; update prevdir for next loop
    lda direction
    sta prevdir
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
    ; generate up or down stair
    jsr rand_passable
; update player x & y to up or down stair, depending on prevdlevel
update_player:
    lda dlevel
    cmp prevdlevel
    bcc update_player_downstair
update_player_upstair:
    ; update upstair
    ldx xpos
    ldy ypos
    stx up_x
    sty up_y
    ; update player coords
    stx mobs+Mob::coords+Coord::xcoord
    sty mobs+Mob::coords+Coord::ycoord
    jmp done_update_player
update_player_downstair:
    ; update down
    ldx xpos
    ldy ypos
    stx down_x
    sty down_y
    ; update player coords
    stx mobs+Mob::coords+Coord::xcoord
    sty mobs+Mob::coords+Coord::ycoord
done_update_player:
    ; update prevdlevel for next generation
    lda dlevel
    sta prevdlevel
    ; generate max mobs
    jsr d4
    sta a2
    ldy #mob_size
    ldx #0
; generate mobs
; rand_mob generates a mob each time it is called
generate_mobs:
    txa
    pha
    jsr rand_mob
    pla
    tax
    ; increment y by mob_size
    tya
    clc
    adc #mob_size
    tay
    inx
    cpx a2
    beq clear_mobs_loop
    jmp generate_mobs
; clear the rest of the mobs
clear_mobs_loop:
    jsr kill_mob
    ; increment y by mob_size
    tya
    clc
    adc #mob_size
    tay
    cmp #mobs_size
    bne clear_mobs_loop
    ; for features loop
    ldy #00
; generate random dungeon features
; rand_feature has a *chance* to generate feature each time called
generate_features:
    tya
    pha
    jsr rand_floor
    pla
    tay
    jsr rand_feature
    ; increment y by Feature size
    tya
    clc
    adc #.sizeof(Feature)
    tay
    cpy #maxfeatures * .sizeof(Feature) ; leave room for drops, since they count as "features" for now
    bne generate_features
    ldx #0
; todo generate random items in dungeon
;generate_items:
;    txa
;    pha
;    jsr rand_floor
;    ldx xpos
;    ldy ypos
;    jsr rand_feature
;    pla
;    clc
;    adc #.sizeof(Feature)
;    tax
;    cpx #maxfeatures * .sizeof(Feature) ; leave room for drops, since they count as "features" for now
;    bne generate_features

    ; finally, generate next level stairs
    lda up_x
    bne generate_down
    lda up_y
    bne generate_down
generate_up:
    ; todo make this better with min width away from up
    jsr rand_passable
    ldx xpos
    ldy ypos
    cpx down_x
    beq generate_up
    cpy down_y
    beq generate_up
    stx up_x
    stx up_y
    jmp generate_done
generate_down:
    ; todo make this better with min width away from up
    jsr rand_passable
    ldx xpos
    ldy ypos
    cpx up_x
    beq generate_down
    cpy up_y
    beq generate_down
    stx down_x
    sty down_y

generate_done:
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
