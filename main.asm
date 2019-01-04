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

main_loop:	; wait for interrupt
jr	main_loop

; joystick
;x_pos: db 16
x_bits: db 84
cycle_bit: db 1

isr:	
call cycle_attrs
call cycle_dots

; cycle_dots:
;     ld a, (cycle_bit)
;     ld  hl, $4800
;     ld  bc, $001F
;     ld  (hl), a
;     ld  d, h
;     ld  e, 1
;     ldir
;     rl a
;     ld (cycle_bit), a
    
; show js bits
ld bc, 31
in a,(c)
ld hl, $5014
ld (hl), a

js button 
ld bc, 31
in a,(c)
and 16
call nz, fire

ld bc, 31
in a,(c)
and 16
call z, nofire

; paint js button
ld hl, $500b
ld a, (x_bits)
ld (hl), a

ei
reti


; ld b, 0
; ld a,(x_pos)
; ld c, a
; ld hl, $5000
; add hl, bc
; ld a, (x_bits)
; ld (hl), a

fire:
ld a, 255
ld (x_bits), a
ret

nofire:
ld a, 85
ld (x_bits), a
ret


include "cls.asm"
include "splash.asm"
include "cycle.asm"
