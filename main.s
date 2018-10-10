.include "global.inc"

.segment "ZEROPAGE"

gamestate:   .res 1
controller1: .res 1
controller1release: .res 1

; constants
maxtiles     = (256 * 240) / 8 / 8
maxtilebytes = maxtiles / 8

; variables
level:       .res 1            ; level integer
tiles:       .res maxtilebytes ; represents a 256x240 walkable grid in bits, 1 = walkable; 0 = impassable

.segment "HEADER"

; iNES header
; see http://wiki.nesdev.com/w/index.php/INES

.byte $4e, $45, $53, $1a ; "NES" followed by MS-DOS EOF
.byte $01                ; size of PRG ROM in 16 KiB units
.byte $01                ; size of CHR ROM in 8 KiB units
.byte $00                ; horizontal mirroring, mapper 000 (NROM)
.byte $00                ; mapper 000 (NROM)
.byte $00                ; size of PRG RAM in 8 KiB units
.byte $00                ; NTSC
.byte $00                ; unused
.res 5, $00              ; zero-filled

.segment "STARTUP"

start:
    ; wait for PPU, see: https://wiki.nesdev.com/w/index.php/PPU_power_up_state
    bit $2002     ; clear the VBL flag if it was set at reset time
    jsr waitforppu

clear_oam:
    lda #$FF
    ldx #$00
oamloop:
    ; reset all sprites via loop
    sta $0200, X
    inx
    cpx #$00
    bne oamloop

init:
init_palettes:
    ; initialize background palettes
    lda #$3F
    sta $2006
    lda #$00
    sta $2006 ; these two instructions tell the PPU to read/write data to $3F00 (BG color)
    ldx #$00
paletteloop:
    lda PALETTE, x
    sta $2007 ; this tells PPU to write color palette to the previous address in PPU
    inx
    cpx #24
    bne paletteloop
    ldx #$FF      ; reset stack to $FF
    txs

    ; wait for ppu to be ready one last time
    ; at this point, about 57165 cycles have passed
    jsr waitforppu

    ; generate first level
    lda #01
    sta level
    jsr generate

    ; show our sprites (& bg)
    jsr render

    ; initialize ppu vblank NMI
    lda #%10000000
    sta $2000

    ; initialize game!
    jmp main

nmi:
    rti
irq:
    rti

.segment "CODE"

render:
generate_ppu:
    ; prep ppu for first nametable write
    lda #$20
    sta $2006
    lda #$00
    sta $2006
    ldx #$00 ; counter for background sprite position
bg_repeat:
    ldy #$00 ; counter for background bit index
    lda tiles, x
bg_bits:
    cpy #8
    beq next_bg
    iny
    asl
    bcs wall
    ; push accumulator to stack, draw floor, then pull from stack
    pha
    lda #$00
    sta $2007
    pla
    jmp bg_bits
wall:
    ; push accumulator to stack, draw wall, then pull from stack
    pha
    lda #$60
    sta $2007
    pla
    jmp bg_bits
next_bg:
    inx
    ; repeat until desired amount (first byte of sprite-set)
    cpx #$78
    bne bg_repeat
bgdone:
    ; tell PPU to render BG & sprites
    lda #%00011010 ; note: need second bit in order to show background on left side of screen
    sta $2001
    rts

waitforppu:
    bit $2002
    bpl waitforppu ; at this point, about 27384 cycles have passed
    rts

main:
    lda gamestate
    cmp #$01
    bne playgame ; check if we're pausing game

pause:
    lda controller1release
    and #%00010000 ; start
    beq main
    ; start is pressed, reset gamestate
    lsr gamestate ; shift byte to 0
    jmp main      ; re-read controllers & continue game

playgame:
    ; todo input & logic
draw:
    ; wait for vblank nmi to happen before drawing
    jsr waitforppu

    ; todo update sprite x & y from player

    ; draw OAM data via DMA
    lda #$02
    sta $4014

    ; endless game loop
    jmp main

.segment "RODATA"

PALETTE:
    .byte $30, $21, $2c, $3a, $0f, $21, $2c, $3a
    .byte $30, $21, $2c, $3a, $0f, $21, $2c, $3a
    .byte $30, $12, $13, $23, $0f, $29, $19, $1A

SPRITES:
    .byte 4                  ; number of sprites
    .byte 200, $84, $00, 124 ; player sprite
    .byte 100, $84, $01,  54 ; box 1
    .byte 100, $84, $01, 204 ; box 2
    .byte  50, $84, $01, 124 ; box 3

.segment "VECTORS"

; set interrupt vectors to point to handlers
.word nmi   ;$fffa NMI
.word start ;$fffc Reset
.word irq   ;$fffe IRQ

.segment "CHARS"

; include CHR ROM data
.incbin "tiles.chr"
