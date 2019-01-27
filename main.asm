org $8000

start:	di	; disable ints
ld	sp,$ff00	; set up a stack

ld	hl,$fefe	; set up a table of 257 x $80 for IM 2 vectors @ $8100
ld	bc,$fd
loop:	ld	(hl),c
inc	hl
; interrupt entry point
djnz	loop
ld	(hl),c	; set the 257th byte
ld	hl,$fdfd
ld	(hl),195	; JP instruction to $8080
inc	hl
ld	de,isr	; address of ISR into DE
ld	(hl),e	; low byte of ISR address to $8081
inc	hl
ld	(hl),d	; high byte of ISR address to $8082
ld	a,$fe
ld	i,a	; set high byte of IM 2 vector to $81

im	2	; 8 T States - switch into IM 2 mode
ei	; 4 T States - enable interrupts

;;;;;;;; wait for interrupt

main_loop:
jr	main_loop

isr:

ld hl, state
ld a, (hl)
dec a
jp z, game_loop ; 1
dec a
jp z, game_start ; 2
dec a
jp z, level_start ; 3
dec a
jp z, level_end ; 4
dec a
jp z, game_over ; 5
dec a
jp z, attract ; 6
dec a
jp z, title ; 7
dec a
jp z, boot ; 8
ei
reti

game_loop: 
call clear_player
call clear_lasers
call update_lasers
call update_player
call clear_aliens
call update_aliens
call spawn_aliens
call draw_aliens
call draw_lasers
call draw_player

ei
reti

state_play: equ 1
state_game_on: equ 2
state_level_start: equ 3
state_level_end: equ 4
state_game_over: equ 5
state_attract: equ 6
state_title: equ 7
state_boot: equ 8

state: db state_boot
state_step: db 0
state_timer: dw 0

game_level: dw 0
level_attr: db %00000100
game_score: dw 0

y_pos: db 12
x_pos: db 16

timer: db 0 ; number of frames elapsed each second(count 0-49)
; slots for 4 lasers. 0 means no laser in that slot

; y, d, x
lasers_count: equ 4
lasers: db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
laser_attr: db 68 ; 0 color bits for lasers - rotate 1-7
laser_dir: db 1 ; dir of last laser 0 right, 1 left

; slots for 5 humanoids
; state, y, x. state 0 = dead, 1 = on screen, 2 = waiting to go on screen, 3 = rescued 
humans: db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
humans_alive: db 0 ; how many humans player has

player_sprite: db %11111111, %00111100, %00011000, %00111100, %00111100, %00011000, %00111100, %11111111
laser_sprite: db %00000000, %00000000, %00011000 , %11111111, %11111111, %00011000, %00000000, %00000000

chars_map: dw $4000, $4020, $4040, $4060, $4080, $40A0, $40C0, $40E0, $4800, $4820, $4840, $4860, $4880, $48A0, $48C0, $48E0, $5000, $5020, $5040, $5060, $5080, $50A0, $50C0, $50E0

attrs_map: dw $5800, $5820, $5840, $5860, $5880, $58A0, $58C0, $58E0, $5900, $5920, $5940, $5960, $5980, $59A0, $59C0, $59E0, $5A00, $5A20, $5A40, $5A60, $5A80, $5AA0, $5AC0, $5AE0

update_player:
; joystick movement
ld bc, 31
in a,(c)
and 1
call nz, right

ld bc, 31
in a,(c)
and 2
call nz, left

ld bc, 31
in a,(c)
and 4
call nz, down

ld bc, 31
in a,(c)
and 8
call nz, up

ld bc, 31
in a,(c)
and 16
call nz, fire
ret


clear_player:
call get_player_yx ; bc now has y, x
call clear_sprite
ret

draw_player:
call get_player_yx; bc now has y, x
push bc
call char_yx_to_pixel_mem
ld c, 8 ; 8 rows
ld de, player_sprite ; sprite
draw_player_loop:
ld a, (de)
ld (hl), a
inc h ; next pixel line
inc e ; next sprite line
dec c ; loop counter
jr nz, draw_player_loop
pop bc
call char_yx_to_attrs_mem
ld (hl), %01000111
ret

get_laser_yx:
; put laser x-y character position in to bc (y, x)
; incoming, hl contains address of laser slot
ld b, (hl); ; laser y to b
inc hl ; skip laser direction
inc hl
ld c, (hl); ; laser x to c
ret

update_lasers:
; cycle laser color attr value
ld hl, laser_attr
ld a, (hl)
inc a
cp 72
jp nz, update_laser_attr
ld a, 66
update_laser_attr:
ld (hl), a

;move lasers
ld hl, lasers
; find active lasers and draw
ld b, lasers_count
move_lasers_loop:
ld a, 0
cp (hl) ; if laser y pos is zero, laser is unused
jp z, skip_move_laser
push bc
push hl
call move_laser ; bc now has y, x
pop hl
pop bc
inc hl ; skip to next slot
inc hl
inc hl
skip_move_laser:
dec b ; for all lasers
ret z ; looked at all slots
jp move_lasers_loop


; move laser position
move_laser:
inc hl ; we got passed laser y pos. skip to dir
ld c, (hl) ; get this laser direction
inc hl ; skip to x pos
ld a, (hl) ;; get laser x pos
cp 29 ; x pos hit right edge?
jp z, move_laser_done
cp 2 ; x pos hit left edge?
jp z, move_laser_done
; move laser
ld b, a ; put x pos in b
ld a, 1
cp c ; laser moving right?
jp z, move_laser_right
dec b; move laser left
ld (hl), b ; save new position
ret
move_laser_right:
inc b; move laser right
ld (hl), b ; save new postion
ret
move_laser_done:
; clear laser - out of bounds
ld (hl), 0
dec hl ; skip back to laser y pos
ld (hl), 0
dec hl
ld (hl), 0 ; save zero to indicate free slot
ret

clear_lasers:
ld hl, lasers
; find active lasers and draw
ld b, lasers_count
clear_lasers_loop:
ld a, 0
cp (hl) ; if laser y pos is zero, laser is unused
jp z, skip_clear_laser
push bc
push hl
call get_laser_yx ; bc now has y, x
call clear_sprite
pop hl
pop bc
inc hl ;; skip to next slot
inc hl
inc hl
skip_clear_laser:
dec b ; for all lasers
ret z ; looked at all slots
jp clear_lasers_loop


draw_lasers:
ld hl, lasers
; find active lasers and draw
ld b, lasers_count
draw_lasers_loop:
ld a, 0
cp (hl) ; if laser y pos is zero, laser is unused
jp z, skip_draw_laser
push bc
push hl
call draw_laser
pop hl
pop bc
inc hl ;; skip to next slot
inc hl
inc hl
skip_draw_laser:
dec b ; for all lasers
ret z ; looked at all slots
jp draw_lasers_loop

draw_laser:
; hl contains address of laser slot
call get_laser_yx; bc now has y, x
push bc ; save it
call char_yx_to_pixel_mem
ld c, 8 ; 8 rows of laser sprite
ld de, laser_sprite ; sprite
draw_laser_loop:
ld a, (de)
ld (hl), a
inc h ; next pixel line
inc e ; next sprite line
dec c ; loop counter
jr nz, draw_laser_loop
pop bc
call char_yx_to_attrs_mem ; hl now has attrs memory location
ld a, (laser_attr)
ld (hl), a
ret

; fire laser

fire:
ld hl, lasers
; find first available laser slot
ld a, 0
ld b, 4 ; 4 slots
fire_find_slot:
cp (hl) ; is y value of slot zero?
jp z, fire_shot ; yes, found an unused laser slot
inc hl
inc hl
inc hl
dec b
jp nz, fire_find_slot
ret ; looked at all slots, none available
fire_shot:
; laser y pos
ld de, y_pos ; player y
ld a, (de)
ld (hl), a ; save as laser y
inc hl ; next pos in slot is direction
; get last direction, flip it
ld de, laser_dir
ld a, (de)
ld c, 1
xor c
ld (de), a ; save direction for next shot
ld (hl), a ; save dirction for this laser
ld de, x_pos ; player x pos
ld a, (de)
jp z, fire_left
inc a ; shoot from right side
jp fire_done
fire_left:
dec a ; shoot from left side
fire_done:
inc hl ; next slot for laser is x pos
ld (hl), a
ret

; joystick movement

right:
ld hl, x_pos
ld a, (hl)
cp 28
ret z
inc (hl)
ret

left:
ld hl, x_pos
ld a, (hl)
cp 4
ret c
dec (hl)
ret

down:
ld hl, y_pos
ld a, (hl)
cp 20
ret z
inc (hl)
ret

up:
ld hl, y_pos
ld a, (hl)
cp 4
ret c
dec (hl)
ret

; aliens
alien_slots: equ 2
; slots for 10 aliens
; type, y, x, state, counter  - type 0 means unoccupied slot

; how many alien slots used (save for faster lookup)
aliens_spawned: db 0

alien_types_count: equ 1
;alien_types_count: db 1 ; testing with 1, should be 3 ; bouncer, hunter, seeker

; alien records
aliens: 
alien_0: db 0, 4, 8
alien_0_sprite: dw 0 ; pointer to sprite, set when spawned
alien_0_color: db %01000100 ; color of this alien, set when spawned or on update
alien_0_update: dw 0 ; pointer to update routine, set when spawned
alien_0_state: db 0, 0 ; state bits and state counter

alien_1: db 0, 4, 30
alien_1_sprite: dw 0
alien_1_color: db %01000101
alien_1_update: dw 0
alien_1_state: db 0, 0

; each alien definition (set at start of level)
; count, max on screen, remaining in this level, spawn interval, spawn interval countup
level_alien_spec:
level_bouncers: db 0, 0, 0, 0, 0
dw spawn_bouncer
level_hunters: db 0, 0, 0, 50, 0
dw spawn_hunter
level_seekers: db 0, 0, 0, 150, 0
dw spawn_seeker

hunter_sprite: db %01011010, %00000000, %01111110, %11011011, %11111111, %01111110, %01000010, %00000000
bouncer_sprite: db %00000000, %01111110, %11000011, %10011001, %10011001, %11000011, %01111110, %00000000
seeker_sprite: db %00000000, %00011000, %01111110 , %11011011, %11111111, %01111110, %00011000, %00000000

clear_aliens:
ld hl, aliens
; find active aliens and clear
ld b, alien_slots
clear_aliens_loop:
ld a, 0
cp (hl) ; if type  zero, alien slot is unused
jp z, skip_clear_alien
push bc
push hl
call clear_alien
pop hl
pop bc
; skip over record
inc hl ; type
inc hl ; y
inc hl ; x
inc hl ; sprite
inc hl ; sprite
inc hl ; color
inc hl ; update
inc hl ; update
inc hl ; state
inc hl ; counter
skip_clear_alien:
dec b ; for all aliens
ret z ; looked at all slots
jp clear_aliens_loop
ret

; hl points to alien struct
clear_alien:
inc hl ;; skip type
ld b, (hl) ; load alien y, x
inc hl
ld c, (hl)
call char_yx_to_pixel_mem
ld c, 8 ; 8 rows
clear_alien_loop:
ld a, 0
ld (hl), a
inc h ; next pixel line
inc e ; next sprite line
dec c ; loop counter
jr nz, clear_alien_loop
ret


spawn_aliens:
; used up all our alien slots?
ld hl, aliens_spawned
ld c, (hl)
ld a, alien_slots
cp c
ret z ; no slots free, can't spawn
; see if we need to spawn any aliens by type
; ld hl, alien_types_count ; how many types to check
; ld b, (hl)
ld b, alien_types_count ; how many types to check
ld hl, level_alien_spec
spawn_aliens_loop:
push hl ; save address of this spec
push bc ; save count remaining (in b)
; first check
ld a, (hl) ; how many of these currently?
inc hl
ld c, (hl) ; how many of these max
cp c
jp z, spawn_aliens_skip ; reached our limit? nothing to do
; next check
inc hl
ld c, (hl) ; how many left this round
cp c
jp z, spawn_aliens_skip ; reached our limit? nothing to do
inc hl
ld c, (hl) ; how many ticks before spawn?
inc hl
ld a, (hl) ; how many ticks elapsed?
cp c
jp nz, spawn_aliens_skip ; not reached interval ticks?
; we are going to spawn
ld (hl), c ; reset timer (c has how many ticks)
pop hl ; get start of spec record
; increase count of this type of alien
ld a, (hl)
inc a
ld (hl), a
; increase count of used slots
ld hl, aliens_spawned;
ld a, (hl)
inc a
ld (hl), a
; spawn here
; should jump to spawn routine
; dummy test code (should find first free slot and spawn alien there)
ld hl, alien_0
ld (hl), 1 ; type 1
inc hl
ld (hl), 6 ; y
;inc hl
;ld (hl), 20 ; x
; /dummy test code
ret

spawn_aliens_skip:
pop bc ;; b has count of types remaining
pop hl ;; get start of this spec and skip past it
inc hl
inc hl
inc hl
inc hl
inc hl
inc hl
inc hl

dec b ; how many types left to check
cp b ; done all? or some left
jp nz, spawn_aliens_loop
ret

spawn_bouncer:
ret

spawn_hunter:
ret

spawn_seeker:
ret

update_aliens:
ld hl, aliens
; find active aliens and update
ld b, alien_slots
update_aliens_loop:
ld a, 0
cp (hl) ; if type zero, alien slot is unused
jp z, skip_update_alien
push bc
push hl

update_alien_y:
inc hl ; skip type
; ld a, (hl)
; dec a
; ld (hl), a
; cp 4
; jp nz, update_alien_x
; ld a, 20
; ld (hl), a

update_alien_x:
inc hl ; skip y
ld a, (hl)
dec a
ld (hl), a
cp 4
jp nz, update_alien_next
ld a, 28
ld (hl), a
; update alien here call alien_laser ; hl is pointer to alien slot
; here should load type, load x, y, get pointers and call update, update

; stub for test
;call update_alien

update_alien_next:
pop hl
pop bc
; skip over record
inc hl ; type
inc hl ; y
inc hl ; x
inc hl ; sprite
inc hl ; sprite
inc hl ; color
inc hl ; update
inc hl ; update
inc hl ; state
inc hl ; counter

skip_update_alien:
dec b ; for all aliens
ret z ; looked at all slots
jp update_aliens_loop
ret

draw_aliens:
ld hl, aliens
; find active aliens and draw
ld b, alien_slots
draw_aliens_loop:
ld a, 0
cp (hl) ; if type  zero, alien slot is unused
jp z, skip_draw_alien
push bc
push hl
; draw alien here call alien_laser ; hl is pointer to alien slot
; here should load type, load x, y, get pointers and call update, draw

; stub for test
call draw_alien

pop hl
pop bc
; skip over record
inc hl ; type
inc hl ; y
inc hl ; x
inc hl ; sprite
inc hl ; sprite
inc hl ; color
inc hl ; update
inc hl ; update
inc hl ; state
inc hl ; counter

skip_draw_alien:
dec b ; for all aliens
ret z ; looked at all slots
jp draw_aliens_loop
ret

; hl points to alien struct
draw_alien:
inc hl ;; skip type
ld b, (hl) ; load alien y, x
inc hl
ld c, (hl)
inc hl
inc hl
inc hl
ld a, (hl)
push af
push bc
call char_yx_to_pixel_mem
ld c, 8 ; 8 rows
ld de, bouncer_sprite ; sprite (should come from struct)
draw_alien_loop:
ld a, (de)
ld (hl), a
inc h ; next pixel line
inc e ; next sprite line
dec c ; loop counter
jr nz, draw_alien_loop
pop bc
call char_yx_to_attrs_mem
pop af
ld (hl), a
ret

; alien type function pointers
alien_types:
alien_type_hunter:
dw update_hunter 
dw paint_hunter
alien_type_bouncer:
dw update_bouncer
dw paint_bouncer
alien_type_seeker:
dw update_seeker 
dw paint_seeker

; alien handlers
update_hunter:
ret

paint_hunter:
ret

update_bouncer:
ret

paint_bouncer:
ret

update_seeker:
ret

paint_seeker:
ret

; helpers

char_yx_to_pixel_mem:
; bc is y, x
ld h, 0
ld l, b ; hl = Y
add hl, hl ; hl = y*2
ld de, chars_map
add hl, de ; hl = chars_map + (row * 2)
ld a, (hl) ; implements ld hl, (hl)
inc hl
ld h,(hl)
ld l, a ; hl = address of first pixel from chars_map
ld d, 0
ld e, c
add hl, de
ret

char_yx_to_attrs_mem:
; bc is y, x
ld h, 0
ld l, b ; hl = Y
add hl, hl ; hl = y*2
ld de, attrs_map
add hl, de ; hl = chars_map + (row * 2)
ld a, (hl) ; implements ld hl, (hl)
inc hl
ld h,(hl)
ld l, a ; hl = address of first pixel from chars_map
ld d, 0
ld e, c
add hl, de
ret

clear_sprite:
; sprite y, x position in bc
call char_yx_to_pixel_mem
ld c, 8
clear_sprite_loop:
ld a, 0
ld (hl), a
inc h
dec c
jr nz, clear_sprite_loop
ret


get_player_yx:
; put player x-y character position in to bc (y, x)
ld hl, y_pos
ld a, (hl);
ld b, a

ld hl, x_pos
ld a, (hl);
ld c, a
ret

;; states

boot:
call cls
call splash
ld hl, state
ld (hl), state_game_on
ei
reti

game_start:
ld hl, game_level
ld (hl), 1

ld hl, game_score
ld (hl), 0
inc hl
ld (hl), 0

ld hl, humans_alive
ld (hl), 5

; start game
ld hl, state
ld (hl), state_level_start
ei
reti

level_start:
; cls
; print score
; print level
; draw game area

; color for this level
ld hl, level_attr
ld a, (hl) ; attr color for this level
out (254), a ; ok so long as not doing sound
;call 8859 ; set border colour (uses a, stomps on a)

; top play area border
ld hl, $4440
ld de, $5840
ld b, 32
top_border_loop:
ld (hl), %10101010 ; pixels
inc hl
ld (de), a ; attrs
inc de
djnz top_border_loop

; bottom play area border
ld hl, $54A0
ld de, $5aa0
ld b, 32
bottom_border_loop:
ld (hl), %10101010 ; pixels
inc hl
ld (de), a ; attrs
inc de
djnz bottom_border_loop

; print score
ld a, 22
rst 16
ld a, 0 ; y
rst 16
ld a, 0; x
rst 16
ld bc, (game_score)
call 11563
call 11747
; score attr
ld de, $5800
ld a, %01000111
ld (de), a
inc de
ld (de), a
inc de
ld (de), a
inc de
ld (de), a

; print level
ld a, 22
rst 16
ld a, 0 ; y
rst 16
ld a, 31; x
rst 16
ld bc, (game_level)
call 11563
call 11747
; level attr
ld de, $581f
ld a, %01000111
ld (de), a
dec de
ld (de), a
dec de
ld (de), a
dec de
ld (de), a

; dummy level start
; would do % based on level and set alien meta based on result

ld hl, level_bouncers
inc hl ; skip count
ld (hl), 4 ; max on screen
inc hl
ld (hl), 12 ; count for level
inc hl
ld (hl), 25 ; spawn interval
inc hl
ld (hl), 50 ; spawn interval countdown (before first alien shows up)

;
ld hl, state
ld (hl), state_play
ei
reti

level_end:
ei
reti

game_over:
ei
reti

attract:
ei
reti

title:
ei
reti


; IN  -   B = pixel row (0..191)
; IN  -   C = character column (0..31)
; OUT -  HL = screen address
; OUT -  DE = trash
; coords_to_address:  
;     ld  h, 0
;     ld  l, b            ; hl = row
;     add hl, hl          ; hl = row number * 2
;     ld  de, screen_map  ; de = screen map
;     add hl, de          ; de = screen_map + (row * 2)
;     ld  a, (hl)         ; implements ld hl, (hl)
;     inc hl
;     ld  h, (hl)         
;     ld  l, a            ; hl = address of first pixel in screen map
;     ld  d, 0
;     ld  e, c            ; de = X (character based)
;     add hl, de          ; hl = screen addr + 32
;     ret                 ; return screen_map[pixel_row]


; screen_map:		
; dw #4000, #4100, #4200, #4300 
; dw #4400, #4500, #4600, #4700 
; dw #4020, #4120, #4220, #4320 
; dw #4420, #4520, #4620, #4720 
; dw #4040, #4140, #4240, #4340 
; dw #4440, #4540, #4640, #4740 
; dw #4060, #4160, #4260, #4360 
; dw #4460, #4560, #4660, #4760 
; dw #4080, #4180, #4280, #4380 
; dw #4480, #4580, #4680, #4780 
; dw #40A0, #41A0, #42A0, #43A0 
; dw #44A0, #45A0, #46A0, #47A0 
; dw #40C0, #41C0, #42C0, #43C0 
; dw #44C0, #45C0, #46C0, #47C0 
; dw #40E0, #41E0, #42E0, #43E0 
; dw #44E0, #45E0, #46E0, #47E0 
; dw #4800, #4900, #4A00, #4B00 
; dw #4C00, #4D00, #4E00, #4F00 
; dw #4820, #4920, #4A20, #4B20 
; dw #4C20, #4D20, #4E20, #4F20 
; dw #4840, #4940, #4A40, #4B40 
; dw #4C40, #4D40, #4E40, #4F40 
; dw #4860, #4960, #4A60, #4B60 
; dw #4C60, #4D60, #4E60, #4F60 
; dw #4880, #4980, #4A80, #4B80 
; dw #4C80, #4D80, #4E80, #4F80 
; dw #48A0, #49A0, #4AA0, #4BA0 
; dw #4CA0, #4DA0, #4EA0, #4FA0 
; dw #48C0, #49C0, #4AC0, #4BC0 
; dw #4CC0, #4DC0, #4EC0, #4FC0 
; dw #48E0, #49E0, #4AE0, #4BE0 
; dw #4CE0, #4DE0, #4EE0, #4FE0 
; dw #5000, #5100, #5200, #5300 
; dw #5400, #5500, #5600, #5700 
; dw #5020, #5120, #5220, #5320 
; dw #5420, #5520, #5620, #5720 
; dw #5040, #5140, #5240, #5340 
; dw #5440, #5540, #5640, #5740 
; dw #5060, #5160, #5260, #5360 
; dw #5460, #5560, #5660, #5760 
; dw #5080, #5180, #5280, #5380 
; dw #5480, #5580, #5680, #5780 
; dw #50A0, #51A0, #52A0, #53A0 
; dw #54A0, #55A0, #56A0, #57A0 
; dw #50C0, #51C0, #52C0, #53C0 
; dw #54C0, #55C0, #56C0, #57C0 
; dw #50E0, #51E0, #52E0, #53E0 
; dw #54E0, #55E0, #56E0, #57E0 

include "cls.asm"
include "splash.asm"
include "cycle.asm"
