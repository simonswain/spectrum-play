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

call draw_player
call draw_lasers

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

state: db state_boot ; 1 = playing game, 2 = level end, 3 = start game, 4 = attract, 5 = title, 6 = boot
state_step: db 0
state_timer: dw 0

game_level: db 0
game_score: dw 0

y_pos: db 12
x_pos: db 16
is_firing: db 0

; slots for 4 lasers. 0 means no laser in that slot

; y, d, x
db 'las'
lasers: db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
laser_attr: db 68 ; 0 color bits for lasers - rotate 1-7
laser_dir: db 1 ; dir of last laser 0 right, 1 left
db 'end'
laser_x: db 0, 0, 0, 0
laser_y: db 0, 0, 0, 0
laser_d: db 0, 0, 0, 0 ; 0 = right, 1 = left

player_sprite: db %11111111, %00111100, %00011000, %00111100, %00111100, %00011000, %00111100, %11111111

laser_sprite: db %00000000, %00000000, %00000000 , %11111111, %11111111, %00000000, %00000000, %00000000

screen_map: dw $4000, $4020, $4040, $4060, $4080, $40A0, $40C0, $40E0, $4800, $4820, $4840, $4860, $4880, $48A0, $48C0, $48E0, $5000, $5020, $5040, $5060, $5080, $50A0, $50C0, $50E0

attrs_map: dw $5800, $5820, $5840, $5860, $5880, $58A0, $58C0, $58E0, $5900, $5920, $5940, $5960, $5980, $59A0, $59C0, $59E0, $5A00, $5A20, $5A40, $5A60, $5A80, $5AA0, $5AC0, $5AE0

char_xy_to_pixel_mem:
; bc is y, x
ld h, 0
ld l, b ; hl = Y
add hl, hl ; hl = y*2
ld de, screen_map
add hl, de ; hl = screen_map + (row * 2)
ld a, (hl) ; implements ld hl, (hl)
inc hl
ld h,(hl)
ld l, a ; hl = address of first pixel from screen_map
ld d, 0
ld e, c
add hl, de
ret

char_xy_to_attrs_mem:
; bc is y, x
ld h, 0
ld l, b ; hl = Y
add hl, hl ; hl = y*2
ld de, attrs_map
add hl, de ; hl = screen_map + (row * 2)
ld a, (hl) ; implements ld hl, (hl)
inc hl
ld h,(hl)
ld l, a ; hl = address of first pixel from screen_map
ld d, 0
ld e, c
add hl, de
ret

clear_sprite:
; sprite y, x position in bc
call char_xy_to_pixel_mem
ld c, 8
clear_sprite_loop:
ld a, 0
ld (hl), a
inc h
dec c
jr nz, clear_sprite_loop
ret


get_player_xy:
; put player x-y character position in to bc (y, x)
ld hl, y_pos
ld a, (hl);
ld b, a

ld hl, x_pos
ld a, (hl);
ld c, a
ret

clear_player:
call get_player_xy ; bc now has y, x
call clear_sprite
ret

draw_player:
call get_player_xy; bc now has y, x
push bc
call char_xy_to_pixel_mem
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
call char_xy_to_attrs_mem
ld (hl), %01000111
ret

get_laser_xy:
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
ld b, 4 ; 4 slots
move_lasers_loop:
ld a, 0
cp (hl) ; if laser y pos is zero, laser is unused
push bc
push hl
call move_laser ; bc now has y, x
pop hl
pop bc
inc hl ; skip to next slot
inc hl
inc hl
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
ld b, 4 ; 4 slots
clear_lasers_loop:
ld a, 0
cp (hl) ; if laser y pos is zero, laser is unused
push bc
push hl
call get_laser_xy ; bc now has y, x
call clear_sprite
pop hl
pop bc
inc hl ;; skip to next slot
inc hl
inc hl
dec b ; for all lasers
ret z ; looked at all slots
jp clear_lasers_loop

draw_lasers:
ld hl, lasers
; find active lasers and draw
ld b, 4 ; 4 slots
draw_lasers_loop:
ld a, 0
cp (hl) ; if laser y pos is zero, laser is unused
push bc
push hl
call nz, draw_laser
pop hl
pop bc
inc hl ;; skip to next slot
inc hl
inc hl
dec b ;; for all lasers
ret z ; looked at all slots
jp draw_lasers_loop

draw_laser:
; hl contains address of laser slot
call get_laser_xy; bc now has y, x
push bc ; save it
call char_xy_to_pixel_mem
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
call char_xy_to_attrs_mem ; hl now has attrs memory location
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



include "cls.asm"
include "splash.asm"
include "cycle.asm"
