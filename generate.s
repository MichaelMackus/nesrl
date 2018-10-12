.include "global.inc"

.export generate

.segment "ZEROPAGE"

tmp:         .res 1 ; temporary variable for generation code
cell_width:  .res 1
cell_height: .res 1

.segment "CODE"

; generate level
.proc generate

; todo why is this numeric constant not working for comparisons?
max_cells = 12

clear_tiles:
    ldx #$00 ; counter for background sprite position
    ldy #$00 ; counter for background bit index
    lda #$00
clear_loop:
    sta tiles, x
    inx
    ; todo figure out why I can't use constants
    cpx #96
    bne clear_loop

    ; todo generate random cell dimensions
    lda #4
    sta cell_width
    sta cell_height
    ; loop through max cells 
    ldy #0

; generate 12 dungeon cells (rooms)
generate_cells:
    cpy #12
    beq generate_corridors
    ; coin flip
    jsr d2
    cmp #1
    bne skip_cell
    ; success
    tya
    pha
    jsr generate_cell
    pla
    tay
skip_cell:
    iny
    jmp generate_cells

; todo connect random cells via corridors
; todo perhaps look into random maze generator (with length limits & no repeats) as way to make more interesting
generate_corridors:
    ; pick start cell at random
    jsr d12
    sec
    sbc #$01
    jsr get_byte_offset
    ; increase offset to center of cell todo figure out a more random way
    clc
    adc #$0B
    tay
    ; todo get byte mask for center
    ; todo pick random direction
    ;jsr d4
    ; todo fill byte mask in direction
    lda #%11111111
    ora tiles, y
    sta tiles, y
    ; todo keep filling until center of next cell
    ; todo keep going until all cells visited
done:
    rts

.endproc

; generate cell within quadrant
; in: quadrant index
; clobbers: tmp and all registers
; todo not generating in quadrant
generate_cell:
    ; todo increment x & y value

    ; get byte offset & transfer to y
    jsr get_byte_offset
    tay

    ; get byte mask & set wall
    ldx #0
    jsr get_byte_mask
    sta tmp

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

; get byte offset for quadrant
; in: quadrant
; out: offset to first byte in quadrant
; clobbers: tmp and all registers
get_byte_offset:
    ; todo fixme
    tax
    stx tmp
    lda #0
    tax
    tay
get_byte_offset_loop:
    cpy tmp
    beq get_byte_offset_done
    iny
    inx
    cpx #4
    beq get_byte_offset_incy
    clc
    adc #1   ; add 1 to offset (increasing in x quadrant)
    jmp get_byte_offset_loop
get_byte_offset_incy:
    ; increase y quadrant and clear x
    ldx #0
    clc
    adc #29  ; add 29 to offset (increasing in y quadrant)
    jmp get_byte_offset_loop
get_byte_offset_done:
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

; the tiles quadrants are arranged like so:
;
;    0        1        2        3
;
; 00000000 00000000 00000000 00000000
; 01000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000100 10000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000

;    4        5        6        7
;
; 00000000 00000000 00000000 00000000
; 01000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000100 10000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000

;    8        9        10       11
;
; 00000000 00000000 00000000 00000000
; 01000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000100 10000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
; 00000000 00000000 00000000 00000000
;
; bit at x,y of 1,1 would be in quadrant 0 with offset 0
; bit at x,y of 8,3 would be in quadrant 1 with offset 1
; bit at x,y of 1,9 would be in quadrant 4 with offset 32
; bit at x,y of 8,11 would be in quadrant 5 with offset 33

