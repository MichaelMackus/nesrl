.include "global.inc"

.segment "ZEROPAGE"

; variables
turn:        .res 1
gamestate:   .res 1
controller1: .res 1
controller1release: .res 1
nmis:        .res 1            ; how many nmis have passed
tmp:         .res 1
need_draw:   .res 1            ; do we need to draw draw buffer?

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
    lda #GameState::start
    sta gamestate
    lda #0
    sta controller1
    sta controller1release
    sta dlevel
    sta need_draw
    sta turn
    inc turn ; set turn to 1
    jsr initialize_player
    lda Messages::none
    jsr push_msg
    lda Messages::none
    jsr push_msg
    lda Messages::none
    jsr push_msg
    jsr init_buffer
    jsr init_status

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
    cpx #32
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

    ; update base ppu addr
    lda base_nt
    ora #%10000000 ; default
    sta $2000

    ; update scroll
    bit $2002
    lda scroll
    sta $2005
    lda scroll + 1
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
    jsr clear_messages
    ; check if we're still in batch buffer mode
    lda buffer_index
    beq check_state
    ; we're still in batch buffer mode, update tiles buffer
    jmp update

check_state:
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
    lda #GameState::playing
    sta gamestate
    ; initialize *both* seed values
    lda nmis
    sta seed
    sta seed + 1
    jmp regenerate

playgame:
    ; update turn when input is made
    lda controller1release
    beq done
    inc turn

    jsr handle_input

    ; check input result & update game's state
    cmp #InputResult::new_dlevel
    beq regenerate
    cmp #InputResult::escape
    beq escape_dungeon
    cmp #InputResult::win
    beq win_dungeon
    cmp #InputResult::move
    beq player_moved

ai:
    jsr mob_ai
    jsr check_game_over

    jsr mob_spawner
    jsr player_regen

update:
    ; todo figure out better way to buffer messages, probably want to
    ; todo buffer them using draw loop, clearing on next action
    ;jsr buffer_messages

    ; notify nmi to draw the buffer
    lda #1
    sta need_draw

    ; update sprite OAM data
    jsr update_sprites

done:
    lda nmis
wait_nmi:
    cmp nmis
    beq wait_nmi

    ; endless game loop
    jmp main


; state updates

; re-generate next dungeon level
regenerate:
    ; initialize & flip seed bits
    lda nmis
    eor #$32
    sta seed
    ; generate dungeon
    jsr generate
    jsr render
    jmp done

; update state to end & render escape
escape_dungeon:
    lda #GameState::end
    sta gamestate
    jsr render_escape
    jmp done

; update state to win
win_dungeon:
    lda #GameState::win
    sta gamestate
    jsr render_win
    jmp done

; ensure buffer is updated when new tiles seen
player_moved:
    jsr update_screen_offsets
    jsr buffer_tiles
    jmp ai

; ensure player alive, otherwise display Game Over screen
check_game_over:
    lda mobs + Mob::hp
    beq game_over
    rts
game_over:
    lda #GameState::end
    sta gamestate
    jsr render_death
    rts


.segment "RODATA"

PALETTE:
    ; tiles
    .byte $0f, $09, $2d, $3a, $0f, $21, $2c, $3a
    .byte $0f, $2d, $08, $18, $0f, $21, $2c, $3a
    ; sprites
    .byte $0f, $08, $2d, $30, $0f, $1d, $1d, $0a
    .byte $0f, $1d, $1d, $2d, $0f, $1d, $1d, $06

.segment "VECTORS"

; set interrupt vectors to point to handlers
.word nmi   ;$fffa NMI
.word start ;$fffc Reset
.word irq   ;$fffe IRQ

.segment "CHARS"

; include CHR ROM data
.incbin "tiles.chr"
