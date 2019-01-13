; functions related to PPU math & scrolling
; todo scrolling functions currently assume scroll is always on 8 pixel boundary

; in: dividend
; x: divisor
; out: remainder of modulus
.import mod

; see: buffer.s
.importzp draw_buffer
.importzp buffer_index
.importzp a1 ; tmp var

.exportzp cur_tile
.exportzp ppu_addr
.exportzp scroll
.exportzp base_nt
.exportzp draw_y
.exportzp draw_length
.exportzp ppu_pos
.exportzp ppu_ctrl
.exportzp buffer_start
.export init_buffer
.export scroll_right
.export scroll_left
.export scroll_up
.export scroll_down
.export iny_ppu
.export iny_ppu_nt
.export dey_ppu
.export dey_ppu_nt
.export inx_ppu
.export inx_ppu_nt
.export dex_ppu
.export dex_ppu_nt
.export calculate_ppu_pos
.export calculate_ppu_col
.export calculate_ppu_row
.export update_nt_boundary

y_first_nt = $20
y_last_nt  = $28
x_first_nt = $20
x_last_nt  = $24

.segment "ZEROPAGE"

cur_tile:       .res 1
ppu_addr:       .res 2 ; high byte, low byte
scroll:         .res 2 ; x, y
base_nt:        .res 1 ; mask for controller base NT bits
draw_y:         .res 1 ; current draw buffer index
draw_length:    .res 1
ppu_pos:        .res 1 ; for ppu_at_attribute procedure
ppu_ctrl:       .res 1 ; for checking vram increment (next NT or next attribute?)
buffer_start:   .res 1 ; start index for draw buffer

.segment "CODE"

; initialize ppu vars
.proc init_buffer
    lda #0
    sta buffer_index
    sta draw_buffer
    sta scroll
    sta scroll+1
    sta base_nt
    sta ppu_addr+1
    lda #$20
    sta ppu_addr
    rts
.endproc

; scroll right by 1 column
.proc scroll_right
    lda scroll
    clc
    adc #$08
    beq flip_page
    sta scroll
    rts
flip_page:
    ; flip the x page
    lda base_nt
    eor #%00000001
    sta base_nt
    ; set scroll to 0, simulating right scroll
    lda #0
    sta scroll
    rts
.endproc

; scroll left by 1 column
.proc scroll_left
    lda scroll
    sec
    sbc #$08
    bcc flip_page
    sta scroll
    rts
flip_page:
    ; flip the x page
    lda base_nt
    eor #%00000001
    sta base_nt
    ; set scroll to 256 - 8, simulating left scroll
    lda #256 - 8
    sta scroll
    rts
.endproc

; scroll up by 1 column
.proc scroll_up
    lda scroll + 1
    sec
    sbc #$08
    bcc flip_page
    sta scroll + 1
    rts
flip_page:
    ; flip the y page
    lda base_nt
    eor #%00000010
    sta base_nt
    ; set scroll to 240 - 8, simulating up scroll
    lda #240 - 8
    sta scroll + 1
    rts
.endproc

; scroll down by 1 column
.proc scroll_down
    lda scroll + 1
    clc
    adc #$08
    cmp #240
    bcs flip_page
    sta scroll + 1
    rts
flip_page:
    ; flip the y page
    lda base_nt
    eor #%00000010
    sta base_nt
    ; set scroll to 0, simulating down scroll
    lda #0
    sta scroll + 1
    rts
.endproc

; increment PPU address by 1 rows, handles wrapping to first NT addr
;
; x: low byte
; y: high byte
;
; clobbers: x
.proc iny_ppu
    lda ppu_addr
    ldx #4
    jsr mod
    ; if remainder of division is 3, we're on last page in NT
    cmp #3
    beq check_last_page
    jmp check_last_row
check_last_page:
    ; special case on last page
    lda ppu_addr+1
    cmp #$A0
    bcs iny_ppu_high
    jmp finish
check_last_row:
    ; check if we're on last row of page
    lda ppu_addr+1
    cmp #$E0
    bcs iny_ppu_high ; last row for low byte
finish:
    ; increment low byte by one row (32 tiles)
    lda ppu_addr+1
    clc
    adc #$20
    sta ppu_addr+1
    ; done
    rts
.endproc

; decrement PPU address by 1 rows, handles wrapping to last NT addr
; updates x and y registers with new NT addr
;
; x: high byte
; y: low byte
;
; clobbers: x
.proc dey_ppu
    lda ppu_addr+1
    cmp #$20
    bcc dey_ppu_high
    ; decrement low byte by one row (32 tiles)
    lda ppu_addr+1
    sec
    sbc #$20
    sta ppu_addr+1
    ; done
    rts
.endproc

; clobbers: x
.proc inx_ppu
    ; if remainder of division is #$1F (31), wrap to next NT
    lda ppu_addr+1
    ldx #$20
    jsr mod
    cmp #$1F
    beq inc_nt
    ; increment low byte by one row (32 tiles)
    inc ppu_addr+1
    ; done
    rts
inc_nt:
    jsr inx_ppu_nt
    ; todo will this work on last page?
    ; subtract $1F from low byte to go to start x of next NT
    lda ppu_addr + 1
    sec
    sbc #$1F
    sta ppu_addr + 1
    rts
    ; done
.endproc

; clobbers: x
.proc dex_ppu
    ; if remainder of division is #$00, wrap to prev NT
    lda ppu_addr+1
    ldx #$20
    jsr mod
    cmp #$0
    beq dec_nt
    ; decrement low byte by one row (32 tiles)
    dec ppu_addr+1
    ; done
    rts
dec_nt:
    jsr dex_ppu_nt
    ; add $1f to from low byte to go to end x of next NT
    lda ppu_addr + 1
    clc
    adc #$1F
    sta ppu_addr + 1
    rts
    ; done
.endproc

; increment PPU high address by 1, updating address to next NT if appropriate
;
; clobbers: x
.proc iny_ppu_high
    ; handle nametable wrapping, incrementing nt if we're on last page
    lda ppu_addr
    ldx #4
    jsr mod
    cmp #3
    beq inc_nt
    ; not start of first or start of last, increment by 1
    inc ppu_addr
    ; set low byte to first row in page using mod function to restore col
    lda ppu_addr + 1
    ldx #$20
    jsr mod
    sta ppu_addr + 1
    ; done
    rts
inc_nt:
    ; subtract 3 first
    lda ppu_addr
    sec
    sbc #$03
    sta ppu_addr
    ; increment NT
    jsr iny_ppu_nt
    ; set low byte to first row in page using mod function to restore col
    lda ppu_addr + 1
    ldx #$20
    jsr mod
    sta ppu_addr + 1
    rts
.endproc

; decrement PPU high address by 1, updating address to previous NT if appropriate
;
; clobbers: x
.proc dey_ppu_high
    ; handle nametable wrapping, decrementing nt if we're on first page
    lda ppu_addr
    ldx #4
    jsr mod
    cmp #0 ; todo shouldn't be necessary, but otherwise bug
    beq dec_nt
    ; not start page, decrement by 1
    dec ppu_addr
    ; set low byte to last row of prev addr using mod function to restore col
    lda ppu_addr + 1
    ldx #$20
    jsr mod
    clc
    adc #$E0
    sta ppu_addr + 1
    rts
dec_nt:
    ; add 3 first to get to last page
    lda ppu_addr
    clc
    adc #$03
    sta ppu_addr
    ; decrement NT
    jsr dey_ppu_nt
    ; set low byte to last row of prev addr using mod function to restore col
    lda ppu_addr + 1
    ldx #$20
    jsr mod
    clc
    adc #$A0
    sta ppu_addr + 1
    rts
.endproc

.proc iny_ppu_nt
    ; first check if we can subtract (i.e. are we in last NT?)
    lda ppu_addr
    sec
    sbc #$08
    cmp #y_first_nt
    bcc inc_nt ; unable to subtract if we're in first NT already
    ; success!
    sta ppu_addr
    rts
inc_nt:
    lda ppu_addr
    clc
    adc #$08
    sta ppu_addr
    rts
.endproc

.proc dey_ppu_nt
    jmp iny_ppu_nt
.endproc

; increment PPU nametable horizontally
;
; clobbers: x
.proc inx_ppu_nt
    ; handle nametable wrapping
    lda ppu_addr
    ldx #8
    jsr mod
    cmp #4
    bcc inc_nt
    lda ppu_addr
    sec
    sbc #$04
    sta ppu_addr
    rts
inc_nt:
    ; increment nametable
    lda ppu_addr
    clc
    adc #$04
    sta ppu_addr
    rts
.endproc

; decrement PPU nametable horizontally
.proc dex_ppu_nt
    jmp inx_ppu_nt
.endproc

;
; functions related to calculating PPU NT attribute boundary
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
