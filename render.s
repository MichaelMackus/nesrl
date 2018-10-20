.include "global.inc"

.export render
.export render_escape
.export render_win

.segment "ZEROPAGE"

tmp: .res 1

.segment "CODE"

; render the dungeon level
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

    bit $2002
    ; prep ppu for first nametable write
    lda #$20
    sta $2006
    lda #$00
    sta $2006
    ldx #$00 ; counter for background sprite position
    ldy #$00
; clear first line
clear_line:
    sta $2007
    inx
    cpx #$20
    bne clear_line
    ldx #$00
; loop through x and y
y_repeat:
    cpy #max_height ; +1 to ensure we clear first line
    beq render_status
x_repeat:
    stx xpos
    sty ypos
    ldy #0
    jsr can_see
    bne render_bg
    jsr get_bg_tile
    sta $2007
    jmp continue_loop
render_bg:
    lda #$00
    sta $2007
continue_loop:
    ldx xpos
    ldy ypos
    inx
    cpx #max_width
    bne x_repeat
    iny
    ldx #$00
    jmp y_repeat
; render status messages
render_status:
    ; hp
    bit $2002
    lda #$23
    sta $2006
    lda #$21
    sta $2006
    lda #<txt_hp
    sta str_pointer
    lda #>txt_hp
    sta str_pointer+1
    jsr render_str
    ; spacing to line up with dlvl
    lda #$00
    sta $2007
    sta $2007
    ; render hp
    jsr buffer_hp

    ; dlvl
    bit $2002
    lda #$23
    sta $2006
    lda #$61
    sta $2006
    lda #<txt_dlvl
    sta str_pointer
    lda #>txt_dlvl
    sta str_pointer+1
    jsr render_str
    ; render current dlevel
    lda dlevel
    jsr render_num

    ; buffer our messages, todo this shouldn't be necessary
    jsr buffer_messages

    ; render the buffer & update our sprites
    jsr render_buffer
    jsr update_sprites

    lda nmis
render_done:
    cmp nmis
    beq render_done

    ; update scrolling
    bit $2002
    lda #$00
    sta $2005
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
