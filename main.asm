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


y_pos: db 12
x_pos: db 16
is_firing: db 0

isr:

call clear_player


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

ld bc, 31
in a,(c)
and 16
call z, nofire

call draw_player

ei
reti

player_sprite: db %11111111, %00111100, %00011000, %00111100, %00111100, %00011000, %00111100, %11111111

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
call char_xy_to_pixel_mem
;; erase sprite
ld c, 8
clear_player_loop:
ld a, 0
ld (hl), a
inc h
dec c
jr nz, clear_player_loop
ret

draw_player:
call get_player_xy; bc now has y, xcall char_xy_to_pixel_mem

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

fire:
call cycle_attrs
ret

nofire:
call reset_attrs
ret


include "cls.asm"
include "splash.asm"
include "cycle.asm"
