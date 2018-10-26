.include "global.inc"

.export readcontroller
.export handle_input

.segment "ZEROPAGE"

input_result: .res 1

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
    ; no input
    lda #InputResult::none
    rts
attempt_left:
    dec xpos
    ; update player direction
    lda #Direction::left
    sta mobs + Mob::direction
    jsr attempt_move
    rts
attempt_right:
    inc xpos
    lda #Direction::right
    sta mobs + Mob::direction
    jsr attempt_move
    rts
attempt_down:
    inc ypos
    lda #Direction::down
    sta mobs + Mob::direction
    jsr attempt_move
    rts
attempt_up:
    dec ypos
    lda #Direction::up
    sta mobs + Mob::direction
    jsr attempt_move
    rts
.endproc

; handle a button
; returns InputResult for handling of input
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
    lda #InputResult::new_dlevel
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
    lda #InputResult::new_dlevel
    rts
escape:
    jsr render_escape
    ; escape dungeon
    lda #InputResult::escape
    rts
win:
    jsr render_win
    ; win dungeon
    lda #InputResult::win
    rts
input_done:
    lda #InputResult::none
    rts
.endproc

; attempt move at xpos, ypos
; returns InputResult for handling of input
.proc attempt_move
    jsr within_bounds
    beq do_move
    lda #InputResult::none
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
    lda #InputResult::move
    rts
attack_mob:
    ; use damage calc for player
    jsr player_dmg
    tax ; preserve for messaging
    jsr damage_mob
    ; if dead, push kill message
    jsr is_alive
    bne mob_killed
    ; push damage message, uses x register above
    lda #Messages::hit
    jsr push_msg
    ; done
    lda #InputResult::attack
    rts
mob_killed:
    tya
    pha
    ; push damage message, uses x register above
    lda #Messages::hit
    jsr push_msg
    ; push kill message
    lda #Messages::kill
    jsr push_msg
    ; award exp
    pla
    tay
    jsr award_exp
    ; done
    lda #InputResult::attack
    rts
input_done:
    lda #InputResult::none
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
