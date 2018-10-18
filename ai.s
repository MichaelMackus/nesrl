; simple mob AI procedure
.include "global.inc"

.export mob_ai

.segment "ZEROPAGE"

tmp:  .res 1

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
    ; todo diff function
    lda mobs + Mob::coords + Coord::xcoord, y
    sta xpos
    lda mobs + Mob::coords + Coord::ycoord, y
    sta ypos
    ; check x
    lda mobs + Mob::coords + Coord::xcoord
    cmp xpos
    beq checkyplus1
    inc xpos
    cmp xpos
    beq checky
    dec xpos
    dec xpos
    cmp xpos
    beq checky
    jmp move_mob
checkyplus1:
    ; check y
    lda mobs + Mob::coords + Coord::ycoord
    inc ypos
    cmp ypos
    beq attack_player
    dec ypos
    dec ypos
    cmp ypos
    beq attack_player
checky:
    lda mobs + Mob::coords + Coord::ycoord
    cmp ypos
    beq attack_player
    jmp move_mob
damage = tmp
attack_player:
    ; remember y to stack
    tya
    pha
    ; ensure we update draw buffer
    lda #1
    sta need_buffer
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
    lda #GameState::end
    sta gamestate
    pla
    tay
    jmp render_death
    rts
mob_index = tmp
move_mob:
    ; first check if can see player
    sty mob_index
    lda mobs + Mob::coords + Coord::xcoord
    sta xpos
    lda mobs + Mob::coords + Coord::ycoord
    sta ypos
    jsr can_see
    bne move_random
    jmp move_towards_player
move_random:
    ldy mob_index
    ; move mob random dir
    lda mobs + Mob::coords + Coord::xcoord, y
    sta xpos
    lda mobs + Mob::coords + Coord::ycoord, y
    sta ypos
    jsr d4
    cmp #1
    beq move_mob_up
    cmp #2
    beq move_mob_right
    cmp #3
    beq move_mob_down
move_mob_left:
    dec xpos
    jsr is_passable
    beq do_move_mob_left
    ldy mob_index
    jmp continue_mob_ai
do_move_mob_left:
    ldy mob_index
    lda xpos
    sta mobs+Mob::coords+Coord::xcoord, y
    jmp continue_mob_ai
move_mob_up:
    dec ypos
    jsr is_passable
    beq do_move_mob_up
    ldy mob_index
    jmp continue_mob_ai
do_move_mob_up:
    ldy mob_index
    lda ypos
    sta mobs+Mob::coords+Coord::ycoord, y
    jmp continue_mob_ai
move_mob_right:
    inc xpos
    jsr is_passable
    beq do_move_mob_right
    ldy mob_index
    jmp continue_mob_ai
do_move_mob_right:
    ldy mob_index
    lda xpos
    sta mobs+Mob::coords+Coord::xcoord, y
    jmp continue_mob_ai
move_mob_down:
    inc ypos
    jsr is_passable
    beq do_move_mob_up
    ldy mob_index
    jmp continue_mob_ai
do_move_mob_down:
    ldy mob_index
    lda ypos
    sta mobs+Mob::coords+Coord::ycoord, y
    jmp continue_mob_ai
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
    lda mobs+Mob::coords+Coord::xcoord, y
    sta xpos
    lda mobs+Mob::coords+Coord::ycoord, y
    sta ypos
    dec xpos
    jsr is_passable
    beq finish_x_move
    ; nope, continue trying
    ldy mob_index
    pla ; player x
    pha
    jmp cont_try_x
try_right:
    lda mobs+Mob::coords+Coord::xcoord, y
    sta xpos
    lda mobs+Mob::coords+Coord::ycoord, y
    sta ypos
    inc xpos
    jsr is_passable
    beq finish_x_move
    ; nope, continue trying
    ldy mob_index
    pla ; remove player x from stack
    pla ; player y
    pha
    jmp try_y
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
    lda mobs+Mob::coords+Coord::xcoord, y
    sta xpos
    lda mobs+Mob::coords+Coord::ycoord, y
    sta ypos
    dec ypos
    jsr is_passable
    beq finish_move
    ; nope, continue trying
    ldy mob_index
    pla ; player y
    pha
    jmp cont_try_y
try_down:
    lda mobs+Mob::coords+Coord::xcoord, y
    sta xpos
    lda mobs+Mob::coords+Coord::ycoord, y
    sta ypos
    inc ypos
    jsr is_passable
    beq finish_move
    ; nope, done trying
    ldy mob_index
    pla ; remove player y from stack
    jmp continue_mob_ai
finish_x_move:
    pla ; remove player x from stack
finish_move:
    pla ; remove player y from stack
    ldy mob_index
    lda xpos
    sta mobs+Mob::coords+Coord::xcoord, y
    lda ypos
    sta mobs+Mob::coords+Coord::ycoord, y
    ; continue AI
    jmp continue_mob_ai
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
