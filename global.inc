; global constants
maxtiles   = 96
max_width  = 32
max_height = 24
maxmobs    = 20

; main.s
.globalzp controller1
.globalzp controller1release

; dungeon.s
.globalzp tiles
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
.globalzp playerlvl
.global mobx
.global moby
.global mobtype
.global update_mob_pos
.global damage_mob
.global kill_mob
.global initialize_player
.global playerx
.global playery
.global update_player_pos
.global rand_mob
.global is_alive

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

; render.s
.global render
.global render_escape
.global render_win
.global render_mobs

; input.s
.global readcontroller
