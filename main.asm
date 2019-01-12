org $8000

start:	di	; disable ints
ld	sp,$ff00	; set up a stack

call cls
call splash

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

call clear_player
call clear_laser
call update_laser

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
call draw_laser

ei
reti

y_pos: db 12
x_pos: db 16
is_firing: db 0

; slots for 4 lasers. 0 means no laser in that slot
laser_x: db 0, 0, 0, 0
laser_y: db 0, 0, 0, 0
laser_d: db 0, 0, 0, 0 ; 0 = right, 1 = left
laser_attr: db 68 ; 0 color bits for lasers - rotate 1-7
laser_direction: db 1 ; dir of last laser 0 right, 1 left

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
ld hl, laser_y
ld a, (hl);
ld b, a

ld hl, laser_x
ld a, (hl);
ld c, a
ret

update_laser:
; cycle laser color attr value
ld hl, laser_attr
ld a, (hl)
inc a
cp 72
jp nz, update_laser_attr
ld a, 66
update_laser_attr:
ld (hl), a

; move laser position
ld hl, laser_x
ld a, 0
cp (hl)
ret z ; no laser
ld a, (hl)
cp 29 ; hit right edge
jp z, update_laser_terminate
cp 3 ; hit left edge
jp z, update_laser_terminate
; move laser
ld hl, laser_d ; this shot direction
ld c, (hl)
ld a, 1
cp c
jp z, update_laser_move_right
ld hl, laser_x ; this shot direction
ld a, (hl) ; get dir for this shot
dec a; move laser left
ld (laser_x), a
ret
update_laser_move_right:
ld hl, laser_x ; this shot direction
ld a, (hl) ; get dir for this shot
inc a; move laser left
ld (laser_x), a
ret
update_laser_terminate:
; clear laser - out of bounds
ld (hl), 0
ret


clear_laser:
ld hl, laser_x
ld a, 0
cp (hl)
ret z ; no laser
call get_laser_xy ; bc now has y, x
call clear_sprite
ret

draw_laser:
ld hl, laser_x
ld a, 0
cp (hl)
ret z ; no laser
call get_laser_xy; bc now has y, x
push bc
call char_xy_to_pixel_mem
ld c, 8 ; 8 rows
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

; just working with one laser for now
fire:
ld hl, laser_x
ld a, 0
cp (hl)
ret nz ; if laser busy, can't fire
ld hl, y_pos
ld a, (hl)
ld (laser_y), a
ld hl, y_pos
ld a, (hl)
; get direction, flip it
ld hl, laser_direction
ld a, (hl)
ld c, 1
xor c
ld (hl), a
ld hl, laser_d ; where we will store dir
ld (hl), a ; save dir for this shot
ld hl, x_pos
ld a, (hl)
jp z, fire_left
inc a ; shoot from right side
ld (laser_x), a
ret
fire_left:
dec a ; shoot from left side
ld (laser_x), a
ret

include "cls.asm"
include "splash.asm"
include "cycle.asm"
