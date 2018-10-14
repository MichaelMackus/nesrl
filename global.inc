; main.s
.global tmp
.global controller1
.global controller1release

; dungeon.s
.global tiles
.global dlevel
.global xpos
.global ypos
.global up_x
.global up_y
.global down_x
.global down_y
.global rand_passable
.global is_passable
.global randxy
.global within_bounds
.global get_byte_mask
.global get_byte_offset

; mob.s
.global player
.global playerx
.global playery
.global playerlvl
.global enemies
.global update_player_pos

; generate.s
.global generate

; random.s
.global seed
.global prng
.global d2
.global d3
.global d4
.global d6
.global d12

; render.s
.global render
.global render_player

; input.s
.global readcontroller
