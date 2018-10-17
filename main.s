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
    jsr mob_ai ; todo only handle for 1 turn

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


; update mob pos randomly, and attack player
; todo move towards player if can see
mob_ai:
    ldy #mob_size
mob_ai_loop:
    tya
    jsr is_alive
    beq do_ai
    jmp continue_mob_ai
do_ai:
    ; todo diff function
    lda mobs + Mob::coords + Coord::xcoord, y
    sta xpos
    lda mobs + Mob::coords + Coord::ycoord, y
    sta ypos
    ; check x
    lda mobs + Mob::coords + Coord::xcoord
    cmp xpos
    beq checkyplus1
    inc xpos
    cmp xpos
    beq checky
    dec xpos
    dec xpos
    cmp xpos
    beq checky
    jmp move_mob
checkyplus1:
    ; check y
    lda mobs + Mob::coords + Coord::ycoord
    inc ypos
    cmp ypos
    beq attack_player
    dec ypos
    dec ypos
    cmp ypos
    beq attack_player
checky:
    lda mobs + Mob::coords + Coord::ycoord
    cmp ypos
    beq attack_player
    jmp move_mob
damage = tmp
attack_player:
    ; remember y to stack
    tya
    pha
    ; ensure we update draw buffer
    lda #1
    sta need_buffer
    ; todo use damage calc, for now just do 1 damage
    lda #1
    ldy #0 ; player index
    sta damage
    jsr damage_mob
    ; push message
    lda #Messages::hurt
    ldx damage
    jsr push_msg
    ; check if player dead
    ldy #0
    jsr is_alive
    bne player_dead
    ; done
    pla
    tay
    jmp continue_mob_ai
player_dead:
    ; dead
    lda #4
    sta gamestate
    pla
    tay
    jmp render_death
mob_index = tmp
move_mob:
    ; todo wtf not working now :(
    ; move mob random dir
    lda mobs + Mob::coords + Coord::xcoord, y
    sta xpos
    lda mobs + Mob::coords + Coord::ycoord, y
    sta ypos
    sty mob_index
    jsr d4
    cmp #1
    beq move_mob_up
    cmp #2
    beq move_mob_right
    cmp #3
    beq move_mob_down
move_mob_left:
    dec xpos
    jsr is_passable
    ; todo is this affecting beq statement?
    beq do_move_mob_left
    ldy mob_index
    jmp continue_mob_ai
do_move_mob_left:
    ldy mob_index
    lda xpos
    sta mobs+Mob::coords+Coord::xcoord, y
    jmp continue_mob_ai
move_mob_up:
    dec ypos
    jsr is_passable
    beq do_move_mob_up
    ldy mob_index
    jmp continue_mob_ai
do_move_mob_up:
    ldy mob_index
    lda ypos
    sta mobs+Mob::coords+Coord::ycoord, y
    jmp continue_mob_ai
move_mob_right:
    inc xpos
    jsr is_passable
    beq do_move_mob_right
    ldy mob_index
    jmp continue_mob_ai
do_move_mob_right:
    ldy mob_index
    lda xpos
    sta mobs+Mob::coords+Coord::xcoord, y
    jmp continue_mob_ai
move_mob_down:
    inc ypos
    jsr is_passable
    beq do_move_mob_up
    ldy mob_index
    jmp continue_mob_ai
do_move_mob_down:
    ldy mob_index
    lda ypos
    sta mobs+Mob::coords+Coord::ycoord, y
    jmp continue_mob_ai
continue_mob_ai:
    tya
    clc
    adc #mob_size
    tay
    cmp #mobs_size
    beq done_ai_loop
    jmp mob_ai_loop
done_ai_loop:
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
