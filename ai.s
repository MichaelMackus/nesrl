; simple mob AI procedure
.include "global.inc"

.export mob_ai

mob_index = a2
mob_dir   = a3

.segment "CODE"

; update mob pos randomly, and attack player
; moves towards player if can see
; NOTE: mobs see further than player, so its a little challenging
; todo bug when moving out of mob range?
.proc mob_ai
    ldy #mob_size
mob_ai_loop:
    sty mob_index
    jsr is_alive
    beq do_ai
    jmp continue_mob_ai
do_ai:
    ; first check if can see player
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
    sta mob_dir
    jsr try_move_dir
    beq do_move
    jmp continue_mob_ai
do_move:
    lda mob_dir
    jsr move_dir
continue_mob_ai:
    ldy mob_index
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
try_x:
    lda mobs + Mob::coords + Coord::xcoord
    cmp mobs + Mob::coords + Coord::xcoord, y
    bcc try_left
cont_try_x:
    lda mobs + Mob::coords + Coord::xcoord
    cmp mobs + Mob::coords + Coord::xcoord, y
    beq try_y
    bcs try_right
    jmp try_y

try_left:
    lda #Direction::left
    sta mob_dir
    jsr try_move_dir
    beq finish_move
    ; check for player
    lda mob_dir
    jsr player_at_dir
    beq attack_player
    ; nope, continue trying
    ldy mob_index
    jmp cont_try_x
try_right:
    lda #Direction::right
    sta mob_dir
    jsr try_move_dir
    beq finish_move
    ; check for player
    lda mob_dir
    jsr player_at_dir
    beq attack_player
    ; nope, continue trying
    ldy mob_index

try_y:
    lda mobs + Mob::coords + Coord::ycoord
    cmp mobs + Mob::coords + Coord::ycoord, y
    bcc try_up
cont_try_y:
    lda mobs + Mob::coords + Coord::ycoord
    cmp mobs + Mob::coords + Coord::ycoord, y
    beq continue_mob_ai
    bcs try_down
    jmp continue_mob_ai

try_up:
    lda #Direction::up
    sta mob_dir
    jsr try_move_dir
    beq finish_move
    ; check for player
    lda mob_dir
    jsr player_at_dir
    beq attack_player
    ; nope, continue trying
    ldy mob_index
    jmp cont_try_y
try_down:
    lda #Direction::down
    sta mob_dir
    jsr try_move_dir
    beq finish_move
    ; check for player
    lda mob_dir
    jsr player_at_dir
    beq attack_player
    ; nope, continue trying
    ldy mob_index
    jmp continue_mob_ai

finish_move:
    jmp do_move

attack_player:
    ; update mob direction
    ldy mob_index
    lda mob_dir
    sta mobs + Mob::direction, y
    ; remember y to stack
    tya
    pha
    ; use damage calc for mob
    damage = a1
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
    sta mob_index
    jmp continue_mob_ai
player_dead:
    ; dead
    pla
    rts

; try to move in direction
;
; in: direction
; clobbers: xpos, ypos, x, and y
.proc try_move_dir
    lda mob_dir
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
