; procedures for buffering of statusbar

.include "global.inc"

status_ppuaddr = $2b80

.segment "ZEROPAGE"

has_status:  .res 1 ; set to 1 to flag for buffering status bar

.segment "CODE"

; initialize vars
.proc init_status
    lda #0
    sta has_status
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
    lda base_nt
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
    
    ; space
    lda #$00
    sta draw_buffer, y
    iny

    ; DLVL
    lda txt_dlvl
    jsr get_str_tile
    sta draw_buffer, y
    iny
    lda txt_dlvl + 1
    jsr get_str_tile
    sta draw_buffer, y
    iny
    lda txt_dlvl + 2
    jsr get_str_tile
    sta draw_buffer, y
    iny
    lda txt_dlvl + 3
    jsr get_str_tile
    sta draw_buffer, y
    iny
    ; space
    lda #0
    sta draw_buffer, y
    iny
    lda dlevel
    ; tens place
    ldx #10
    jsr divide
    txa
    beq blank_tensb
    jsr get_num_tile
    jmp write_tensb
blank_tensb:
    lda #$00
write_tensb:
    sta draw_buffer, y
    iny
    ; mod by 10 to get ones place
    lda dlevel
    ldx #10
    jsr divide
    jsr get_num_tile
    sta draw_buffer, y
    iny

    ; todo finish status bar

    ; fill blank tiles
    ldx #13
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

; buffer the end of statusbar
;
; clobbers: x and y
.proc buffer_status_end
    ; store original ppu addr
    lda ppu_addr
    pha
    lda ppu_addr + 1
    pha

    ; update ppuaddr with status ppuaddr
    lda #.hibyte(status_ppuaddr)
    sta ppu_addr
    lda #.lobyte(status_ppuaddr) + $20
    sta ppu_addr + 1

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
    lda base_nt
    sta draw_buffer, y
    iny

    ; fill blank tiles
    ldx #$00
    lda #$62
loop_tiles:
    ; HP
    sta draw_buffer, y
    iny
    inx
    cpx #32
    bne loop_tiles
    
    ; finish buffer
    lda #$00
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

txt_hp:   .asciiz "HP"
txt_lvl:  .asciiz "LVL"
txt_dlvl: .asciiz "DLVL"
