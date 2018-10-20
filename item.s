.include "global.inc"

.export feature_at
.export rand_feature
.export rand_drop

.segment "ZEROPAGE"

; store map of item -> appearance
potion_map: .res 5 ; amount of potions
scroll_map: .res 5 ; amount of scrolls

.segment "BSS"

features:    .res .sizeof(Feature)*maxfeatures
items:       .res .sizeof(ItemDrop)*maxdrops

.segment "CODE"

; get feature at xpos and ypos
; out: 0 on success
; updates: y register to feature index
.proc feature_at
    ldy #0
loop:
    lda features + Feature::coords + Coord::xcoord, y
    cmp xpos
    bne continue
    lda features + Feature::coords + Coord::ycoord, y
    cmp ypos
    beq success
continue:
    tya
    clc
    adc #.sizeof(Feature)
    cmp #maxfeatures * .sizeof(Feature)
    tay
    bne loop
    ; failure
    lda #1
    rts
success:
    lda #0
    rts
.endproc

; generate random dungeon feature at xpos and ypos
; stores feature in features array at index y
;
; clobbers: x
.proc rand_feature
    lda xpos
    sta features + Feature::coords + Coord::xcoord, y
    ; for some reason, if we lda twice we get grey screen bug
    lda ypos
    sta features + Feature::coords + Coord::ycoord, y
    ; random number 0-255
    jsr prng
    ; roughly 2% chance to spawn chest
    cmp #5
    bcc chest
    ; failure
    lda #Features::none
    sta features + Feature::type, y
    rts
chest:
    lda #Features::chest
    sta features + Feature::type, y
    rts
.endproc

; generate random drop at index y
;
; in: rarity (1-10) (todo doesn't do anything atm)
.proc rand_drop
    jsr d2
    cmp #1
    beq rand_potion
    jmp rand_scroll
.endproc

; store random potion in items var at index y
; clobbers x and accum
.proc rand_potion
    ; prepare item
    lda #ItemTypes::potion
    sta items+Item::type, y
    ; generate random potion
    jsr d6
    cmp #1
    beq pot_1
    cmp #2
    beq pot_2
    cmp #3
    beq pot_3
    cmp #4
    beq pot_4
    cmp #5
    beq pot_5
    cmp #6
    beq pot_6
    rts
; healing pot
pot_1:
pot_2:
    lda #Potions::heal
    sta items+Item::item, y
    jsr item_appearance
    rts
; full healing pot
pot_3:
    lda #Potions::fullheal
    sta items+Item::item, y
    jsr item_appearance
    rts
; poison pot
pot_4:
    lda #Potions::poison
    sta items+Item::item, y
    jsr item_appearance
    rts
; confusion pot
pot_5:
    lda #Potions::confusion
    sta items+Item::item, y
    jsr item_appearance
    rts
; power pot
pot_6:
    lda #Potions::power
    sta items+Item::item, y
    jsr item_appearance
    rts
.endproc

; todo store random scroll in items var at index y
; clobbers x and accum
.proc rand_scroll
.endproc

; loads the item appearance pointer of items var at index y
; todo lookup in map first, otherwise randomize appearance
.proc item_appearance
    lda items+Item::type, y
    cmp #ItemTypes::potion
    beq potion_appearance
    ; todo scrolls
    rts
potion_appearance:
    lda items+Item::item, y
    cmp #Potions::heal
    beq heal
    cmp #Potions::fullheal
    beq fullheal
    cmp #Potions::poison
    beq poison
    cmp #Potions::confusion
    beq confusion
    cmp #Potions::power
    beq power
    rts
heal:
    lda #<txt_heal
    sta items+Item::appearance, y
    lda #>txt_heal
    sta items+Item::appearance+1, y
    rts
fullheal:
    lda #<txt_fullheal
    sta items+Item::appearance, y
    lda #>txt_fullheal
    sta items+Item::appearance+1, y
    rts
poison:
    lda #<txt_poison
    sta items+Item::appearance, y
    lda #>txt_poison
    sta items+Item::appearance+1, y
    rts
confusion:
    lda #<txt_confusion
    sta items+Item::appearance, y
    lda #>txt_confusion
    sta items+Item::appearance+1, y
    rts
power:
    lda #<txt_power
    sta items+Item::appearance, y
    lda #>txt_power
    sta items+Item::appearance+1, y
    rts
.endproc

.segment "RODATA"

; todo will need to translate these into NES color palette
txt_colors:
    .asciiz "Black"
    .asciiz "Blue"
    .asciiz "Green"
    .asciiz "Yellow"
    .asciiz "Grey"

txt_heal:       .asciiz "Healing"
txt_fullheal:   .asciiz "Full Healing"
txt_poison:     .asciiz "Poison"
txt_confusion:  .asciiz "Confusion"
txt_power:      .asciiz "Power"

txt_names:
    .asciiz "READ ME"
    .asciiz "ABRACADABRA"
    .asciiz "ASDF ZSDF"
    .asciiz "BLAH"
    .asciiz "DONT READ"
