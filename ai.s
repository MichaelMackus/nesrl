; simple mob AI procedure
.include "global.inc"

.export mob_ai

.segment "ZEROPAGE"

tmp:      .res 1

.segment "CODE"

; update mob pos randomly, and attack player
; moves towards player if can see
; NOTE: mobs see further than player, so its a little challenging
.proc mob_ai
    ldy #mob_size
mob_ai_loop:
    tya
    jsr is_alive
    beq do_ai
    jmp continue_mob_ai
do_ai:
mob_index = tmp
move_mob:
    ; first check if can see player
    sty mob_index
    lda mobs + Mob::coords + Coord::xcoord
    sta xpos
    lda mobs + Mob::coords + Coord::ycoord
    sta ypos
    jsr line_of_sight
    bne move_random
    jmp move_towards_player
move_random:
    ; move mob random dir
    jsr d4
    pha
    jsr try_move_dir
    beq do_move
    pla
    jmp continue_mob_ai
do_move:
    pla
    jsr move_dir
continue_mob_ai:
    tya
    clc
    adc #mob_size
    tay
    cmp #mobs_size
    beq done_ai_loop
    jmp mob_ai_loop
done_ai_loop:
    rts
move_towards_player:
    ldy mob_index
    ; xpos and ypos have position of player
    lda ypos
    pha
    lda xpos
    pha
try_x:
    cmp mobs+Mob::coords+Coord::xcoord, y
    bcc try_left
cont_try_x:
    cmp mobs+Mob::coords+Coord::xcoord, y
    beq skip_right
    bcs try_right
skip_right:
    pla ; remove player x from stack
    pla ; player y pos
    pha
    jmp try_y

try_left:
    lda #Direction::left
    pha
    jsr try_move_dir
    beq finish_x_move
    ; check for player
    pla
    pha
    jsr player_at_dir
    beq attack_x_player
    ; nope, continue trying
    ldy mob_index
    pla ; direction
    pla ; player x
    pha
    jmp cont_try_x
try_right:
    lda #Direction::right
    pha
    jsr try_move_dir
    beq finish_x_move
    ; check for player
    pla
    pha
    jsr player_at_dir
    beq attack_x_player
    ; nope, continue trying
    ldy mob_index
    pla ; direction
    pla ; remove player x from stack
    pla ; player y
    pha

try_y:
    cmp mobs+Mob::coords+Coord::ycoord, y
    bcc try_up
cont_try_y:
    cmp mobs+Mob::coords+Coord::ycoord, y
    beq skip_down
    bcs try_down
skip_down:
    pla ; remove player y from stack
    jmp continue_mob_ai ; don't move, try next mob

try_up:
    lda #Direction::up
    pha
    jsr try_move_dir
    beq finish_y_move
    ; check for player
    pla
    pha
    jsr player_at_dir
    beq attack_y_player
    ; nope, continue trying
    ldy mob_index
    pla ; direction
    pla ; player y
    pha
    jmp cont_try_y
try_down:
    lda #Direction::down
    pha
    jsr try_move_dir
    beq finish_y_move
    ; check for player
    pla
    pha
    jsr player_at_dir
    beq attack_y_player
    ; nope, continue trying
    ldy mob_index
    pla ; direction
    pla ; remove player y from stack
    jmp continue_mob_ai

finish_x_move:
    pla ; direction
    jsr move_dir
    pla ; remove player x from stack
    pla ; remove player y from stack
    jmp continue_mob_ai

finish_y_move:
    pla ; direction
    jsr move_dir
    pla ; remove player y from stack
    jmp continue_mob_ai

attack_x_player:
    ; update mob direction
    pla
    ldy mob_index
    sta mobs + Mob::direction, y
    pla ; remove player x from stack
    pla ; remove player y from stack
    jmp attack_player
attack_y_player:
    ; update mob direction
    pla
    ldy mob_index
    sta mobs + Mob::direction, y
    pla ; remove player y from stack
attack_player:
    damage = tmp
    ; remember y to stack
    tya
    pha
    ; use damage calc for mob
    jsr mob_dmg
    ldy #0 ; player index
    sta damage
.ifndef WIZARD
    jsr damage_mob
.endif
    ; push message
    lda #Messages::hurt
    ldx damage
    jsr push_msg
    ; check if player dead
    ldy #0
    jsr is_alive
    bne player_dead
    ; done
    pla
    tay
    jmp continue_mob_ai
player_dead:
    ; dead
    pla ; todo ensure this is appropriate
    tay
    rts

; try to move in direction
;
; in: direction
; clobbers: xpos, ypos, x, and y
.proc try_move_dir
    cmp #Direction::left
    beq try_left
    cmp #Direction::right
    beq try_right
    cmp #Direction::down
    beq try_down
    ; up
try_up:
    jsr update_pos
    dec ypos
    jmp is_passable
try_down:
    jsr update_pos
    inc ypos
    jmp is_passable
try_right:
    jsr update_pos
    inc xpos
    jmp is_passable
try_left:
    jsr update_pos
    dec xpos
    jmp is_passable

update_pos:
    ldy mob_index
    lda mobs + Mob::coords + Coord::xcoord, y
    sta xpos
    lda mobs + Mob::coords + Coord::ycoord, y
    sta ypos
    rts
.endproc

; is player at direction?
;
; in: direction
; clobbers: xpos, ypos, x, and y
.proc player_at_dir
    cmp #Direction::left
    beq try_left
    cmp #Direction::right
    beq try_right
    cmp #Direction::down
    beq try_down
    ; up
    ; todo
try_up:
    jsr update_pos
    dec ypos
    jmp compare_player
try_down:
    jsr update_pos
    inc ypos
    jmp compare_player
try_right:
    jsr update_pos
    inc xpos
    jmp compare_player
try_left:
    jsr update_pos
    dec xpos
    jmp compare_player

compare_player:
    lda xpos
    cmp mobs + Mob::coords + Coord::xcoord
    bne fail
    lda ypos
    cmp mobs + Mob::coords + Coord::ycoord
    rts
fail:
    lda #1
    rts

update_pos:
    ldy mob_index
    lda mobs + Mob::coords + Coord::xcoord, y
    sta xpos
    lda mobs + Mob::coords + Coord::ycoord, y
    sta ypos
    rts
.endproc

; finish move in direction, xpos and ypos should be set from
; try_move_dir
;
; in: direction
.proc move_dir
    ldy mob_index
    sta mobs + Mob::direction, y
    lda ypos
    sta mobs + Mob::coords + Coord::ycoord, y
    lda xpos
    sta mobs + Mob::coords + Coord::xcoord, y
    rts
.endproc
.endproc

; should be called each time turn in order to spawn mobs randomly
.proc mob_spawner
    ; try to spawn a mob every 8 turns
    lda turn
    lsr
    bcs skip_spawn
    lsr
    bcs skip_spawn
    lsr
    bcs skip_spawn
    jmp attempt_spawn
skip_spawn:
    ; don't spawn a mob this turn
    rts
attempt_spawn:
    ; loop through mobs and try to find an empty spot
    ldy #mob_size
loop:
    lda mobs + Mob::hp, y
    beq spawn
    tya
    clc
    adc #mob_size
    tay
    cpy #mobs_size
    bne loop
    ; no empty spot for mob found
    rts
spawn:
    jsr rand_mob
    rts
.endproc
