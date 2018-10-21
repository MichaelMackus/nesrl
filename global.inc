.include "scopes.inc"

; global constants
maxtiles    = 96
max_width   = 32
max_height  = 24
maxmobs     = 20
maxfeatures = 20
maxdrops    = 20

; math.s
.global divide

; scroll.s
.globalzp ppu_addr
.globalzp scroll
.globalzp base_nt
.global scroll_right
.global scroll_left
.global scroll_up
.global scroll_down
.global inx_ppu
.global dex_ppu
.global iny_ppu
.global dey_ppu

; main.s
.globalzp turn
.globalzp controller1
.globalzp controller1release
.globalzp nmis

; message.s
.globalzp max_messages
.globalzp messages
.globalzp message_strlen
.globalzp message_size
.global push_msg
.global update_message_str
.global has_amount

; update.s
.global init_buffer
.global buffer_tiles
.global buffer_messages
.global buffer_hp
.global update_sprites

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
.global rand_floor
.global is_floor
.global is_passable
.global randxy
.global within_bounds
.global get_byte_mask
.global get_byte_offset
.global update_seen
.global was_seen

; mob.s
.globalzp mob_size
.globalzp mobs_size
.global mobs
.global mob_at
.global damage_mob
.global kill_mob
.global rand_mob
.global is_alive
.global mob_dmg

; ai.s
.global mob_ai
.global mob_spawner

; lighting.s
.globalzp sight_distance
.global can_see

; player.s
.globalzp stats
.global initialize_player
.global player_regen
.global player_dmg
.global award_exp

; generate.s
.global generate

; random.s
.globalzp seed
.global prng
.global d2
.global d3
.global d4
.global d6
.global d8
.global d12

; tile.s
.globalzp metaxpos
.globalzp metaypos
.global get_bg_metatile
.global get_bg_tile
.global get_mob_tile
.global get_str_tile
.global get_num_tile

; render.s
.globalzp screen_width
.globalzp screen_height
.global render
.global render_escape
.global render_death
.global render_win

; buffer.s
.globalzp max_buffer_size
.globalzp draw_buffer
.globalzp str_pointer
.global next_index
.global buffer_str
.global buffer_num
.global render_buffer

; input.s
.global readcontroller
.global handle_input

; item.s
.globalzp features
.globalzp items
.global feature_at
.global rand_feature
.global rand_drop
