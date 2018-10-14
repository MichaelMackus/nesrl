.include "global.inc"

.segment "ZEROPAGE"

; variables
tmp:         .res 1
gamestate:   .res 1
controller1: .res 1
controller1release: .res 1
level:       .res 1            ; level integer
nmis:        .res 1            ; how many nmis have passed

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
waitforppu:
    bit $2002
    bpl waitforppu ; at this point, about 27384 cycles have passed

init:
init_memory:
    ; initialize vars to zero
    lda #0
    sta gamestate
    sta controller1
    sta controller1release
    sta level

clear_oam:
    lda #$FF
    ldx #$00
oamloop:
    ; reset all sprites via loop
    sta $0200, x
    inx
    cpx #$00
    bne oamloop

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

init_ppu:
    ; wait for ppu to be ready one last time
    bit $2002
    bpl init_ppu
    ; at this point, about 57165 cycles have passed

    ; initialize ppu vblank NMI
    lda #%10000000
    sta $2000

    ; initialize game!
    jmp main

nmi:
    pha

    lda #$00
    sta $2003
    ; draw OAM data via DMA
    lda #$02
    sta $4014

    pla

    inc nmis
    rti
irq:
    rti

.segment "CODE"

main:
    jsr readcontroller

playgame:
    jsr handle_input
    jsr render_player

    lda nmis
done:
    cmp nmis
    beq done

    ; endless game loop
    jmp main


handle_input:
    lda controller1release
    and #%00010000 ; start
    bne regenerate
    ; update player pos to memory
    jsr playerx
    sta xpos
    jsr playery
    sta ypos
    lda xpos
    pha
    lda ypos
    pha
    ; handle player movement
    lda controller1release
    and #%00000010  ; left
    bne move_left
    lda controller1release
    and #%00000001  ; right
    bne move_right
    lda controller1release
    and #%00000100  ; down
    bne move_down
    lda controller1release
    and #%00001000  ; up
    bne move_up
    jmp reset_player_pos
move_left:
    dec xpos
    jsr within_bounds
    bne reset_player_pos
    jmp move_done
move_right:
    inc xpos
    jsr within_bounds
    bne reset_player_pos
    jmp move_done
move_up:
    dec ypos
    jsr within_bounds
    bne reset_player_pos
    jmp move_done
move_down:
    inc ypos
    jsr within_bounds
    bne reset_player_pos
    jmp move_done
reset_player_pos:
    pla
    sta ypos
    pla
    sta xpos
    rts
move_done:
    pla
    pla
    jsr update_player_pos
    rts

; re-generate dungeon level
regenerate:
    lda nmis
    sta seed
    jsr generate
    ; render the dungeon
    jsr render

    jmp done

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
