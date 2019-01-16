; buffer abstraction functions

; in: dividend
; x: divisor
; out: remainder of modulus
.import mod

; see: buffer.s
.importzp draw_buffer ; see: buffer.s
.importzp ppu_addr ; see: math.s
.importzp a1 ; tmp var
.import next_index ; see: buffer.s
.import iny_ppu_nt ; see: math.s
.import inx_ppu_nt ; see: math.s

.export update_nt_boundary
.export start_buffer
.export append_buffer
.export calculate_ppu_pos
.export calculate_ppu_col
.export calculate_ppu_row
.exportzp cur_tile
.exportzp draw_y
.exportzp draw_length
.exportzp ppu_pos
.exportzp ppu_ctrl
.exportzp buffer_start

.segment "ZEROPAGE"

cur_tile:       .res 1
draw_y:         .res 1 ; current draw buffer index
draw_length:    .res 1
ppu_pos:        .res 1 ; for ppu_at_attribute procedure
ppu_ctrl:       .res 1 ; for checking vram increment (next NT or next attribute?)
buffer_start:   .res 1 ; start index for draw buffer

.segment "CODE"

.proc update_nt_boundary
    ; check to prevent attributes update (scrolling up or down)
    jsr ppu_at_attribute
    beq update_attribute
    ; check if we're past nametable boundary (scrolling left or right)
    jsr ppu_at_next_nt
    beq update_nt
    ; nope, continue
    rts
update_nt:
    ; we're past NT boundary, update buffer and continue
    jmp buffer_next_nt ; updates draw buffer and draw_y
update_attribute:
    jmp buffer_next_vertical_nt

; updates draw_buffer to next NT
; updates previously written draw_buffer's length
; NOTE: should only happen once per update cycle
.proc buffer_next_nt
    ; update old length to current loop index
    ldy buffer_start
    lda cur_tile
    sta draw_buffer, y

    ; write new draw length
    ldy draw_y
    lda draw_length
    sec
    sbc cur_tile
    sta draw_buffer, y
    iny

    ; remember origin
    lda ppu_addr
    pha
    lda ppu_addr + 1
    pha

    ; switch to start column of next nt
    jsr inx_ppu_nt
    lda ppu_addr+1
    ldx #$20
    jsr mod
    sta a1
    lda ppu_addr+1
    sec
    sbc a1
    sta ppu_addr+1

    ; write new ppu address
    lda ppu_addr
    sta draw_buffer, y
    iny
    lda ppu_addr + 1
    sta draw_buffer, y
    iny

    ; restore previous ppu address for next buffer update
    pla
    sta ppu_addr + 1
    pla
    sta ppu_addr

    ; write vram increment
    lda ppu_ctrl
    sta draw_buffer, y
    iny

    ; update ppu_pos
    lda #0
    sta ppu_pos

    sty draw_y
    rts
.endproc

; updates draw_buffer to next NT
; updates previously written draw_buffer's length
; NOTE: should only happen once per update cycle
.proc buffer_next_vertical_nt
    ; update old length to current loop index
    ldy buffer_start
    lda cur_tile
    sta draw_buffer, y

    ; write new draw length
    ldy draw_y
    lda draw_length
    sec
    sbc cur_tile
    sta draw_buffer, y
    iny

    ; remember origin
    lda ppu_addr
    pha
    lda ppu_addr + 1
    pha

    ; switch to start page of next nt
    jsr iny_ppu_nt
    lda ppu_addr
    ldx #4
    jsr mod
    sta a1
    lda ppu_addr
    sec
    sbc a1
    sta ppu_addr
    ; switch to start row of next nt
    lda ppu_addr + 1
    ldx #$20
    jsr mod
    sta ppu_addr + 1

    ; write new ppu address
    lda ppu_addr
    sta draw_buffer, y
    iny
    lda ppu_addr + 1
    sta draw_buffer, y
    iny

    ; restore previous ppu address for next buffer update
    pla
    sta ppu_addr + 1
    pla
    sta ppu_addr

    ; write vram increment
    lda ppu_ctrl
    sta draw_buffer, y
    iny
    
    ; update ppu_pos
    lda #0
    sta ppu_pos

    sty draw_y
    rts
.endproc
.endproc

; helper function to start the buffer
;
; uses ppu_addr for ppuaddress
; uses draw_length for length
; uses ppu_ctrl for ppuctrl
;
; updates buffer_start with start index, cur_tile, and ppu_pos
; updates y with position in buffer
.proc start_buffer
    jsr next_index
    ; save buffer_start for NT boundary check
    sty buffer_start
    ; initialize cur_tile for NT boundary check
    lda #0
    sta cur_tile
    lda draw_length
    sta draw_buffer, y
    iny
    ; ppuaddr
    lda ppu_addr
    sta draw_buffer, y
    iny
    lda ppu_addr + 1
    sta draw_buffer, y
    iny
    ; ppuctrl (vram increment)
    lda ppu_ctrl
    sta draw_buffer, y
    iny
    ; calculate the position in the PPU
    jsr calculate_ppu_pos
    rts
.endproc

; helper function to append to buffer
;
; a: tile to append
; y: index in buffer
;
; updates y with position in buffer
.proc append_buffer
    pha
    sty draw_y
    ; update ppu page if at NT boundary
    jsr update_nt_boundary
    ; update buffer
    ldy draw_y
    pla
    sta draw_buffer, y
    iny
    ; increment cur_tile & ppu_pos (for NT boundary check)
    inc cur_tile
    inc ppu_pos
    rts
.endproc

;
; functions related to calculating PPU NT attribute boundary
; todo should probably move to math.s
;

; calculate current position in PPU
.proc calculate_ppu_pos
    lda ppu_ctrl
    and #%00000100
    bne calculate_ppu_row
    jmp calculate_ppu_col
.endproc

.proc calculate_ppu_col
    ; calculate column
    lda ppu_addr + 1
    ldx #$20
    jsr mod
    sta ppu_pos
    rts
.endproc

; calculate current row in PPU for attribute check
.proc calculate_ppu_row
    ; 8 rows in first 3 pages
    lda ppu_addr
    ldx #4
    jsr mod
    ; result of *mod* is page number, multiply by 8 to get row
    asl
    asl
    asl
    sta ppu_pos
    ; mod low byte by 32 to get offset in page
    lda ppu_addr + 1
    ldx #$20
    jsr mod
    ; add result of *division* with row of page
    txa
    clc
    adc ppu_pos
    sta ppu_pos
    rts
.endproc

; test if ppu at attribute boundary (and we're writing vertically)
;
; from nesdev:
; Each attribute table, starting at $23C0, $27C0, $2BC0, or $2FC0, is arranged as an 8x8 byte array
; (64 bytes total)
.proc ppu_at_attribute
    ; only test when increasing vram vertically
    lda ppu_ctrl
    and #%00000100
    bne check
    ; not incrementing vertically
    jmp failure

check:
    ; ppu row 30 and 31 are attributes
    lda ppu_pos
    cmp #30
    bcc failure
    cmp #32
    bcc success
    jmp failure

success:
    lda #0
    rts
failure:
    lda #1
    rts
.endproc

; test if at NT boundary (and we're writing horizontally)
.proc ppu_at_next_nt
    ; only test when increasing vram horizontally
    lda ppu_ctrl
    and #%00000100
    beq check
    ; not incrementing vertically
    jmp failure

check:
    ; are we at end of NT?
    lda ppu_pos
    cmp #$20
    beq success
failure:
    ; nope
    lda #1
    rts
success:
    lda #0
    rts
.endproc
