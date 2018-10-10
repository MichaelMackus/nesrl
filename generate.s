.include "global.inc"

.export generate

.segment "ZEROPAGE"

max_generate = 10
tmp:         .res 1 ; temporary variable for generation code

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
    cpx maxtilebytes
    bne clear_loop

generate_cells:
    ; set sample cells for now
    ldx #0
    ldy #1
    jsr set_cell
    ldx #1
    ldy #1
    jsr set_cell
    ldx #9
    ldy #1
    jsr set_cell
    ldx #16
    ldy #1
    jsr set_cell
    ldx #23
    ldy #1
    jsr set_cell
    ldx #0
    ldy #2
    jsr set_cell
    ldx #1
    ldy #2
    jsr set_cell
    ldx #9
    ldy #2
    jsr set_cell
    ldx #16
    ldy #2
    jsr set_cell
    ldx #23
    ldy #2
    jsr set_cell
    ldx #16
    ldy #3
    jsr set_cell
    ldx #17
    ldy #3
    jsr set_cell
    ldx #18
    ldy #3
    jsr set_cell
    ldx #19
    ldy #3
    jsr set_cell
    ldx #20
    ldy #3
    jsr set_cell
    ldx #21
    ldy #3
    jsr set_cell
    ldx #22
    ldy #3
    jsr set_cell
    ldx #23
    ldy #3
    jsr set_cell


    ; todo generate random cells
    ; todo connect random cells via corridors
done:
    rts

; make cell at x,y with size in accumulator
; clobbers: tmp and all registers
set_cell:
    ; remember cell size & x value
    pha
    txa
    pha
    ; get byte offset & transfer to y
    jsr get_byte_offset
    tay
    ; get byte mask
    pla
    tax
    jsr get_byte_mask
    ora tiles, y
    sta tiles, y

    ; set tmp to cell size
    pla
    sta tmp
    ; todo generate cell y
    ; todo generate cell x

    rts

; set bit at x, y
; clobbers: tmp and all registers
set_bit:
    jsr get_byte_offset

; get byte offset for x & y
; out: y * 4 + x
; clobbers: tmp and all registers
get_byte_offset:
get_byte_y_offset:
    ; use tmp var for y comparisons
    sty tmp
    lda #00
    tay
get_byte_y_loop:
    cpy tmp
    beq get_byte_x_offset
    iny
    clc
    adc #$04 ; add 4 for every y value
    jmp get_byte_y_loop
    ; now we need to add x to result
get_byte_x_offset:
    ; remember result
    pha
    ; use tmp var for x comparisons
    txa
    sta tmp
    ; get result from stack, and put result in x for incrementing
    pla
    tax
    lda #00
get_byte_x_loop:
    ; check if x is within next +8 bits
    clc
    adc #$08
    cmp tmp
    beq get_byte_continue_x_loop
    bcs get_byte_offset_done
get_byte_continue_x_loop:
    inx
    jmp get_byte_x_loop ; continue loop if less than target
get_byte_offset_done:
    ; now we're done, transfer result to accum
    txa
    rts

; get byte mask for x
; out: byte mask
; clobbers: x
get_byte_mask:
    txa
    ; subtract 8 from x until we get < 8 (representing a bit from 0-7)
get_byte_mask_loop:
    cmp #$08
    bcc get_byte_mask_done
    sec
    sbc #$08
    jmp get_byte_mask_loop
get_byte_mask_done:
    ; accum is a bit from 0-7, put in tmp for comparison
    sta tmp
    ; increment tmp for comparison
    inc tmp
    lda #$00 ; byte mask
    tax      ; counter
    sec      ; for shift operation
get_byte_mask_shift:
    ; rotate byte mask until tmp is reached
    ror
    inx
    cpx tmp
    bcc get_byte_mask_shift
    rts

; the tiles bytes are arranged like so (by x & y):
;
; 0     00000000 00000000 00000000 00000000
; 32    01000000 00000000 00000000 00000000
; 64    00000000 00000000 00000000 00000000
; 96    00000100 10000000 00000000 00000000
; 128   00000000 00000000 00000000 00000000
;
; bit at x,y of 1,1 would be at position 33
; bit at x,y of 5,3 would be at position 101
;
; to get to position, add 32 for every y then 1 for every x

.endproc

