; procedures for getting the specific tile depending on input

.include "global.inc"

.export get_bg_metatile
.export get_bg_tile
.export get_mob_tile
.export get_str_tile
.export get_num_tile

.segment "CODE"

; gets bg metatile in metaxpos and metaypos
; clobbers: x and y
.proc get_bg_metatile
    ; divide metax and metay by 2 to get tile offset
    lda metaxpos
    lsr
    sta xpos
    lda metaypos
    lsr
    sta ypos
    ; get the bg tile
    jsr get_bg_tile
    rts
.endproc

; updates register a with the tile corresponding to xpos and ypos
; clobbers: x and y
.proc get_bg_tile
    ; todo
    ;jsr within_bounds
    ;bne bg
check_upstair:
    ldx xpos
    ldy ypos
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
    bne check_feature
    lda #$3F
    rts
check_feature:
    jsr feature_at
    bne tile
    ; success! feature in register y
    cmp #Features::chest
    beq chest
chest:
    lda #$91
    rts
    ; no feature found
    jmp tile
; todo check_item:
tile:
    ; finally, display tile
    jsr get_byte_offset
    tay
    jsr get_byte_mask
    and tiles, y
    bne floor
bg:
    lda #$00
    ;lda #$60 ; todo only display wall if is_touching floor
    rts
floor:
    ;lda #$62
    ;lda #$84
    lda #$82
    rts
.endproc

; get mob tile
; in: mob index
; out: tile
.proc get_mob_tile
    ; branch based on mob type
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
    lda mobs+Mob::direction
    cmp #Direction::up
    beq player_uptile
    cmp #Direction::down
    beq player_uptile
    lda #$A0
    rts
player_uptile:
    lda #$AA
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

; get hex number tile (for debugging)
; in: hex number
; out: tile
.proc get_hex_tile
    cmp #10
    bcs hex
    ; num
    clc
    adc #$10
    rts
hex:
    clc
    adc #$17
    rts
.endproc
