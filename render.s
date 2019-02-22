.include "global.inc"

.export render
.export render_escape
.export render_win

.segment "ZEROPAGE"

startx: .res 1
endx:   .res 1
endy:   .res 1

.segment "CODE"

; render the dungeon level on the current screen
.proc render
    lda nmis
wait_nmi:
    ; wait for nmi
    cmp nmis
    beq wait_nmi
generate_ppu:
    ; turn off rendering
    lda #%00000000 ; note: need second bit in order to show background on left side of screen
    sta $2001

    ; initialize defaults for scrolling functionality
    jsr init_buffer

    ; initialize scroll offsets
    jsr update_screen_offsets

    ; update y-scroll to player Y offset
    ldy #0
scroll_loop:
    cpy #vertical_bound
    bcc skip_scroll
    beq skip_scroll
    cpy #(max_height*2) - (screen_height-vertical_bound)
    beq update_scroll
    bcs skip_scroll
update_scroll:
    jsr scroll_down ; scroll down 8 pixels
    jsr scroll_down ; scroll down 8 pixels, 16 pixels total (1 metatile)
    jsr iny_ppu ; increase top of PPUADDR 8 pixels
    jsr iny_ppu ; increase top of PPUADDR 8 pixels, 16 pixels total (1 metatile)
skip_scroll:
    iny
    iny
    tya
    lsr ; divide by 2 to compare to player y-pos
    cmp mobs + Mob::coords + Coord::ycoord ; check that we're at the mob ycoord
    ; end loop once y is *greater* than ycoord
    bcc scroll_loop
    beq scroll_loop
    
    ; clear previous nametable
    bit $2002
    lda #$20
    sta $2006
    lda #$00
    sta $2006
    lda #$00
    tax
    tay
clear_page:
    sta $2007
    inx
    cpx #$FF
    bne clear_page
    sta $2007
    iny
    cpy #16 ; 16 total pages in NT
    bne clear_page

    ; render dungeon
    jsr buffer_seen
    jsr render_buffer

    ; render statusbar
    jsr buffer_status_text
    jsr buffer_status
    jsr buffer_status_end
    jsr render_buffer

render_done:
    jsr update_sprites

    lda nmis
render_wait:
    cmp nmis
    beq render_wait

    ; tell PPU to render BG & sprites
    lda #%00011010 ; note: need second bit in order to show background on left side of screen
    sta $2001

    rts
.endproc

.proc render_death
    ; offset PPUADDR
    jsr iny_ppu
    jsr iny_ppu
    jsr iny_ppu
    jsr iny_ppu
    jsr iny_ppu
    jsr iny_ppu
    jsr iny_ppu
    jsr iny_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    lda #<txt_gameover
    sta str_pointer
    lda #>txt_gameover
    sta str_pointer+1
    ; start buffer
    lda #9 ; todo strlen func
    sta draw_length
    lda base_nt
    sta ppu_ctrl
    jsr start_buffer
    jsr append_str
    ; finish buffer
    lda #$00
    sta draw_buffer, y
    rts
.endproc

.proc render_escape
    ; offset PPUADDR
    jsr iny_ppu
    jsr iny_ppu
    jsr iny_ppu
    jsr iny_ppu
    jsr iny_ppu
    jsr iny_ppu
    jsr iny_ppu
    jsr iny_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    lda #<txt_escape
    sta str_pointer
    lda #>txt_escape
    sta str_pointer+1
    ; start buffer
    lda #12 ; todo strlen func
    sta draw_length
    lda base_nt
    sta ppu_ctrl
    jsr start_buffer
    jsr append_str
    ; finish buffer
    lda #$00
    sta draw_buffer, y
    rts
.endproc

.proc render_win
    ; offset PPUADDR
    jsr iny_ppu
    jsr iny_ppu
    jsr iny_ppu
    jsr iny_ppu
    jsr iny_ppu
    jsr iny_ppu
    jsr iny_ppu
    jsr iny_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    jsr inx_ppu
    lda #<txt_win
    sta str_pointer
    lda #>txt_win
    sta str_pointer+1
    ; start buffer
    lda #8 ; todo strlen func
    sta draw_length
    lda base_nt
    sta ppu_ctrl
    jsr start_buffer
    jsr append_str
    ; finish buffer
    lda #$00
    sta draw_buffer, y
    rts
.endproc

; render padded num 0-99
; in: number
; clobbers: x and y
.proc render_num
    cmp #10
    bcc render_padded
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
    tay
    txa
    jsr get_num_tile
    sta $2007
    ; now, render ones place
    tya
render_ones:
    jsr get_num_tile
    sta $2007
    rts
render_padded:
    tax
    lda #$00
    sta $2007
    txa
    jmp render_ones
.endproc

; render string constant to screen
; in: address to start of str
; clobbers: y
.proc render_str
    ldy #0
loop:
    lda (str_pointer), y
    beq done
    jsr get_str_tile
    sta $2007
    iny
    jmp loop
done:
    rts
.endproc

.segment "RODATA"

; end messages
txt_win:      .asciiz "You win!"
txt_escape:   .asciiz "You escaped!"
txt_death:    .asciiz "You died!"
txt_gameover: .asciiz "Game Over"
