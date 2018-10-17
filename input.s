.include "global.inc"

.export readcontroller
.export handle_input

.segment "CODE"

.proc handle_input
    lda controller1release
    and #%10000000 ; a
    beq check_movement
    jmp handle_action
check_movement:
    ; update player pos to memory
    lda mobs + Mob::coords + Coord::xcoord
    sta xpos
    lda mobs + Mob::coords + Coord::ycoord
    sta ypos
    ; handle player movement
    lda controller1release
    and #%00000010  ; left
    bne attempt_left
    lda controller1release
    and #%00000001  ; right
    bne attempt_right
    lda controller1release
    and #%00000100  ; down
    bne attempt_down
    lda controller1release
    and #%00001000  ; up
    bne attempt_up
    rts
attempt_left:
    dec xpos
    jsr attempt_move
    rts
attempt_right:
    inc xpos
    jsr attempt_move
    rts
attempt_down:
    inc ypos
    jsr attempt_move
    rts
attempt_up:
    dec ypos
    jsr attempt_move
    rts
.endproc

; handle a button
.proc handle_action
check_dstair:
    ldx mobs + Mob::coords + Coord::xcoord
    ldy mobs + Mob::coords + Coord::ycoord
    cpx down_x
    bne check_upstair
    cpy down_y
    bne check_upstair
    ; on downstair, generate new level
    inc dlevel
    lda dlevel
    cmp #10 ; todo custom win condition
    beq win
    jsr regenerate
    rts
check_upstair:
    ldx mobs + Mob::coords + Coord::xcoord
    lda mobs + Mob::coords + Coord::ycoord
    cpx up_x
    bne input_done
    cpy up_y
    bne input_done
    ; on upstair, generate new level
    dec dlevel
    lda dlevel
    cmp #0
    beq escape
    jsr regenerate
    rts
escape:
    jsr render_escape
    ; escape dungeon
    lda #2
    sta gamestate
    rts
win:
    jsr render_win
    ; win dungeon
    lda #3
    sta gamestate
    rts
input_done:
    rts
.endproc

; attempt move at xpos, ypos
.proc attempt_move
    jsr within_bounds
    beq do_move
    rts
do_move:
    jsr mob_at
    beq attack_mob
    jsr is_passable
    bne input_done
    ; move successful
    lda xpos
    sta mobs+Mob::coords+Coord::xcoord
    lda ypos
    sta mobs+Mob::coords+Coord::ycoord
    rts
attack_mob:
    ; ensure we update buffer
    lda #1
    sta need_buffer
    ; todo use damage calc, for now just do 1 damage
    lda #1
    tax ; preserve for messaging
    jsr damage_mob
    ; if dead, push kill message
    jsr is_alive
    bne mob_killed
    ; push damage message, uses x register above
    lda #Messages::hit
    jsr push_msg
    ; done
    rts
mob_killed:
    ; push damage message, uses x register above
    lda #Messages::hit
    jsr push_msg
    ; push kill message
    lda #Messages::kill
    jsr push_msg
    ; done
    rts
input_done:
    rts
.endproc


.proc readcontroller

    ; previous controller1 state
    ldx controller1
    ; tell CPU we're reading controller
    lda #$01
    sta $4016
    ; store a single bit in controller 1
    sta controller1
    ; reset latching so we can read all buttons
    lsr a
    sta $4016
controllerloop:
    lda $4016
    lsr a
    ; carry will be 1 when bit from above is rotated off
    rol controller1
    bcc controllerloop
readreleased:
    ; figure out released buttons between x and controller1
    ; see: released.txt for example states
    ;
    ; first, we EOR previous controller state with new state
    txa
    eor controller1
    ; now, store the EOR'ed state to var
    sta controller1release
    ; now, we have to AND the stored var with previous state
    ; this will *only* set the bit if the button was in previous
    ; state, and not in new state due to EOR
    txa
    and controller1release
    sta controller1release
    ; done!
    rts

.endproc
