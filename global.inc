.include "scopes.inc"

; global constants
maxtiles    = 96
max_width   = 32
max_height  = 24
maxmobs     = 10
maxfeatures = 20
maxdrops    = 20
min_bound   = 1  ; minimum number of spaces from edge

; math.s
.global divide

; ppu exports
.globalzp cur_tile
.globalzp ppu_addr
.globalzp ppu_pos
.globalzp scroll
.globalzp base_nt
.globalzp draw_y
.globalzp draw_length
.globalzp ppu_pos
.globalzp ppu_ctrl
.globalzp buffer_start
.globalzp max_buffer_size
.globalzp draw_buffer
.globalzp str_pointer
.globalzp buffer_index
.global init_buffer
.global scroll_right
.global scroll_left
.global scroll_up
.global scroll_down
.global inx_ppu
.global dex_ppu
.global inx_ppu_nt
.global dex_ppu_nt
.global iny_ppu
.global dey_ppu
.global iny_ppu_nt
.global dey_ppu_nt
.global calculate_ppu_pos
.global calculate_ppu_col
.global calculate_ppu_row
.global update_nt_boundary
.global start_buffer
.global append_buffer
.global append_str
.global next_index
.global buffer_str
.global buffer_num
.global buffer_num_tens
.global buffer_num_hex
.global render_buffer

; status.s
.globalzp has_status
.global init_status
.global buffer_status
.global buffer_status_text
.global buffer_status_end

; main.s
.globalzp turn
.globalzp controller1
.globalzp controller1release
.globalzp gamestate
.globalzp nmis
.globalzp a1
.globalzp a2
.globalzp a3

; message.s
.globalzp max_messages
.globalzp messages
.globalzp message_strlen
.globalzp message_size
.global clear_messages
.global push_msg
.global update_message_str
.global has_amount

; dungeon.s
.global tiles
.global seen
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
.global can_player_see
.global line_of_sight

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
.global get_hex_tile

; screen.s
.globalzp screen_width
.globalzp screen_height
.globalzp vertical_bound
.globalzp horizontal_bound
.globalzp xoffset
.globalzp yoffset
.global get_mob_xoffset
.global get_mob_yoffset
.global get_first_col
.global get_last_col
.global get_first_row
.global get_last_row
.global update_screen_offsets

; sprite.s
.global update_sprite_offsets
.global update_sprites
.global debug
.global debug_ypos

; update.s
.global buffer_tiles
.global update_scroll
.global buffer_seen
.global buffer_messages

; render.s
.global render
.global render_escape
.global render_death
.global render_win

; input.s
.global readcontroller
.global handle_input

; item.s
.globalzp features
.globalzp items
.global feature_at
.global rand_feature
.global rand_drop
