;
; bootstrap.s
; Lives at $4000 and is used to trampoline to main()
;

    .extern __main
    
    .gpu
    .org $4000

    movei   #__main,r0
    nop
    jump    (r0)
    nop
    nop

    .68000
    .data
    .phrase

_image::
    .incbin 'pic.raw'
