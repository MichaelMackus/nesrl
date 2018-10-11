.include "global.inc"

.export generate

.segment "ZEROPAGE"

max_generate = 10
tmp:         .res 1 ; temporary variable for generation code
cell_width:  .res 1
cell_height: .res 1

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
    lda #4
    sta cell_width
    sta cell_height
    ; set sample cells for now
    ldx #0
    ldy #1
    jsr set_cell
    ldx #8
    ldy #8
    jsr set_cell
    ldx #16
    ldy #8
    jsr set_cell


    ; todo generate random cells
    ; todo connect random cells via corridors
done:
    rts

; make cell at x,y with size in accumulator
; clobbers: tmp and all registers
set_cell:
    ; remember x value
    txa
    pha
    ; get byte offset & transfer to y
    jsr get_byte_offset
    tay

    ; get byte mask & set wall
    pla
    tax
    jsr get_byte_mask
    sta tmp

    ; todo need to handle empty space in middle

    ; loop until cell height reached
    ldx #0
set_cell_loop:
    inx
    tya
    clc
    adc #$04 ; increment byte offset for y
    tay
    lda tmp
    ora tiles, y
    sta tiles, y

    cpx cell_height
    bne set_cell_loop

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
; clobbers: accum
get_byte_mask:
    txa
    pha ; remember x
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
    cpx cell_width
    bcc get_byte_mask_shift_sec
get_byte_mask_shift_continue:
    cpx tmp
    bcc get_byte_mask_shift
    ; restore registers
    sta tmp ; remember result
    pla
    tax
    lda tmp
    rts
get_byte_mask_shift_sec:
    ; set carry since we're not at width yet
    sec
    jmp get_byte_mask_shift

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

