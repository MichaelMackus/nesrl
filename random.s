; prng
;
; Returns a random 8-bit number in A (0-255), clobbers X (0).
;
; Requires a 2-byte value on the zero page called "seed".
; Initialize seed to any value except 0 before the first call to prng.
; (A seed value of 0 will cause prng to always return 0.)
;
; This is a 16-bit Galois linear feedback shift register with polynomial $002D.
; The sequence of numbers it generates will repeat after 65535 calls.
;
; Execution time is an average of 125 cycles (excluding jsr and rts)

.include "global.inc"

.segment "ZEROPAGE"

seed: .res 2       ; initialize 16-bit seed to any value except 0

.segment "CODE"

; clobbers: x and accum
prng:
	ldx #8     ; iteration count (generates 8 bits)
	lda seed+0
:
	asl        ; shift the register
	rol seed+1
	bcc :+
	eor #$2D   ; apply XOR feedback whenever a 1 bit is shifted out
:
	dex
	bne :--
	sta seed+0
	cmp #0     ; reload flags
	rts

; generate random value from 1-2
d2:
    jsr prng
    and #%00000001
    beq d2_eq
    lda #$01
    rts
d2_eq:
    lda #$02
    rts

; generate random value from 1-3
d3:
    jsr prng
    and #%00000011
    beq d3 ; don't accept zero
    rts

; generate random value from 1-4
d4:
    jsr prng
    and #%00000011
    clc
    adc #$01
    rts

; generate random value from 1-6
d6:
    jsr prng
    and #%00000111
    beq d6 ; don't generate zero
    cmp #7
    beq d6 ; don't generate 7
    rts

; generate random value from 1-8
d8:
    jsr prng
    and #%00000111
    clc
    adc #$01
    rts

; generate random value from 1-12
d12:
    jsr prng
    and #%00001111
    cmp #12
    bcs d12 ; try again since we have a number >= 12
    ; all good, increment by 1 for result
    clc
    adc #$01
    rts
