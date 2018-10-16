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
    sta draw_buffer
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

render_draw_buffer:
    ; render draw queue
    jsr render_buffer

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
    ;lda messages_updated
    ;beq done_next
    ; update draw buffer with messages
    jsr buffer_messages

    lda nmis
wait_nmi:
    cmp nmis
    beq wait_nmi

    ; endless game loop
    jmp main


handle_input:
    lda controller1release
    and #%10000000 ; a
    bne check_action
    ; update player pos to memory
    lda mobs + Mob::coords + Coord::xcoord
    sta xpos
    lda mobs + Mob::coords + Coord::ycoord
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
    rts
check_action:
check_dstair:
    ldx mobs + Mob::coords + Coord::xcoord
    ldy mobs + Mob::coords + Coord::ycoord
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
    ldx mobs + Mob::coords + Coord::xcoord
    lda mobs + Mob::coords + Coord::ycoord
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
    lda xpos
    sta mobs+Mob::coords+Coord::xcoord
    lda ypos
    sta mobs+Mob::coords+Coord::ycoord
input_done:
    rts
attack_mob:
    ; todo use damage calc, for now just do 1 damage
    damage = tmp
    lda #1
    sta damage
    jsr damage_mob
    ; if dead, push kill message
    jsr is_alive
    bne push_kill_msg
    ; push damage message
    lda #Messages::hit
    ldx damage
    jsr push_msg
    ; done
    rts
push_kill_msg:
    ; push damage message
    lda #Messages::hit
    ldx damage
    jsr push_msg
    ; push kill message
    lda #Messages::kill
    jsr push_msg
    ; done
    rts

; update mob pos randomly, and attack player
; todo move towards player if can see
mob_ai:
    ldy #mob_size
mob_ai_loop:
    tya
    jsr is_alive
    bne continue_mob_ai
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
; todo buffer HP to draw buffer
attack_player:
    ; remember y to stack
    tya
    pha
    ; todo use damage calc, for now just do 1 damage
    lda #1
    ldy #0 ; player index
    sta damage
    jsr damage_mob
    ; push message
    lda #Messages::hurt
    ldx #1
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
move_mob:
    ; todo move mob random dir
continue_mob_ai:
    tya
    clc
    adc #mob_size
    tay
    cmp #mobs_size
    bne mob_ai_loop
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
