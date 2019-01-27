opench: equ 5633 ;$1601
print: equ 8252 ;$203C
splash_text:
db '     All systems operational.',13

splash:
call cls

ld a, %01000010     
ld (23693),a        ; set our screen colours.
call 3503           ; clear the screen.

; Open upper screen channel
ld a,2
call opench

; Print string
ld de,splash_text
ld bc, 28
call print

ret
