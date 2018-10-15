.include "global.inc"

.segment "ZEROPAGE"

; variables
gamestate:   .res 1
controller1: .res 1
controller1release: .res 1
nmis:        .res 1            ; how many nmis have passed
tmp:         .res 1

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
    jsr initialize_player
    lda Messages::none
    sta messages
    sta messages + .sizeof(Message)
    sta messages + .sizeof(Message)*2

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

    ; re-render messages if updated
    ; todo figure out universal draw queue
    lda messages_updated
    beq continue_nmi
    jsr render_messages
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
    jsr handle_input
    ; todo handle mob ai
    jsr render_mobs

    lda nmis
done:
    cmp nmis
    beq done

    ; endless game loop
    jmp main


handle_input:
    lda controller1release
    and #%10000000 ; a
    bne check_action
    ; update player pos to memory
    jsr playerx
    sta xpos
    jsr playery
    sta ypos
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
    jmp input_done
check_action:
check_dstair:
    jsr playerx
    tax
    jsr playery
    tay
    cpx down_x
    bne check_upstair
    cpy down_y
    bne check_upstair
    ; on downstair, generate new level
    inc dlevel
    lda dlevel
    cmp #10 ; todo custom win condition
    beq win
    jsr regenerate
    rts
check_upstair:
    jsr playerx
    tax
    jsr playery
    tay
    cpx up_x
    bne input_done
    cpy up_y
    bne input_done
    ; on upstair, generate new level
    dec dlevel
    lda dlevel
    cmp #0
    beq escape
    jsr regenerate
    rts
move_left:
    dec xpos
    jsr within_bounds
    bne input_done
    jmp move_done
move_right:
    inc xpos
    jsr within_bounds
    bne input_done
    jmp move_done
move_up:
    dec ypos
    jsr within_bounds
    bne input_done
    jmp move_done
move_down:
    inc ypos
    jsr within_bounds
    bne input_done
move_done:
    jsr mob_at
    beq attack_mob
    jsr is_passable
    bne input_done
    jsr update_player_pos
input_done:
    rts
attack_mob:
    ; todo use damage calc, for now just do 1 damage
    damage = tmp
    lda #1
    sta damage
    jsr damage_mob
    ; push message
    lda #Messages::hit
    ldx damage
    jsr push_msg
    ; done
    jmp input_done
escape:
    jsr render_escape
    ; escape dungeon
    lda #2
    sta gamestate
    rts
win:
    jsr render_win
    ; win dungeon
    lda #3
    sta gamestate
    rts

; re-generate dungeon level
regenerate:
    lda nmis
    sta seed
    jsr generate
    ; render the dungeon
    jsr render
    rts

.segment "RODATA"

PALETTE:
    .byte $30, $21, $2c, $3a, $0f, $21, $2c, $3a
    .byte $30, $21, $2c, $3a, $0f, $21, $2c, $3a
    .byte $30, $12, $13, $23, $0f, $29, $19, $1A

.segment "VECTORS"

; set interrupt vectors to point to handlers
.word nmi   ;$fffa NMI
.word start ;$fffc Reset
.word irq   ;$fffe IRQ

.segment "CHARS"

; include CHR ROM data
.incbin "tiles.chr"
