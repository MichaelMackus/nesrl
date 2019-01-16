; initialize function to zero out memory

.importzp buffer_index
.importzp draw_buffer
.importzp scroll
.importzp base_nt
.importzp ppu_addr

.export init_buffer

.segment "CODE"

; initialize ppu vars
.proc init_buffer
    lda #0
    sta buffer_index
    sta draw_buffer
    sta scroll
    sta scroll+1
    sta base_nt
    sta ppu_addr+1
    lda #$20
    sta ppu_addr
    rts
.endproc
