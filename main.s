.include "global.inc"

.segment "ZEROPAGE"

; variables
gamestate:   .res 1
controller1: .res 1
controller1release: .res 1
nmis:        .res 1            ; how many nmis have passed
tmp:         .res 1
need_draw:   .res 1            ; do we need to draw draw buffer?
need_buffer: .res 1            ; do we need to update the draw buffer?

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
    sta dlevel
    sta draw_buffer
    sta need_draw
    sta need_buffer
    jsr initialize_player
    lda Messages::none
    jsr push_msg
    lda Messages::none
    jsr push_msg
    lda Messages::none
    jsr push_msg

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
    txa
    pha
    tya
    pha
    lda tmp
    pha

    lda need_draw
    beq continue_nmi
render_draw_buffer:
    ; render draw queue
    jsr render_buffer

    ; done drawing
    lda #$00
    sta need_draw

    ; update scroll
    lda #$00
    sta $2005
    sta $2005

continue_nmi:
    lda #$00
    sta $2003
    ; draw OAM data via DMA
    lda #$02
    sta $4014

    pla
    sta tmp
    pla
    tay
    pla
    tax
    pla

    inc nmis
    rti
irq:
    rti

.segment "CODE"

main:
    jsr readcontroller

    lda gamestate
    cmp #1
    beq playgame
    bcs done
    ; todo handle more gamestates (e.g. inventory, win, death, quit)
start_screen:
    lda controller1release
    and #%00010000 ; start
    beq done
    jsr regenerate
    lda #1
    sta gamestate
    jmp done

escape_dungeon:
    jmp done

playgame:
    ; update turn when input is made
    lda controller1release
    beq playgame_noinput

    jsr handle_input
    jsr mob_ai

playgame_noinput:
    ; update sprite OAM data
    jsr update_sprites

done:
    ; check for new messages
    lda need_buffer
    beq wait_nmi
    ; update draw buffer with messages
    jsr buffer_messages
    jsr buffer_hp
    ; stop further buffering
    lda #0
    sta need_buffer
    ; notify nmi to draw the buffer
    lda #1
    sta need_draw

    lda nmis
wait_nmi:
    cmp nmis
    beq wait_nmi

    ; endless game loop
    jmp main


.segment "RODATA"

PALETTE:
    .byte $0d, $09, $2d, $3a, $0f, $21, $2c, $3a
    .byte $0d, $21, $2c, $3a, $0f, $21, $2c, $3a
    .byte $0d, $12, $13, $23, $0f, $29, $19, $1A

.segment "VECTORS"

; set interrupt vectors to point to handlers
.word nmi   ;$fffa NMI
.word start ;$fffc Reset
.word irq   ;$fffe IRQ

.segment "CHARS"

; include CHR ROM data
.incbin "tiles.chr"
