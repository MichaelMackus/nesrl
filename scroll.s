; functions related to PPU scrolling
; todo scrolling functions currently assume scroll is always on 8 pixel boundary
; todo inc & dec nt functions should just do that, the page should be set in the inc/dec ppu functions

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
    ; todo won't work for x scroll
    cmp #y_first_nt + 3
    beq check_last_page
    cmp #y_last_nt + 3
    beq check_last_page
    jmp check_last_row
check_last_page:
    ; special case on +3
    lda ppu_addr+1
    cmp #$A0
    beq iny_ppu_high
    jmp finish
check_last_row:
    lda ppu_addr+1
    cmp #$E0
    beq iny_ppu_high ; last row for low byte
finish:
    ; decrement low byte by one row (32 tiles)
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
    beq dey_ppu_high ; zero
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
    beq inx_ppu_nt
    ; increment low byte by one row (32 tiles)
    inc ppu_addr+1
    ; done
    rts
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
    jmp dex_ppu_nt
.endproc

; increment PPU high address by 1, updating address to next NT if appropriate
.proc iny_ppu_high
    ; handle nametable wrapping
    ; todo fix with x scroll
    lda ppu_addr
    cmp #y_first_nt + 3
    beq inc_nt
    cmp #y_last_nt + 3
    beq inc_nt
    ; not start of first or start of last, increment by 1
    inc ppu_addr
    ; set low byte to $00, first row in page
    lda #$00
    sta ppu_addr + 1
    ; done
    rts
inc_nt:
    ; subtract 3 first
    sec
    sbc #$03
    sta ppu_addr
    ; increment NT
    jsr iny_ppu_nt
    ; set low byte to $00, first row in NT
    lda #$00
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

; decrement PPU high address by 1, updating address to previous NT if appropriate
.proc dey_ppu_high
    ; handle nametable wrapping
    ; todo fix with x scroll
    lda ppu_addr
    cmp #y_first_nt
    beq dec_nt
    cmp #y_last_nt
    beq dec_nt
    ; not start of first or start of last, decrement by 1
    dec ppu_addr
    ; set low byte to last row of prev addr
    lda #$E0
    sta ppu_addr + 1
    rts
dec_nt:
    ; add 3 first to get to last page
    clc
    adc #$03
    sta ppu_addr
    ; decrement NT
    jsr dey_ppu_nt
    ; set low byte to $A0, last row in NT
    lda #$A0
    sta ppu_addr + 1
    rts
.endproc

.proc dey_ppu_nt
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
    ; done
    rts
.endproc

; increment PPU nametable horizontally
.proc inx_ppu_nt
    ; handle nametable wrapping
    lda ppu_addr
    cmp #x_last_nt
    bcs dec_nt
    ; increment nametable
    clc
    adc #$04
    sta ppu_addr
    ; todo don't set low byte
    jmp set_lowbyte
dec_nt:
    sec
    sbc #$04
    sta ppu_addr
set_lowbyte:
    ; subtract $1F from low byte to go to start x of next NT
    ; todo will this work with scrolling?
    lda ppu_addr + 1
    sec
    sbc #$1F
    sta ppu_addr + 1
    ; done
    rts
.endproc

; decrement PPU nametable horizontally
.proc dex_ppu_nt
    ; handle nametable wrapping
    lda ppu_addr
    cmp #x_last_nt
    bcs dec_nt
    ; increment nametable
    clc
    adc #$04
    sta ppu_addr
    jmp set_lowbyte
dec_nt:
    sec
    sbc #$04
    sta ppu_addr
    ; todo don't set lowbyte
set_lowbyte:
    ; add $to from low byte to go to end x of next NT
    lda ppu_addr + 1
    clc
    adc #$1F
    sta ppu_addr + 1
    ; done
    rts
.endproc

