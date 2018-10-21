.include "global.inc"

.export render
.export render_escape
.export render_win

.segment "ZEROPAGE"

tmp: .res 1

screen_width  = 32
screen_height = 30
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
    lda #$00
    sta base_nt
    sta scroll
    sta scroll + 1
    lda #$20
    sta ppu_addr
    lda #$00
    sta ppu_addr + 1

    ; update PPUADDR
    bit $2002
    lda ppu_addr
    sta $2006
    lda ppu_addr + 1
    sta $2006

draw_dungeon:
    ; start x = player's xpos - 16
    ; end   x = player's xpos + 16
    lda mobs + Mob::coords + Coord::xcoord
    asl ; multiply by 2 for metax
    cmp #screen_width / 2
    bcc force_x
    sec
    sbc #screen_width / 2
    sta startx
    sta metaxpos
    lda mobs + Mob::coords + Coord::xcoord
    asl ; multiply by 2 for metax
    clc
    adc #screen_width / 2
    sta endx
set_y:
    ; start y = player's ypos - 15
    ; end   y = player's xpos + 15
    lda mobs + Mob::coords + Coord::ycoord
    asl ; multiply by 2 for metay
    cmp #screen_width / 2
    bcc force_y
    sec
    sbc #screen_height / 2
    sta metaypos
    lda mobs + Mob::coords + Coord::ycoord
    asl ; multiply by 2 for metay
    clc
    adc #screen_height / 2
    sta endy
    jmp y_repeat
force_x:
    lda #0
    sta startx
    sta metaxpos
    lda #screen_width
    sta endx
    jmp set_y
force_y:
    lda #0
    sta metaypos
    lda #screen_height
    sta endy
; loop through x and y
y_repeat:
    lda metaypos
    cmp endy
    beq tiles_done ; greater than or equal
x_repeat:
    jsr get_bg_metatile
    sta $2007
    jmp continue_loop
render_bg:
    lda #$00
    sta $2007

continue_loop:
    inc metaxpos
    lda metaxpos
    cmp endx
    beq continue_y ; greater than or equal
    jmp x_repeat
continue_y:
    inc metaypos
    lda startx
    sta metaxpos
    jmp y_repeat
; todo render status messages
tiles_done:
;    ; hp
;    bit $2002
;    lda #$23
;    sta $2006
;    lda #$21
;    sta $2006
;    lda #<txt_hp
;    sta str_pointer
;    lda #>txt_hp
;    sta str_pointer+1
;    jsr render_str
;    ; spacing to line up with dlvl
;    lda #$00
;    sta $2007
;    sta $2007
;    ; render hp
;    jsr buffer_hp
;
;    ; dlvl
;    bit $2002
;    lda #$23
;    sta $2006
;    lda #$61
;    sta $2006
;    lda #<txt_dlvl
;    sta str_pointer
;    lda #>txt_dlvl
;    sta str_pointer+1
;    jsr render_str
;    ; render current dlevel
;    lda dlevel
;    jsr render_num
;
;    ; buffer our messages, todo this shouldn't be necessary
;    jsr buffer_messages
;
;    ; render the buffer & update our sprites
;    jsr render_buffer

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
