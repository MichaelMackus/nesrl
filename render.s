.include "global.inc"

.export render
.export render_escape
.export render_win
.export render_mobs

.segment "ZEROPAGE"

tmp: .byte 1

.segment "CODE"

; render string constant to screen
; in: address to start of str
; clobbers: x and tmp
.macro render_str str
    .local loop
    .local done
    ldx #0
loop:
    lda str, x
    beq done
    sec
    sbc #$20
    sta tmp
    lda #$00
    clc
    adc tmp
    sta $2007
    inx
    jmp loop
done:
.endmacro

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
; clear first line (not renderable)
clear_line:
    lda #$00
    sta $2007
    inx
    cpx #$20
    bne clear_line
    lda #$00
    tax
    tay
; loop through x and y
y_repeat:
    cpy #max_height
    beq render_status
x_repeat:
    stx xpos
    sty ypos
    jsr get_tile
    sta $2007
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
    bit $2002
    lda #$23
    sta $2006
    lda #$21
    sta $2006

    ; player hp
    render_str txt_hp
    lda #$00
    sta $2007
    lda #$00 ; extra space to line up with dlvl
    sta $2007
    jsr playerhp
    jsr render_padded_num
    ; todo max hp
    ; todo player stats, player lvl

    bit $2002
    lda #$23
    sta $2006
    lda #$61
    sta $2006

    ; dlvl
    render_str txt_dlvl
    lda #$00
    sta $2007
    lda dlevel
    jsr render_num

    jsr render_messages

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

; get tile index for x,y
; out: index in sprite sheet
; todo maybe we should render BG if sprite already on pos?
get_tile:
    ; todo then check item ??
check_stair:
    ; then check stair
    cpx up_x
    bne check_downstair
    cpy up_y
    beq up
check_downstair:
    cpx down_x
    bne tile
    cpy down_y
    beq down
tile:
    ; finally, display tile
    jsr get_byte_offset
    tay
    jsr get_byte_mask
    and tiles, y
    bne floor
bg:
    lda #$00
    rts
floor:
    lda #$82
    rts
up:
    lda #$3E
    rts
down:
    lda #$3F
    rts
player:
    lda #$A1
    rts


.endproc

.proc render_escape

    ; turn off rendering
    lda #%00000000 ; note: need second bit in order to show background on left side of screen
    sta $2001
    ; prep ppu for first nametable write
    lda #$20
    sta $2006
    lda #$00
    sta $2006
    ldx #$00 ; counter for background sprite position
    txa
    tay
    sta tmp
; clear line until middle of screen
render_escape_clear_y:
    cpy #$0F
    beq render_escape_message
render_escape_clear_x:
    lda #$00
    sta $2007
    inx
    cpx #$20
    bne render_escape_clear_x
    ldx #$00
    iny
    jmp render_escape_clear_y
render_escape_message:
    lda tmp
    bne render_escape_done
    ; You escaped!
    lda #$00
    sta $2007
    render_str txt_escape
    ; done
    inc tmp
    lda #$00
    tax
    tay
    jsr render_escape_clear_y
render_escape_done:
    lda #%00001010 ; note: need second bit in order to show background on left side of screen
    sta $2001
    rts

.endproc

.proc render_win

    ; turn off rendering
    lda #%00000000 ; note: need second bit in order to show background on left side of screen
    sta $2001
    ; prep ppu for first nametable write
    lda #$20
    sta $2006
    lda #$00
    sta $2006
    ldx #$00 ; counter for background sprite position
    txa
    tay
    sta tmp
; clear line until middle of screen
render_win_clear_y:
    cpy #$0F
    beq render_win_message
render_win_clear_x:
    lda #$00
    sta $2007
    inx
    cpx #$20
    bne render_win_clear_x
    ldx #$00
    iny
    jmp render_win_clear_y
render_win_message:
    lda tmp
    bne render_win_done
    ; You win!
    lda #$00
    sta $2007
    render_str txt_win
    ; done
    inc tmp
    lda #$00
    tax
    tay
    jsr render_win_clear_y
render_win_done:
    lda #%00001010 ; note: need second bit in order to show background on left side of screen
    sta $2001
    rts

.endproc

.proc render_mobs

; render the player sprite
render_mobs:
    lda #0
    tay
    tax
render_mobs_loop:
    jsr is_alive
    bne clear_mob
    jsr moby
    asl
    asl
    asl
    clc
    adc #$07 ; +8 (skip first row), and -1 (sprite data delayed 1 scanline)
    sta $0200, x
    jsr mobtype
    clc
    adc #$A1 ; first mob sprite index
    sta $0201, x
    lda #%00000000
    sta $0202, x
    jsr mobx
    asl
    asl
    asl
    sta $0203, x
continue_mobs_loop:
    txa
    clc
    adc #$04
    tax
    tya
    clc
    adc #mob_size
    tay
    cmp #mobs_size
    bne render_mobs_loop

done_mobs:
    rts

clear_mob:
    ; set sprite x and y to off screen
    lda #$FF
    sta $0200, x
    sta $0203, x
    jmp continue_mobs_loop

.endproc

.proc render_messages
    ; render message area
    lda #0
    tax
    sta tmp
    bit $2002
render_messages_loop:
    lda #$23
    sta $2006
    lda #$2C
    clc
    adc tmp
    sta $2006
    ; remember vars & render message
    lda tmp
    pha
    txa
    pha
    jsr render_message
    pla
    tax
    pla
    sta tmp
    ; end rendering message
    lda tmp
    clc
    adc #$20
    sta tmp
    txa
    clc
    adc #.sizeof(Message)
    tax
    cmp #.sizeof(Message)*max_messages
    bne render_messages_loop
    rts
render_message:
    lda messages, x
    cmp #Messages::hit
    beq render_hit
    cmp #Messages::hurt
    beq render_hurt
    cmp #Messages::kill
    beq render_kill
    cmp #Messages::heal
    beq render_heal
    cmp #Messages::scroll
    beq render_scroll
    cmp #Messages::quaff
    beq render_quaff
render_finish:
    rts
render_hit:
    ; todo amount
    render_str txt_hit
    rts
render_hurt:
    ; todo amount
    render_str txt_hurt
    rts
render_kill:
    render_str txt_kill
    rts
render_heal:
    ; todo amount
    render_str txt_heal
    rts
render_scroll:
    render_str txt_scroll
    rts
render_quaff:
    render_str txt_quaff
    rts
.endproc

; render num padded with space at front
; in: number
; clobbers: x, y, and tmp
render_padded_num:
    cmp #10
    bcs render_num
    tax
    lda #$00
    sta $2007
    txa
    jmp render_num

; render num 0-99
; in: number
; clobbers: x, y, and tmp
render_num:
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
    tay
    txa
    sta tmp
    lda #$10
    clc
    adc tmp
    sta $2007
    ; now, render ones place
    tya
render_ones:
    sta tmp
    lda #$10
    clc
    adc tmp
    sta $2007
    rts

.segment "RODATA"

; status
txt_hp:     .asciiz "hp"
txt_lvl:    .asciiz "lvl"
txt_dlvl:   .asciiz "dlvl"
; messages
txt_win:    .asciiz "You win!"
txt_escape: .asciiz "You escaped!"
txt_hit:    .asciiz "You hit it for XX"
txt_hurt:   .asciiz "You got hit for XX"
txt_kill:   .asciiz "It died!"
txt_heal:   .asciiz "You healed for XX"
txt_scroll: .asciiz "You read the scroll"
txt_quaff:  .asciiz "*gulp*" ; todo need asterisk
