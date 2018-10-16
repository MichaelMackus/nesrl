; procedures for getting the specific tile depending on input

.include "global.inc"

.export get_bg_tile
.export get_mob_tile
.export get_str_tile
.export get_num_tile

.segment "CODE"

; updates register a with the tile corresponding to 
; coords from registers x and y
; clobbers y
.proc get_bg_tile
check_upstair:
    cpx up_x
    bne check_downstair
    cpy up_y
    bne check_downstair
    ; upstair tile
    lda #$3E
    rts
check_downstair:
    cpx down_x
    bne tile
    cpy down_y
    bne tile
    lda #$3F
    rts
tile:
    ; finally, display tile
    jsr get_byte_offset
    tay
    jsr get_byte_mask
    and tiles, y
    bne floor
bg:
    lda #$00
    rts
floor:
    lda #$82
    rts
.endproc

; get mob tile
; in: mob index
; out: tile
.proc get_mob_tile
    ; todo branch based on type
    tay
    lda mobs + Mob::type, y
    cmp #Mobs::player
    beq player_tile
    cmp #Mobs::goblin
    beq goblin_tile
    cmp #Mobs::orc
    beq orc_tile
    cmp #Mobs::ogre
    beq ogre_tile
    cmp #Mobs::dragon
    beq dragon_tile
    ; unknown tile
    lda #$01
    rts
player_tile:
    lda #$A1
    rts
goblin_tile:
    lda #$47
    rts
orc_tile:
    lda #$4F
    rts
ogre_tile:
    lda #$2F
    rts
dragon_tile:
    lda #$24
    rts
.endproc

; get str tile
; in: ascii char
; out: tile
.proc get_str_tile
    beq blank
    sec
    sbc #$20
    rts
blank:
    lda #$00
    rts
.endproc

; get number tile
; in: number 0-9
; out: tile
.proc get_num_tile
    cmp #10
    bcs blank
    clc
    adc #$10
    rts
blank:
    lda #$00
    rts
.endproc