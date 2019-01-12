; procedures for buffering of statusbar

.include "global.inc"

.segment "ZEROPAGE"

need_buffer_status:  .res 1 ; set to 1 to flag for buffering status bar
status_scroll:       .res 2
status_nt:           .res 1 ; base nt for scrolling
tmp:                 .res 1

.segment "CODE"

; initialize vars
.proc init_status
    lda #0
    sta need_buffer_status
    sta status_scroll
    sta status_scroll + 1
    lda #%00000010
    sta status_nt

    ; todo for testing, remove
    jsr buffer_status

    rts
.endproc

; buffer the statusbar
;
; clobbers: x and y
.proc buffer_status
    ; store original ppu addr
    lda ppu_addr
    pha
    lda ppu_addr + 1
    pha

    ; update ppu addr (for statusbar) to next NT + half page (15 rows)
    jsr iny_ppu_nt
    ldy #0
next_row_loop:
    jsr iny_ppu
    iny
    cpy #15
    bne next_row_loop

    ; reset ppuaddr to origin from left edge
    lda ppu_addr + 1
    ldx #$20
    jsr divide
    sta tmp
    ; subtract result of mod 32 from ppu to get origin row without col
    lda ppu_addr + 1
    sec
    sbc tmp
    sta ppu_addr + 1

    jsr calculate_ppu_row

    ; update status_scroll with flipped base nt
    lda base_nt
    eor #%00000010
    sta status_nt
    ; multiply row by 8 to get y scroll
    lda ppu_pos
    asl
    asl
    asl
    ; update status_scroll with current y scroll
    sta status_scroll + 1

    ; todo write statusbar to buffer

    ; restore original ppu addr
    pla
    sta ppu_addr + 1
    pla
    sta ppu_addr

    rts
.endproc
