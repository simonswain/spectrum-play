; cycle

ATTR: db 0
BITS: db 1

reset_attrs:
    ld a, $44
    ld  hl, $5800
    ld  bc, $300
    ld  (hl), a
    ld  d, h
    ld  e, 1
    ldir
    inc a
    ret

cycle_attrs:
    ld a, (ATTR)
    ld  hl, $5800
    ld  bc, $300
    ld  (hl), a
    ld  d, h
    ld  e, 1
    ldir
    inc a
    ld (ATTR), a
    ret

cycle_pixels:
    ld a, (BITS)
    ld  hl, $4000
    ld  bc, $17ff
    ld  (hl), a
    ld  d, h
    ld  e, 1
    ldir
    rl a
    ld (BITS), a
    ret

cycle_dots:
    ld a, (BITS)
    ld  hl, $4800
    ld  bc, $001F
    ld  (hl), a
    ld  d, h
    ld  e, 1
    ldir
    inc a
    ld (BITS), a
    ret