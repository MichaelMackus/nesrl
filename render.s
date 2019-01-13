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
    ; inc y twice for scroll amount (1 metatile)
    iny
    iny
    tya
    lsr ; divide by 2 to compare to player y-pos
    cmp mobs + Mob::coords + Coord::ycoord ; check that we're at the mob ycoord
    bne scroll_loop
    
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
    jsr buffer_status
    jsr render_buffer

render_done:
    jsr update_sprites

    lda nmis
render_wait:
    cmp nmis
    beq render_wait

    ; update the NT page
    lda #%10000000
    ora base_nt
    sta $2000
    ; update scrolling
    bit $2002
    lda scroll
    sta $2005
    lda scroll + 1
    sta $2005

    ; tell PPU to render BG & sprites
    lda #%00011010 ; note: need second bit in order to show background on left side of screen
    sta $2001

    rts
.endproc

.proc render_death
    ; wait for nmi
    lda nmis
waitnmi:
    cmp nmis
    beq waitnmi
    ; prep ppu for first nametable write
    bit $2002
    lda #$21
    sta $2006
    lda #$8B
    sta $2006
    ; You died
    lda #<txt_death
    sta str_pointer
    lda #>txt_death
    sta str_pointer+1
    jsr render_str
    ; Game Over
    ; prep ppu for next nametable write
    bit $2002
    lda #$22
    sta $2006
    lda #$0B
    sta $2006
    ; You died
    lda #<txt_gameover
    sta str_pointer
    lda #>txt_gameover
    sta str_pointer+1
    jsr render_str
    ; done
    bit $2002
    lda #$00
    sta $2005
    sta $2005
    rts
.endproc

.proc render_escape
    ; wait for nmi
    lda nmis
waitnmi:
    cmp nmis
    beq waitnmi
    ; prep ppu for first nametable write
    bit $2002
    lda #$21
    sta $2006
    lda #$CA
    sta $2006
render_escape_message:
    ; You escaped!
    lda #<txt_escape
    sta str_pointer
    lda #>txt_escape
    sta str_pointer+1
    jsr render_str
    ; done
    bit $2002
    lda #$00
    sta $2005
    sta $2005
    rts
.endproc

.proc render_win
    ; wait for nmi
    lda nmis
waitnmi:
    cmp nmis
    beq waitnmi
    ; prep ppu for first nametable write
    bit $2002
    lda #$21
    sta $2006
    lda #$CC
    sta $2006
    ; You win!
    lda #<txt_win
    sta str_pointer
    lda #>txt_win
    sta str_pointer+1
    jsr render_str
    ; done
    bit $2002
    lda #$00
    sta $2005
    sta $2005
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

; status
txt_hp:     .asciiz "hp"
txt_lvl:    .asciiz "lvl"
txt_dlvl:   .asciiz "dlvl"
; end messages
txt_win:      .asciiz "You win!"
txt_escape:   .asciiz "You escaped!"
txt_death:    .asciiz "You died!"
txt_gameover: .asciiz "Game Over"
