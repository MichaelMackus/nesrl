; Due to storage & palette constraints of the NES, we only store the dungeon
; feature on the dungeon tile. Once the player picks up the item, the feature
; gets randomized into a real item with feature_to_item. This way, we only need
; to store coords of features in the dungeon, and the full item struct only
; gets stored in the player's inventory. This works, since only the Player can
; use items in this game.
;
; TODO this won't work if we want to allow more than 1 item/feature in 1 tile
; TODO for example, if a chest is on a tile, we can't put a monster drop there

.include "global.inc"

.export rand_feature
.export rand_drop
.export feature_to_item

.segment "ZEROPAGE"

; for random generation
feature:    .res .sizeof(Feature)
item:       .res .sizeof(Item)
; store map of item -> appearance
potion_map: .res 5 ; amount of potions
scroll_map: .res 5 ; amount of scrolls

.segment "CODE"

; generate random dungeon feature at xpos and ypos
.proc rand_feature
    lda xpos
    sta feature + Feature::coords + Coord::xcoord
    lda ypos
    sta feature + Feature::coords + Coord::ycoord
    ; random number 0-255
    jsr prng
    ; roughly 2% chance to spawn chest
    cmp #5
    bcc chest
    ; additional 2% potion
    cmp #11
    bcc potion
    ; additional 2% chance to spawn scroll
    cmp #15
    bcc scroll
    ; failure
    lda #Features::none
    sta feature+Feature::type
    rts
chest:
    lda #Features::chest
    sta feature+Feature::type
    rts
potion:
    lda #Features::item_potion
    sta feature+Feature::type
    rts
scroll:
    lda #Features::item_scroll
    sta feature+Feature::type
    rts
.endproc

; generate random mob drop feature at xpos and ypos
.proc rand_drop
.endproc

; generate random item from the feature
.proc feature_to_item
.endproc

; store random potion in item var
; clobbers x and accum
.proc rand_potion
    ; prepare item
    lda #ItemTypes::potion
    sta item+Item::type
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
    sta item+Item::item
    jsr item_appearance
    rts
; full healing pot
pot_3:
    lda #Potions::fullheal
    sta item+Item::item
    jsr item_appearance
    rts
; poison pot
pot_4:
    lda #Potions::poison
    sta item+Item::item
    jsr item_appearance
    rts
; confusion pot
pot_5:
    lda #Potions::confusion
    sta item+Item::item
    jsr item_appearance
    rts
; power pot
pot_6:
    lda #Potions::power
    sta item+Item::item
    jsr item_appearance
    rts
.endproc

; todo store random scroll in item var
; clobbers x and accum
.proc rand_scroll
.endproc

; loads the item appearance pointer
; todo lookup in map first, otherwise randomize appearance
.proc item_appearance
    lda item+Item::type
    cmp #ItemTypes::potion
    beq potion_appearance
    ; todo scrolls
    rts
potion_appearance:
    lda item+Item::item
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
    sta item+Item::appearance
    lda #>txt_heal
    sta item+Item::appearance+1
    rts
fullheal:
    lda #<txt_fullheal
    sta item+Item::appearance
    lda #>txt_fullheal
    sta item+Item::appearance+1
    rts
poison:
    lda #<txt_poison
    sta item+Item::appearance
    lda #>txt_poison
    sta item+Item::appearance+1
    rts
confusion:
    lda #<txt_confusion
    sta item+Item::appearance
    lda #>txt_confusion
    sta item+Item::appearance+1
    rts
power:
    lda #<txt_power
    sta item+Item::appearance
    lda #>txt_power
    sta item+Item::appearance+1
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
