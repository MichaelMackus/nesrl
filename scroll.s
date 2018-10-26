; functions related to PPU scrolling
; todo scrolling functions currently assume scroll is always on 8 pixel boundary

; in: dividend
; x: divisor
; out: remainder of modulus
.import mod

.exportzp ppu_addr
.exportzp scroll
.exportzp base_nt
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

y_first_nt = $20
y_last_nt  = $28
x_first_nt = $20
x_last_nt  = $24

.segment "ZEROPAGE"

ppu_addr: .res 2 ; high byte, low byte
scroll:   .res 2 ; x, y
base_nt:  .res 1 ; mask for controller base NT bits

.segment "CODE"

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

