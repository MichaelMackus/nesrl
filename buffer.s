; see: https://wiki.nesdev.com/w/index.php/The_frame_and_NMIs#Buffer_Formats
;
;   byte    0 = length of data (0 = no more data)
;   byte    1 = high byte of target PPU address
;   byte    2 = low byte of target PPU address
;   byte    3 = update with PPUCTRL mask
;   bytes 4-X = the data to draw (number of bytes determined by the length)
; 
; If the drawing buffer contains the following data:
; NOTE: this doesn't have the additional byte 3 above
; 
;  05 20 16 CA AB 00 EF 05 01 2C 01 00 00 
;   | \___/ \____________/  | \___/  |  |
;   |   |         |         |   |    |  |
;   |   |         |         |   |    |  length (0, so no more)
;   |   |         |         |   |    byte to copy
;   |   |         |         |   PPU Address $2C01
;   |   |         |         length=1
;   |   |         bytes to copy
;   |   PPU Address $2016
;   length=5

.include "global.inc"

.export buffer_num
.export buffer_num_tens
.export buffer_num_hex
.export buffer_str
.export render_buffer

.segment "ZEROPAGE"

max_buffer_size = 160
draw_buffer:  .res max_buffer_size
str_pointer:  .res 2 ; pointer for buffering of strings
buffer_index: .res 1 ; current index for buffering, >0 if batch buffer mode
tiles_drawn:  .res 1 ; amount of tiles drawn

tmp: .res 1

; max amount of tiles before we end drawing this frame
tiles_per_frame = 64

.segment "CODE"

; get next index for drawing
;
; updates: y with next available index
; preserves: x
.proc next_index
    lda #0
    tay
loop:
    lda draw_buffer, y ; length to draw
    bne update_ppuaddr
    ; length is 0, so we're done drawing
    rts
update_ppuaddr:
    sta tmp
    ; for length
    iny
    ; set ppu addr, high byte then low byte
    iny
    iny
    ; for PPUCTRL mask
    iny
    ; add tmp to y for next index
    tya
    clc
    adc tmp
    tay
    jmp loop
.endproc

; Append string at str_pointer to draw_buffer.
;
; y: index of current draw buffer pos
; out: length of written string
; clobbers: x
.proc buffer_str
    ; index str with y, so we can use indirect indexed addressing mode
    tya
    tax
    ldy #0
str_loop:
    ; load first char of str
    lda (str_pointer), y
    beq done ; done?
    ; load tile index for char
    jsr get_str_tile
    ; update draw buffer, and increment
    sta draw_buffer, x
    inx
    iny
    jmp str_loop
done:
    ; restore y and return write length
    sty tmp
    txa
    tay
    lda tmp
    rts
.endproc

; add number to draw_buffer
;
; in: number (only supports 0-99 for now)
; y: index of current draw buffer pos
; clobbers: x
.proc buffer_num
    ; first, render tens place for number
    ldx #0
    stx tmp
    inc tmp
    cmp #10
    bcc render_ones
    jsr buffer_num_tens
    inc tmp
render_ones:
    jsr get_num_tile
    sta draw_buffer, y
    iny
    ; return length of written number
    lda tmp
    rts
.endproc

; add tens place of number to draw_buffer
;
; in: number
; y: index of current draw buffer pos
; clobbers: x
.proc buffer_num_tens
    cmp #10
    bcc render_space
    ldx #0
tens_loop:
    cmp #10
    bcc render_tens
    sec
    sbc #10
    inx
    jmp tens_loop
render_tens:
    pha ; remember ones
    txa
    jsr get_num_tile
    sta draw_buffer, y
    iny
    ; now, render ones place
    pla
    rts
render_space:
    pha ; remember ones
    lda #0
    sta draw_buffer, y
    iny
    ; now, render ones place
    pla
    rts
.endproc

; add hex number to draw_buffer (for debugging)
;
; in: number
; y: index of current draw buffer pos
; clobbers: x
.proc buffer_num_hex
    ; first, render tens place for number
    ldx #0
    cmp #10
    bcc render_ones_padded
sixteens_loop:
    cmp #$10
    bcc render_sixteens
    sec
    sbc #$10
    inx
    jmp sixteens_loop
render_sixteens:
    pha ; remember ones
    txa
    jsr get_hex_tile
    sta draw_buffer, y
    iny
    ; now, render ones place
    pla
render_ones:
    jsr get_hex_tile
    sta draw_buffer, y
    iny
    rts
render_ones_padded:
    pha
    lda #$0
    jsr get_hex_tile
    sta draw_buffer, y
    iny
    pla
    jmp render_ones
.endproc

; Render the draw buffer.
; Only call this during vblank or when rendering is disabled. Caller will need
; to update PPUSCROLL ($2005) after rendering buffer, since ppu latch is reset.
;
; NOTE: every time we append draw buffer, we need to write length $00 after our
; bytes to ensure we don't re-draw old data.
;
; clobbers: all registers
.proc render_buffer
    draw_length = tmp
    lda #0
    tax
    sta tiles_drawn
    ldy buffer_index
loop:
    lda draw_buffer, y ; length to draw
    bne update_ppuaddr
    ; length is 0, so we're done drawing
    ; reset draw_buffer to length 0
    lda #0
    sta draw_buffer
    sta buffer_index ; stop batch buffer mode
    rts
update_ppuaddr:
    sta draw_length
    iny
    ; reset ppu latch
    bit $2002
    ; set ppu addr, high byte then low byte
    lda draw_buffer, y
    sta $2006
    iny
    lda draw_buffer, y
    sta $2006
    iny
    ; set PPUCTRL bit
    lda draw_buffer, y
    ora #%10000000 ; default
    sta $2000
    iny
vram_loop:
    cpx draw_length
    beq next
    ; now we can write the actual buffer data to vram
    lda draw_buffer, y
    sta $2007
    inx
    iny
    ; check for end of batch buffering
    ; todo do this outside loop (add draw_length), not going to work here due to ppuaddr
    ; todo change to max_bytes_per_frame
    inc tiles_drawn
    lda tiles_drawn
    cmp #tiles_per_frame
    bcs update_buffer_index
    jmp vram_loop
next:
    lda #0
    tax
    jmp loop
update_buffer_index:
    sty buffer_index
    rts
.endproc
