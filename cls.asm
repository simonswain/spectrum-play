cls_pixels:
   ; a is bitmap
    ld  hl, $4000
    ld  bc, $17ff
    ld  (hl), a
    ld  d, h
    ld  e, 1
    ldir
    ret

cls_attrs:
   ; a is attrs
    ld  hl, $5800
    ld  bc, $300
    ld  (hl), a
    ld  d, h
    ld  e, 1
    ldir

    ret

cls:
   ld a, 4            ;  green.
   call 8859           ; set border colour.

   ld a, $60
   call cls_pixels

   ld a, $44             ; 0 40 0 4  64 bright green
   call cls_attrs

   ret
