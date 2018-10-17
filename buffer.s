; see: https://wiki.nesdev.com/w/index.php/The_frame_and_NMIs#Buffer_Formats
;
;   byte    0 = length of data (0 = no more data)
;   byte    1 = high byte of target PPU address
;   byte    2 = low byte of target PPU address
;   bytes 3-X = the data to draw (number of bytes determined by the length)
; 
; If the drawing buffer contains the following data:
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

.export next_index
.export buffer_num
.export buffer_str
.export render_buffer

.segment "ZEROPAGE"

; todo increase once we free up some zeropage mem
max_buffer_size = 120
draw_buffer: .res max_buffer_size
draw_length: .res 1
str_pointer: .res 2 ; pointer for buffering of strings

tmp: .res 1

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
    sty draw_length
    txa
    tay
    rts
.endproc

; add number to draw_buffer
;
; in: number (only supports 0-99 for now)
; y: index of current draw buffer pos
; clobbers: x
.proc buffer_num
    cmp #10
    bcc render_ones
    ; first, render tens place for number
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
render_ones:
    jsr get_num_tile
    sta draw_buffer, y
    iny
    rts
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
    lda #0
    tay
    tax
loop:
    lda draw_buffer, y ; length to draw
    bne update_ppuaddr
    ; length is 0, so we're done drawing
    ; reset draw_buffer to length 0
    lda #0
    sta draw_buffer
    rts
update_ppuaddr:
    sta tmp
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
vram_loop:
    cpx tmp
    beq next
    ; now we can write the actual buffer data to vram
    lda draw_buffer, y
    sta $2007
    inx
    iny
    jmp vram_loop
next:
    lda #0
    tax
    jmp loop
.endproc
