.include "scopes.inc"

; global constants
maxtiles   = 96
max_width  = 32
max_height = 24
maxmobs    = 20

; main.s
.globalzp controller1
.globalzp controller1release
.globalzp nmis
.globalzp gamestate
.globalzp need_buffer

; message.s
.globalzp max_messages
.globalzp messages
.global push_msg
.global buffer_messages

; dungeon.s
.global tiles
.globalzp dlevel
.globalzp xpos
.globalzp ypos
.globalzp up_x
.globalzp up_y
.globalzp down_x
.globalzp down_y
.global rand_passable
.global is_passable
.global randxy
.global within_bounds
.global get_byte_mask
.global get_byte_offset

; mob.s
.globalzp mob_size
.globalzp mobs_size
.globalzp mobs
.global mob_at
.global damage_mob
.global kill_mob
.global rand_mob
.global is_alive

; ai.s
.global mob_ai

; player.s
.global initialize_player
.global buffer_hp

; generate.s
.global generate

; random.s
.globalzp seed
.global prng
.global d2
.global d3
.global d4
.global d6
.global d12

; tile.s
.global get_bg_tile
.global get_mob_tile
.global get_str_tile
.global get_num_tile

; render.s
.global render
.global regenerate
.global render_escape
.global render_death
.global render_win
.global update_sprites

; buffer.s
.globalzp max_buffer_size
.globalzp draw_buffer
.globalzp draw_length
.globalzp str_pointer
.global next_index
.global buffer_str
.global buffer_num
.global render_buffer

; input.s
.global readcontroller
.global handle_input
