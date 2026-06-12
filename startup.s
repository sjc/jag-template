
	.include    "jaguar.inc"
	.include 	"bootconst.inc"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Begin STARTUP PICTURE CONFIGURATION -- Edit this to change startup picture
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


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
        .extern _OLPstore
        .extern _OList
        .extern _InitObjectList


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Program Entry Point Follows...

		.text

		move.l  #$70007,G_END		; big-endian mode
		move.l  #$70007,D_END
		move.w  #$FFFF,VI       	; disable video interrupts

		move.l  #INITSTACK,a7   	; Setup a stack
			
		jsr 	InitVideo      		; Setup our video registers.
		jsr 	InitLister     		; Initialize Object Display List
		jsr 	InitVBint      		; Initialize our VBLANK routine

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

		move.l 	#_OLPstore+16,d0
		swap  	d0
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


InitLister:
	movem.l	d0-d7/a0-a6,-(sp)
;
; make some branch and stop objects to work around an object processor bug
; for the branch objects:
; [-------unused-------][--------link--------] [unused] cc[---ypos---]type
; xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
;
;link is the address of the stop object / 8
;cc is 2 for branch0, 1 for branch1
;type is 3 for both branch objects
;ypos is vde for branch0, vdb for branch1
;
	lea	_OLPstore,a0
	move.l	a0,d0  			; address of STOP object
	lsr.l	#3,d0			; convert address to phrase
	move.l	d0,d3			; we'll need this link address twice

	move.l	#0,(a0)+
	move.l	#4,(a0)+		; stop object
	move.l	#0,(a0)+		;
	move.l	#4,(a0)+		; another one, never used, for quad alignment
					; a0 is now _OLPstore+16
;
; a0 now points at branch0
;
	moveq.l	#0,d1
	moveq.l	#0,d2
	move.w	_VID_vde,d1
	move.w	_VID_vdb,d2

	lsr.l	#8,d0					;lowest 8 bits go in next long, so remove them
	move.l	d0,(a0)					;set high bytes of link pointer
	lsl.l	#3,d1					;shift vde left 3 to make room for object type
	or.w	#$8003,d1				;set cc to 2, type to 3
	lsl.l	#8,d3					;shift past 8 unused bits
	swap	d3					;move low 8 bits of link pointer and unused 8 bits to high word
	move.w	d1,d3					;combine cc, ypos, type with low 8 bits of link pointer and unused 8 bits
	move.l	d3,4(a0)				;save 2nd long in the phrase
	move.l	(a0),8(a0)				;high bytes of link pointer are the same as branch0
	lsl.l	#3,d2					;shift vdb left 3 to make room for object type
	or.w	#$4003,d2				;set cc to 1, type to 3
	move.w	d2,d3					;combine cc, ypos, type with low 8 bits of link pointer and unused 8 bits
	move.l	d3,12(a0)				;save 2nd long in the phrase
;
; finally, add another stop object (for now)
;
	lea	16(a0),a0		; a0 is now _OLPstore+32
	move.l	#0,(a0)
	move.l	#4,4(a0)
	;move.l	a0,_OList

	jsr _InitObjectList 	; this must set _OList to point to a valid list

	movem.l	(sp)+,d0-d7/a0-a6
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Procedure: VBI
;        Handle Video Interrupt and update object list fields
;        destroyed by the object processor.

VBI:
		movem.l  d0/a0-a1,-(sp)

	; copy the current object list into the OLPStore, after the
	;	initial BRANCH objects

	move.l	_OList,a0
	lea		_OLPstore+32,a1	; first 4 phrases are reserved for stop and branch objects
.copy_olist:
	move.l	(a0)+,(a1)+		; copy first long of phrase
	move.l	(a0)+,d0
	move.l	d0,(a1)+
	cmpi.l	#4,d0			; see if we have reached the stop object
	bne.b	.copy_olist

		add.l 	#1,_GPU_vblank_ticks 	; Increment ticks semaphore

		move.w  #$101,INT1      	; Signal we're done
		move.w  #$0,INT2

		movem.l  (sp)+,d0/a0-a1
		rte
VBI_end:

	; check that there is at least this reserved at _VBI
	.PRINT	"VBI SIZE: ",/u/l (VBI_end-VBI), " Bytes"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		.end
