.include "global.inc"

.export readcontroller

.segment "CODE"

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
