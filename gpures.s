;
; gpures.s
; Resident GPU code
;

    .include "jaguar.inc"

_GPU_resident_start::

    .gpu
    .org G_RAM

    .include "cabi.inc"

; stored in alt registers
; TODO: ensure these match eg. regs used by the jag3d code
bcmd_ptr        .equr   r0,1
; NOTE: jag3d uses a1_ptr => A1_PIXEL and a2_ptr => A2_PIXEL
a1base_ptr      .equr   r1,1
a2base_ptr      .equr   r2,1

;
; shut down the GPU
;

_GPU_done::

    movei   #G_CTRL,r0
    moveq   #2,r1
    store   r1,(r0)
    nop
    nop

;
; basic blitter functions
;

bcmd    .equr   r13,1
a1p     .equr   r14,1
a2p     .equr   r15,1

temp0   .equr   r0,1
temp1   .equr   r1,1
temp2   .equr   r30,1

;
; Perform a blit and return once it's done
; param0 - source (phrase aligned)
; param1 - destination (phrase aligned)
; param2 - count of long words to copy (???)
; lr - return address
;

_GPU_blit_and_wait::

    subqt   #4,sp       ; save our real return address
    store   lr,(sp)

    ; jump to the blitter code and return here

    movei   #_GPU_blit,temp0
    move    pc,lr
    jump    (temp0)
    addqt   #6,lr
    
    load    (sp),lr     ; restore return address
    addqt   #4,sp

    ; fall through to blitter wait code, returning from there

;
; wait for the blitter to be ready and then return
; r27 - return address
;

_GPU_wait_blitter_ready::

    movefa  bcmd_ptr,bcmd
        ; TODO: maybe this should require that bcmd is already setup?

.wait_blitter_ready:
    load    (bcmd),temp0
    btst    #0,temp0
    jr      EQ,.wait_blitter_ready
    nop

    jump    (lr)
    nop

;
; Perform a blit and return with it in progress
; param0 - source (phrase aligned)
; param1 - destination (phrase aligned)
; param2 - count of long words to copy
; lr - return address
;

; NOTE: if blitting into GPU RAM, caller should ensure that address
;   is in the +$8000 32-bit range

_GPU_blit::

    movefa  a1base_ptr,a1p
    movefa  a2base_ptr,a2p

    subqt   #4,sp           ; store the return address
    store   lr,(sp)

    ; check blitter is ready

    movei   #_GPU_wait_blitter_ready,temp0
    move    pc,lr
    jump    (temp0)
    addqt   #6,lr

    ; this will return with bcmd => B_CMD

    addqt   #4,bcmd         ; => B_COUNT

    ; setup to blit

    ; A1 == destination
    ; A2 == source

    store   param1,(a1p)        ; destination parameter
    store   param0,(a2p)        ; source parameter

    movei   #(PIXEL32|PITCH1|WID448|XADDPHR),temp2
    moveq   #0,temp0

    store   temp2,(a1p+1)               ; A1_FLAGS
    store   temp2,(a2p+1)               ; A2_FLAGS
    
    store   temp0,(a1p+3)               ; A1_PIXEL
    store   temp0,(a2p+3)               ; A2_PIXEL

    ; param2 contains the count of long words to copy
    bset    #16,param2      ; eg. $0001nnnn = 1 row, nnnn columns
    store   param2,(bcmd)   ; bcmd => B_COUNT
    subqt   #4,bcmd         ; bcmd => B_CMD

    movei   #(SRCEN|LFU_REPLACE),temp1
    store   temp1,(bcmd)

    ; restore return address and return

    load    (sp),lr
    ;addqt   #4,sp
    jump    (lr)
    ;nop
    addqt   #4,sp

    .equrundef      bcmd
    .equrundef      a1p
    .equrundef      a2p

    .equrundef      temp0
    .equrundef      temp1
    .equrundef      temp2

;
; vblank
;

;
; C entry point, with return address in lr
; uses: r0-r3
;
_GPU_wait_vblank::

    movei   #_GPU_vblank_ticks,r0
    load    (r0),r1

.wait_vblank:

    load    (r0),r2
    cmp     r1,r2
    jr  EQ,.wait_vblank
    nop

    jump    (lr)
    nop

    .long
; in GPU RAM so we can spin here while we wait and keep the main bus free
_GPU_vblank_ticks::     .dc.l   1

; storage for passing params or saving the stack or whatever
_GPU_store::            .dc.l   1   

;
; Initial code to setup the GPU environment
; Once run, this can be used as the address to load other code
;
    .phrase
GPU_init::

    ; setup the initial Object List pointer, which was passed via _GPU_store

    movei   #_GPU_store,r0
    load    (r0),r1

    movei   #OLP,r0
    store   r1,(r0)

    ; set the video mode

    movei   #$6C1,r0        ; 16-bit CrY mode
    movei   #VMODE,r1
    storew  r0,(r1)

    ; setup the stack pointer

    movei   #$1FFF00,sp     ; leaves 256 bytes for the 68k stack

    ; squirrel some useful values away in the alt regs

    movei   #B_CMD,r0
    moveta  r0,bcmd_ptr
    movei   #A1_BASE,r0
    moveta  r0,a1base_ptr
    movei   #A2_BASE,r0
    moveta  r0,a2base_ptr

    ;
    ; TEMP: wait briefly to demonstrate vblank waiting works
    ;

    movei   #_GPU_wait_vblank,r4
    moveq   #30,r5
    move    pc,lr
    addqt   #8,lr   ; point to after the nop

.wait_vblank_loop:
    jump    (r4)
    nop

    subq    #1,r5
    jr  NE,.wait_vblank_loop
    nop

    ;
    ; Load the main code into RAM using the blitter
    ;

    .extern ram_bin
    .extern ram_binx

    movei   #ram_bin,param0
    movei   #ram_binx,param2
    sub     param0,param2
    addqt   #3,param2       ; round up to next phrase
    shrq    #2,param2

    movei   #$4000,param1   ; destination address
    move    param1,lr       ; ...is also return address

    movei   #_GPU_blit_and_wait,r0
    jump    (r0)
    nop

    ; does not return...

    .equrundef  sp

    .equrundef  bcmd_ptr
    .equrundef  a1base_ptr
    .equrundef  a2base_ptr

    .include "cabi-undef.inc"

    .68000
    .phrase
_GPU_resident_end::

; copy the output from this into gpures_funcs.s so they can be
;   accessed from the main code and gpures.h

.PRINT  "; gpures_funcs.s"
.PRINT  "; Automatically generated from gpures.s -- manual changes will be lost!"
.PRINT  "    .gpu"

.PRINT  "    .org $",/x/l _GPU_done
.PRINT  "_GPU_done::"

.PRINT  "    .org $",/x/l _GPU_wait_blitter_ready
.PRINT  "_GPU_wait_blitter_ready::"

.PRINT  "    .org $",/x/l _GPU_blit_and_wait
.PRINT  "_GPU_blit_and_wait::"

.PRINT  "    .org $",/x/l _GPU_blit
.PRINT  "_GPU_blit::"

.PRINT  "    .org $",/x/l _GPU_wait_vblank
.PRINT  "_GPU_wait_vblank::"

.PRINT  "    .org $",/x/l _GPU_store
.PRINT  "_GPU_store::"

.PRINT  "    .org $",/x/l GPU_init
.PRINT  "_GPU_init::"
