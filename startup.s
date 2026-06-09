
	.include    "jaguar.inc"
	.include 	"bootconst.inc"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Begin STARTUP PICTURE CONFIGURATION -- Edit this to change startup picture
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PPP     	.equ    8      			; Pixels per Phrase (1-bit)
BMP_WIDTH   	.equ    320      		; Width in Pixels
BMP_HEIGHT  	.equ    200    			; Height in Pixels

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; End of STARTUP PICTURE CONFIGURATION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Globals

		.extern _GPU_vblank_ticks

		.extern _VBI

		.extern _VID_tick
		.extern _VID_pal

		.extern _VID_width
		.extern _VID_height

		.extern _VID_vdb
		.extern _VID_vde
		.extern _VID_hdb
		.extern _VID_hde
        
        .extern _vidmem
        .extern listbuf
        .extern bmpupdate


BMP_PHRASES 	.equ    (BMP_WIDTH/PPP) 	; Width in Phrases
BMP_LINES   	.equ    (BMP_HEIGHT*2)  	; Height in Half Scanlines
BITMAP_OFF  	.equ    (2*8)       		; Two Phrases
LISTSIZE    	.equ    5       		; List length (in phrases)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Program Entry Point Follows...

		.text

		move.l  #$70007,G_END		; big-endian mode
		move.l  #$70007,D_END
		move.w  #$FFFF,VI       	; disable video interrupts

		move.l  #INITSTACK,a7   	; Setup a stack
			
		jsr 	InitVideo      		; Setup our video registers.
		jsr 	InitLister     		; Initialize Object Display List
		jsr 	InitVBint      		; Initialize our VBLANK routine

;;; Sneaky trick to cause display to popup at first VB

		move.l	#$0,listbuf+BITMAP_OFF
		move.l	#$C,listbuf+BITMAP_OFF+4

		;
		; load resident code into the GPU
		;

		.extern _GPU_resident_start
		.extern _GPU_resident_end

		move.l 	#G_RAM,a1

		move.l 	#_GPU_resident_start,a0
		move.l 	#_GPU_resident_end,d1
		sub.l  	a0,d1
		addq  	#3,d1
		lsr.w 	#2,d1 ; number of longs
		subq 	#1,d1 ; now a counter
.copy_gpu_resident:
		move.l  (a0)+,(a1)+
		dbra 	d1,.copy_gpu_resident

		.extern _GPU_store
		.extern GPU_init

		move.l 	d0,_GPU_store  		; D0 is swapped OLP from InitLister
		move.l 	#GPU_init,G_PC
		
.start_gpu:
		move.l  #RISCGO,G_CTRL
.stop_68k:
		stop	#$2000

		move.l  G_CTRL,d0   		; we're back! is the GPU still running?
		andi.l  #$1,d0
		bne 	.stop_68k 			; yes! stop again

		move.l 	#$4000,G_PC  		; no! restart the GPU
		bra.s  	.start_gpu

		; should never reach here...

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Procedure: InitVBint
; Install our vertical blank handler and enable interrupts
;

InitVBint:
		movem.l d0/a0-a1,-(sp)

		lea  	VBI,a0  			; copy the vblank handler into RAM
		lea 	_VBI,a1
		move.w 	#(((VBISIZE+3)/4)-1),d0
.copy_VBI:
		move.l  (a0)+,(a1)+
		dbra  	d0,.copy_VBI 

		move.l  #_VBI,LEVEL0		; Install 68K LEVEL0 handler

		move.w  _VID_vde,d0        	; Must be ODD
		ori.w   #1,d0
		move.w  d0,VI

		move.w  #C_VIDENA,INT1         	; Enable video interrupts

		move.w  sr,d0
		and.w   #$F8FF,d0       	; Lower 68k IPL to allow
		move.w  d0,sr           	; interrupts

		movem.l (sp)+,d0/a0-a1
		rts
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Procedure: InitVideo (same as in vidinit.s)
;            Build values for hdb, hde, vdb, and vde and store them.
;
						
InitVideo:
		movem.l d0-d6,-(sp)
			
		move.w  CONFIG,d0      		 ; Also is joystick register
		andi.w  #VIDTYPE,d0    		 ; 0 = PAL, 1 = NTSC
		beq 	palvals

		move.w  #NTSC_HMID,d2
		move.w  #NTSC_WIDTH,d0

		move.w  #NTSC_VMID,d6
		move.w  #NTSC_HEIGHT,d4

		move.w	#5,_VID_tick		; 1 frame is 1/60 second = 5/300 tick units
		move.w	#0,_VID_pal

		bra 	calc_vals

palvals:
		move.w  #PAL_HMID,d2
		move.w  #PAL_WIDTH,d0

		move.w  #PAL_VMID,d6
		move.w  #PAL_HEIGHT,d4

		move.w	#6,_VID_tick		; 1 frame is 1/50 second = 6/300 tick units
		move.w	#1,_VID_pal

calc_vals:
		move.w  d0,_VID_width
		move.w  d4,_VID_height

		move.w  d0,d1
		asr 	#1,d1         	 	; Width/2

		sub.w   d1,d2         	  	; Mid - Width/2
		add.w   #4,d2         	  	; (Mid - Width/2)+4

		sub.w   #1,d1         	  	; Width/2 - 1
		ori.w   #$400,d1      	  	; (Width/2 - 1)|$400
		
		move.w  d1,_VID_hde
		move.w  d1,HDE

		move.w  d2,_VID_hdb
		move.w  d2,HDB1
		move.w  d2,HDB2

		move.w  d6,d5
		sub.w   d4,d5
		move.w  d5,_VID_vdb

		add.w   d4,d6
		move.w  d6,_VID_vde

		move.w  d5,VDB  			; d5 == _VID_vdb
		move.w  #$FFFF,VDE
			
		move.l  #0,BORD1        	; Black border
		move.w  #0,BG           	; Init line buffer to black
			
		movem.l (sp)+,d0-d6
		rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; InitLister: Initialize Object List Processor List
;
;    Returns: Pre-word-swapped address of current object list in d0.l
;
;  Registers: d0.l/d1.l - Phrase being built
;             d2.l/d3.l - Link address overlays
;             d4.l      - Work register
;             a0.l      - Roving object list pointer
		
InitLister:
		movem.l d1-d4/a0,-(sp)		; Save registers
			
		lea     listbuf,a0
		move.l  a0,d2           	; Copy

		add.l   #(LISTSIZE-1)*8,d2  	; Address of STOP object
		move.l	d2,d3			; Copy for low half

		lsr.l	#8,d2			; Shift high half into place
		lsr.l	#3,d2
		
		swap	d3			; Place low half correctly
		clr.w	d3
		lsl.l	#5,d3

; Write first BRANCH object (branch if YPOS > a_vde )

		clr.l   d0
		move.l  #(BRANCHOBJ|O_BRLT),d1  ; $4000 = VC < YPOS
		or.l	d2,d0			; Do LINK overlay
		or.l	d3,d1
								
		move.w  _VID_vde,d4                ; for YPOS
		lsl.w   #3,d4                   ; Make it bits 13-3
		or.w    d4,d1

		move.l	d0,(a0)+
		move.l	d1,(a0)+

; Write second branch object (branch if YPOS < a_vdb)
; Note: LINK address is the same so preserve it

		andi.l  #$FF000007,d1           ; Mask off CC and YPOS
		ori.l   #O_BRGT,d1      	; $8000 = VC > YPOS
		move.w  _VID_vdb,d4                ; for YPOS
		lsl.w   #3,d4                   ; Make it bits 13-3
		or.w    d4,d1

		move.l	d0,(a0)+
		move.l	d1,(a0)+

; Write a standard BITMAP object
		move.l	d2,d0
		move.l	d3,d1

		ori.l  #BMP_HEIGHT<<14,d1       ; Height of image

		move.w  _VID_height,d4           	; Center bitmap vertically
		sub.w   #BMP_HEIGHT,d4
		add.w   _VID_vdb,d4
		andi.w  #$FFFE,d4               ; Must be even
		lsl.w   #3,d4
		or.w    d4,d1                   ; Stuff YPOS in low phrase

		move.l	#_vidmem,d4
		lsl.l	#8,d4
		or.l	d4,d0

		move.l	d0,(a0)+
		move.l	d1,(a0)+
		movem.l	d0-d1,bmpupdate

; Second Phrase of Bitmap
		move.l	#BMP_PHRASES>>4,d0	; Only part of top LONG is IWIDTH
		move.l  #O_DEPTH8|O_NOGAP,d1   ; Bit Depth = 16-bit, Contiguous data

		move.w  _VID_width,d4            	; Get width in clocks
		lsr.w   #2,d4               	; /4 Pixel Divisor
		sub.w   #BMP_WIDTH,d4
		lsr.w   #1,d4
		or.w    d4,d1

		ori.l	#(BMP_PHRASES<<18)|(BMP_PHRASES<<28),d1	; DWIDTH|IWIDTH

		move.l	d0,(a0)+
		move.l	d1,(a0)+

; Write a STOP object at end of list
		clr.l   (a0)+
		move.l  #(STOPOBJ|O_STOPINTS),(a0)+

; Now return swapped list pointer in D0

		move.l  #listbuf,d0
		swap    d0

		movem.l (sp)+,d1-d4/a0
		rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Procedure: VBI
;        Handle Video Interrupt and update object list fields
;        destroyed by the object processor.

VBI:
		move.l  a0,-(sp)

		move.l  #listbuf+BITMAP_OFF,a0

		move.l  bmpupdate,(a0)      	; Phrase = d1.l/d0.l
		move.l  bmpupdate+4,4(a0)

		add.l 	#1,_GPU_vblank_ticks 	; Increment ticks semaphore

		move.w  #$101,INT1      	; Signal we're done
		move.w  #$0,INT2

		move.l  (sp)+,a0
		rte
VBI_end:

	; check that there is at least this reserved at _VBI
	.PRINT	"VBI SIZE: ",/u/l (VBI_end-VBI), " Bytes"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		.end
