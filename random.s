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

; generate random value from 0-1
d2:
    jsr prng
    and #%00000001
    beq d2_eq
    lda #$01
    rts
d2_eq:
    lda #$02
    rts
