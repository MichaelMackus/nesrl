.include "global.inc"

.export generate

.segment "ZEROPAGE"

tmp:         .res 1 ; temporary variable for generation code
visited:     .res 1 ; visited number of cells for generation
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

; todo connect random cells via corridors
; todo perhaps look into random maze generator (with length limits & no repeats) as way to make more interesting
generate_corridors:
    ; pick start cell at random
    jsr d12
    sec
    sbc #$01
    jsr get_byte_offset

    ; increase offset to center y of cell todo figure out a more random way
    clc
    adc #$0C
    tay
    ; x offset is used to count increase in y offset
    ldx #$0
    stx visited

    ; push y to stack for loop
    tya
    pha

generate_corridors_loop:
    pla
    tay
    jsr generate_corridor
    tya
    pha
    jsr update_visited
    ; keep going until all cells visited
    cmp #12
    bne generate_corridors_loop
    pla

; generate 12 dungeon cells (rooms)
generate_cells:
    ; todo generate random cell dimensions
    lda #4
    sta cell_width
    sta cell_height
    ; loop through max cells 
    ldy #0
generate_cells_loop:
    cpy #12
    beq done_generating
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
    jmp generate_cells_loop

done_generating:
    rts

.endproc

generate_corridor:
    ; pick random direction
    jsr d4
    sta tmp ; save direction to tmp
    cmp #1
    beq fill_center
    cmp #2
    beq fill_right
    cmp #3
    beq fill_center
fill_left:
    lda #%11110000
    jmp fill_corridor
fill_right:
    lda #%00011111
    jmp fill_corridor
fill_center:
    lda #%00010000 ; center byte mask
fill_corridor:
    ; fill byte mask in direction
    ora tiles, y
    sta tiles, y
    ; move in direction
    lda tmp
    cmp #1
    beq move_up
    cmp #2
    beq move_right
    cmp #3
    beq move_down
move_left:
    ; get quadrant and store in tmp
    tya
    jsr get_x
    sta tmp
    ; divide x by 4 (ensure we're not at left edge)
    lda #%00000000
    lsr tmp
    ror
    lsr tmp
    ror
    ; if remainder of division is zero, skip moving
    beq move_done
    ; now we know it is not zero, move to left
    dey ; decrement byte offset
    lda #%00011111
    ora tiles, y
    sta tiles, y
    jmp move_done
move_right:
    ; get quadrant and store in tmp
    tya
    jsr get_x
    sta tmp
    ; divide x by 4 (ensure we're not at left edge)
    lda #%00000000
    lsr tmp
    ror
    lsr tmp
    ror
    ror
    ror
    ror
    ror
    ror
    ror
    ; if remainder of division is 3, skip moving
    cmp #3
    beq move_done
    ; now we know it is not zero, move to right
    iny ; increment byte offset
    lda #%11110000
    ora tiles, y
    sta tiles, y
    jmp move_done
move_up:
    ; initialize counter for loop
    ldx #$00
move_up_loop:
    ; compare increment to see if we're done
    cpx #$08
    beq move_done
    ; fill center for current offset
    lda #%00010000 ; center byte mask
    ora tiles, y
    sta tiles, y
    ; compare y to ensure we're not at edge
    tya
    jsr get_y
    cmp #$00
    beq move_up_reset
    ; we're not at edge, so decrement offset, counter, and continue loop
    tya
    sec
    sbc #$04
    tay
    inx
    jmp move_up_loop
move_up_reset:
    ; reset y to +12
    tya
    clc
    adc #$0C
    tay
    jmp move_done
move_down:
    ; initialize counter for loop
    ldx #$00
move_down_loop:
    ; compare increment to see if we're done
    cpx #08
    beq move_done
    ; fill center for current offset
    lda #%00010000 ; center byte mask
    ora tiles, y
    sta tiles, y
    ; compare y to ensure we're not at edge
    tya
    jsr get_y
    cmp #23
    beq move_down_reset
    ; we're not at edge, so increment offset, counter, and continue loop
    tya
    clc
    adc #$04
    tay
    inx
    jmp move_down_loop
move_down_reset:
    ; reset y to -16
    tya
    sec
    sbc #$10
    tay
move_done:
    rts


; generate cell within quadrant
; in: quadrant index
; clobbers: tmp and all registers
; todo not generating in quadrant
generate_cell:
    ; todo increment x & y value

    ; get byte offset & transfer to y
    jsr get_byte_offset
    tay

    ; todo fixme get byte mask & set wall
    ;ldx #4
    ;jsr get_byte_mask
    lda #%01111000
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

; get visited cell count
; out: visited cells
; clobbers: tmp and all registers
update_visited:
    lda #$00
    sta visited
    tax
update_visited_loop:
    txa
    pha
    jsr quadrant_visited
    bne next_visited
    ; the quadrant was visited, increment visited
    inc visited
next_visited:
    pla
    tax
    inx
    cpx #12
    bne update_visited_loop
    lda visited
    rts

; check if quadrant visited
; in: quadrant
; out: 0 if visited
; clobbers: tmp and all registers
quadrant_visited:
    jsr get_byte_offset
    tay
    lda #$00
    tax
quadrant_visited_loop:
    ; and byte at offset with mask
    lda tiles, y
    and #%11111111
    bne quadrant_visited_success
    ; now we increment offset by 4 (get next y)
    tya
    clc
    adc #4
    tay
    inx
    ; end condition
    cpx #8
    bne quadrant_visited_loop

    ; failure
    lda #1
    rts
quadrant_visited_success:
    lda #0
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

; get x pos for offset
; in: offset
; out: x pos
; clobbers: tmp
get_x:
    sta tmp
    lda #%00000000
    lsr tmp
    ror
    lsr tmp
    ror
    ; fill in rest of zeroes
    ror
    ror
    ror
    ror
    ror
    ror
    rts

; get y pos for offset
; in: offset
; out: y pos
get_y:
    ; divide by 4 to get y pos
    lsr
    lsr
    rts

; get quadrant for offset y
; in: offset
; out: quadrant
; clobbers: tmp and all registers
; todo fixme the rol stuff is messed up, bits will be reversed
get_quadrant:
    tay
    lda #0
    sta tmp
    tya
    ; divide by 32, storing remainder in tmp
    lsr
    rol tmp
    lsr
    rol tmp
    lsr
    rol tmp
    lsr
    rol tmp
    lsr
    rol tmp
    ; decrement division result by 1 to get index
    tay
    dey
    ; now a has y value and tmp has remainder

    ; ; divide remainder by 4
    ; lda tmp
    ; ldx #$0
    ; stx tmp
    ; lsr
    ; rol tmp
    ; lsr
    ; rol tmp

    ; remainder of division should be x offset
    ; result is 4 * y + x
    tya
    asl
    asl
    clc
    adc tmp

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
; 00000000 00000001 00000010 00000011
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
; 00000100 00000101 00000110 00000111
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
; 00001000 00001001 00001010 00010111
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

