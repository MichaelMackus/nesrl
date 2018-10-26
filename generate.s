.include "global.inc"

.export generate

.segment "ZEROPAGE"

tunnels:     .res 1
tunnel_len:  .res 1
direction:   .res 1 ; represents corridor direction
prevdir:     .res 1 ; previous direction
prevdlevel:  .res 1 ; previous dlevel
tmp:         .res 1
floor_len:   .res 1 ; used to prevent increment tunnels if traversing another corridor
connecting:  .res 1 ; used to prevent connecting corridors more than once

max_tunnels = 90 ; maximum tunnels
max_length  = 6  ; maximum length for tunnel
min_length  = 3  ; minimum length for tunnel

.segment "CODE"

; generate level
; todo generate rooms
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
    inx
    cpx #maxtiles
    bne clear_loop

; random maze generator (with length limits & no repeats) as way to make more interesting
; see https://medium.freecodecamp.org/how-to-make-your-own-procedural-dungeon-map-generator-using-the-random-walk-algorithm-e0085c8aa9a?gi=74f51f176996
generate_corridors:
    sta direction
    sta tunnels
    sta tunnel_len

    jsr randxy

    ; push xpos & ypos to stack
    lda xpos
    pha
    lda ypos
    pha
    lda #0
    pha

random_dir:
    pla
    ; restore xpos and ypos from stack (for check function)
    pla
    sta ypos
    pla
    sta xpos
random_dir_loop:
    ; pick random direction
    jsr d4
    ; prevent picking previous dir
    cmp direction
    beq random_dir_loop
    sta direction
    ; push xpos and ypos to stack to restore after check
    lda xpos
    pha
    lda ypos
    pha

; pick random length
random_length:
    lda #0
    sta floor_len
    sta connecting
    jsr d6 ; todo don't hardcode random value
    ; prevent picking previous length
    cmp tunnel_len
    beq random_length
    ; check max & min length
    cmp #max_length
    beq check_min
    bcs random_length ; greater than max_length
check_min:
    cmp #min_length
    bcc random_length
length_done:
    sta tunnel_len
    ldx #0
check_dir:
    txa
    pha
    lda direction
    jsr update_pos
    jsr within_bounds
    bne random_dir
    jsr is_corridor
    bne random_dir
    jsr is_floor
    bne continue_dir_loop
    ; increment floor length if traversing previous corridor
    inc floor_len
continue_dir_loop:
    pla
    tax
    inx
    cpx tunnel_len
    bne check_dir
    ; update prevdir for next loop
    lda direction
    sta prevdir
finish_dir:
    ; restore xpos and ypos from stack (for check function)
    pla
    sta ypos
    pla
    sta xpos
    ; update xpos and ypos
    ldx #$00

update_tile:
    ; todo only inc tunnels if floor length is > to tunnel_len - min_length
    ; todo possible endless loop
    ;lda floor_len
    ;cmp #min_length
    ;bcs update_tile_loop
inc_tunnels:
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
generate_up:
    jsr rand_passable
    ldx xpos
    ldy ypos
    cpx down_x
    bne finish_up
    cpy down_y
    bne finish_up
    jmp generate_up
finish_up:
    stx up_x
    sty up_y
; update player x & y to up or down stair, depending on prevdlevel
update_player:
    lda dlevel
    cmp prevdlevel
    bcc update_player_downstair
update_player_upstair:
    ldx up_x
    ldy up_y
    stx mobs+Mob::coords+Coord::xcoord
    sty mobs+Mob::coords+Coord::ycoord
    jmp done_update_player
update_player_downstair:
    ldx down_x
    ldy down_y
    stx mobs+Mob::coords+Coord::xcoord
    sty mobs+Mob::coords+Coord::ycoord
done_update_player:
    ; update prevdlevel for next generation
    lda dlevel
    sta prevdlevel
    ; generate max mobs
    jsr d4
    sta tmp
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
    cpx tmp
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
    ; done
    rts

.endproc

; check if corridor is overlapping next to another corridor
; enforce our corridors are only connected via intersection or corner
; clobbers: y
is_corridor:
    lda xpos
    pha
    lda ypos
    pha

    ; check if connecting to another corridor
    ; only check perpendicular dirs
    lda direction
    cmp #1
    beq cmp_x
    cmp #2
    beq cmp_y
    cmp #3
    beq cmp_x
    cmp #4
    beq cmp_y

cmp_x:
    inc xpos
    jsr within_bounds
    bne cmp_dec_x
    jsr is_floor
    beq corridor_connecting
cmp_dec_x:
    dec xpos
    dec xpos
    jsr within_bounds
    bne is_corridor_success
    jsr is_floor
    beq corridor_connecting
    jmp is_corridor_success
cmp_y:
    inc ypos
    jsr within_bounds
    bne cmp_dec_y
    jsr is_floor
    beq corridor_connecting
cmp_dec_y:
    dec ypos
    dec ypos
    jsr within_bounds
    bne is_corridor_success
    jsr is_floor
    beq corridor_connecting

is_corridor_success:
    lda #0
    sta connecting
    pla
    sta ypos
    pla
    sta xpos
    lda #0
    rts
corridor_connecting:
    inc connecting
    lda connecting
    cmp #2
    bcs is_corridor_fail
    ; allow connecting corridors at most once
    pla
    sta ypos
    pla
    sta xpos
    lda #0
    rts
is_corridor_fail:
    pla
    sta ypos
    pla
    sta xpos
    lda #1
    rts

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
    lda prevdir
    cmp #1
    beq is_opposite
    jmp isnt_opposite
cmp_dir_2:
    lda prevdir
    cmp #2
    beq is_opposite
    jmp isnt_opposite
cmp_dir_3:
    lda prevdir
    cmp #3
    beq is_opposite
    jmp isnt_opposite
cmp_dir_4:
    lda prevdir
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
