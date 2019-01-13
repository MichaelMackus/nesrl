; procedures for buffering of statusbar

.include "global.inc"

status_ppuaddr = $2b60

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

    ; update ppuaddr with status ppuaddr
    lda #.hibyte(status_ppuaddr)
    sta ppu_addr
    lda #.lobyte(status_ppuaddr)
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

; write statusbar to buffer
.proc update_statusbar_buffer
    jsr next_index
    sty buffer_start
    lda #32
    sta draw_length
    sta draw_buffer, y
    iny
    lda ppu_addr
    sta draw_buffer, y
    iny
    lda ppu_addr + 1
    sta draw_buffer, y
    iny
    lda status_nt
    sta draw_buffer, y
    iny

tiles:
    ; HP
    lda txt_hp
    jsr get_str_tile
    sta draw_buffer, y
    iny
    lda txt_hp + 1
    jsr get_str_tile
    sta draw_buffer, y
    iny
    ; space
    lda #0
    sta draw_buffer, y
    iny
    lda mobs + Mob::hp
    ; tens place
    ldx #10
    jsr divide
    txa
    beq blank_tens
    jsr get_num_tile
    jmp write_tens
blank_tens:
    lda #$00
write_tens:
    sta draw_buffer, y
    iny
    ; mod by 10 to get ones place
    lda mobs + Mob::hp
    ldx #10
    jsr divide
    jsr get_num_tile
    sta draw_buffer, y
    iny

    ; todo finish status bar

    ; fill blank tiles
    ldx #5
    lda #$00
loop_fill_blank:
    sta draw_buffer, y
    iny
    inx
    cpx #32
    bne loop_fill_blank
    ; finish buffer
    sta draw_buffer, y
    iny
.endproc

    ; restore original ppu addr
    pla
    sta ppu_addr + 1
    pla
    sta ppu_addr

    rts
.endproc

.segment "RODATA"

txt_hp: .asciiz "HP"
